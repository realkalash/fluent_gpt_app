// ignore_for_file: constant_identifier_names

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:deepgram_speech_to_text/deepgram_speech_to_text.dart';
import 'package:docx_to_text/docx_to_text.dart';
import 'package:fluent_gpt/common/attachment.dart';
import 'package:fluent_gpt/common/chat_model.dart';
import 'package:fluent_gpt/common/conversaton_style_enum.dart';
import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/common/custom_prompt.dart';
import 'package:fluent_gpt/common/excel_to_json.dart';
import 'package:fluent_gpt/common/on_message_actions/on_message_action.dart';
import 'package:fluent_gpt/common/scrapper/web_scrapper.dart';
import 'package:fluent_gpt/common/scrapper/web_search_result.dart';
import 'package:fluent_gpt/common/stop_reason_enum.dart';
import 'package:fluent_gpt/common/window_listener.dart';
import 'package:fluent_gpt/dialogs/ai_lens_dialog.dart';
import 'package:fluent_gpt/dialogs/error_message_dialogs.dart';
import 'package:fluent_gpt/dialogs/info_about_user_dialog.dart';
import 'package:fluent_gpt/features/agent_get_message_actions.dart';
import 'package:fluent_gpt/features/annoy_feature.dart';
import 'package:fluent_gpt/features/deepgram_speech.dart';
import 'package:fluent_gpt/features/rag_openai.dart';
import 'package:fluent_gpt/features/image_generator_feature.dart';
import 'package:fluent_gpt/features/image_util.dart';
import 'package:fluent_gpt/features/notification_service.dart';
import 'package:fluent_gpt/features/open_ai_features.dart';
import 'package:fluent_gpt/features/text_to_speech.dart';
import 'package:fluent_gpt/fluent_icons_list.dart';
import 'package:fluent_gpt/gpt_tools.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/log.dart';

import 'package:fluent_gpt/common/chat_room.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/pages/new_settings_page.dart';
import 'package:fluent_gpt/shell_driver.dart';
import 'package:fluent_gpt/system_messages.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/command_request_answer_overlay.dart';
import 'package:fluent_gpt/widgets/confirmation_dialog.dart';
import 'package:fluent_gpt/widgets/input_field.dart';
import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gpt_tokenizer/flutter_gpt_tokenizer.dart';
import 'package:intl/intl.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';
import 'package:record/record.dart';
import 'package:rxdart/rxdart.dart';
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:collection/collection.dart';
import 'package:url_launcher/url_launcher_string.dart';

import '../common/last_deleted_message.dart';

ChatOpenAI? openAI;
ChatOpenAI? localModel;

/// First is ID, second is ChatRoom
BehaviorSubject<Map<String, ChatRoom>> chatRoomsStream =
    BehaviorSubject.seeded({});
BehaviorSubject<List<OnMessageAction>> onMessageActions =
    BehaviorSubject.seeded([]);

/// first is ID, second is ChatRoom
Map<String, ChatRoom> get chatRooms => chatRoomsStream.valueOrNull ?? {};

/// key is date, value is list of chat rooms
Map<String, List<ChatRoom>> get chatRoomsGrouped {
  final grouped = groupBy(chatRooms.values, (ChatRoom chatRoom) {
    if (chatRoom.isPinned) return 'Pinned';
    final date =
        DateTime.fromMillisecondsSinceEpoch(chatRoom.dateModifiedMilliseconds);
    return '${date.day}/${date.month}/${date.year}';
  });
  return grouped;
}

BehaviorSubject<String> selectedChatRoomIdStream =
    BehaviorSubject.seeded('Default');
String get selectedChatRoomId => selectedChatRoomIdStream.value;
set selectedChatRoomId(String v) => selectedChatRoomIdStream.add(v);

ChatModelAi get selectedModel =>
    chatRooms[selectedChatRoomId]?.model ??
    (allModels.value.isNotEmpty
        ? allModels.value.first
        : const ChatModelAi(modelName: 'Unknown', apiKey: ''));
ChatRoom get selectedChatRoom {
  final fastSearchItem = chatRooms[selectedChatRoomId];
  if (fastSearchItem != null) return fastSearchItem;
  if (chatRooms.values.isEmpty == true) {
    return _generateDefaultChatroom();
  }
  // next we search in all chats
  final allRooms = getChatRoomsRecursive(chatRooms.values.toList());
  for (var chatRoom in allRooms) {
    if (chatRoom.id == selectedChatRoomId) {
      return chatRoom;
    }
  }
  return chatRooms.values.first;
}

double get temp => chatRooms[selectedChatRoomId]?.temp ?? 0.9;
int get topk => chatRooms[selectedChatRoomId]?.topk ?? 40;
int get promptBatchSize =>
    chatRooms[selectedChatRoomId]?.promptBatchSize ?? 128;
double get topP => chatRooms[selectedChatRoomId]?.topP ?? 0.4;
int get maxTokenLenght => chatRooms[selectedChatRoomId]?.maxTokenLength ?? 2048;
double get repeatPenalty =>
    chatRooms[selectedChatRoomId]?.repeatPenalty ?? 1.18;

/// the key is id or DateTime.now() (chatcmpl-9QZ8C6NhBc5MBrFCVQRZ2uNhAMAW2)  the answer is message
BehaviorSubject<Map<String, FluentChatMessage>> messages =
    BehaviorSubject.seeded({});

/// This list is only for the UI part. It's reversed to show the messages from the bottom and we have separate list for keys to optimize memory usage
List<FluentChatMessage> messagesReversedList = [];

/// conversation lenght style. Will be appended to the prompt
BehaviorSubject<ConversationLengthStyleEnum> conversationLenghtStyleStream =
    BehaviorSubject.seeded(ConversationLengthStyleEnum.normal);

/// conversation style. Will be appended to the prompt
BehaviorSubject<ConversationStyleEnum> conversationStyleStream =
    BehaviorSubject.seeded(ConversationStyleEnum.normal);

String modifyMessageStyle(String prompt) {
  if (conversationLenghtStyleStream.value !=
      ConversationLengthStyleEnum.normal) {
    prompt += ' ${conversationLenghtStyleStream.value.prompt}';
  }

  if (conversationStyleStream.value != ConversationStyleEnum.normal) {
    prompt += ' ${conversationStyleStream.value.prompt}';
  }
  return prompt;
}

String removeMessageTagsFromPrompt(String message, String tagsStr) {
  String newContent = message;
  final tags = tagsStr.split(';');
  if (tags.isEmpty) return message;
  for (var tag in tags) {
    final lenghtStyle = ConversationLengthStyleEnum.fromName(tag);
    final style = ConversationStyleEnum.fromName(tag);
    if (lenghtStyle != null) {
      newContent = newContent.replaceAll(lenghtStyle.prompt ?? '', '');
      continue;
    }
    if (style != null) {
      newContent = newContent.replaceAll(style.prompt ?? '', '');
      continue;
    }
    newContent = newContent.replaceAll(tag, '');
  }
  return newContent;
}

final allModels = BehaviorSubject<List<ChatModelAi>>.seeded([]);

class ChatProvider with ChangeNotifier {
  final listItemsScrollController = AutoScrollController();
  static final TextEditingController messageControllerGlobal =
      TextEditingController();
  TextEditingController get messageController =>
      ChatProvider.messageControllerGlobal;
  late AgentGetMessageActions agentMessageActions;

  bool includeConversationGlobal = true;
  bool scrollToBottomOnAnswer = true;
  bool isSendingFile = false;
  bool isWebSearchEnabled = false;

  final dialogApiKeyController = TextEditingController();
  bool isAnswering = false;
  bool isGeneratingImage = false;
  CancelToken? cancelToken;

  /// It's not a good practice to use [context] directly in the provider...
  BuildContext? context;

  int _messageTextSize = 14;

  /// Used to show the container with the answer only to one single message
  OverlayEntry? _overlayEntry;

  void closeQuickOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> sendToQuickOverlay(String title, String prompt) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tokens = await countTokensString(prompt);
    final messageToSend = FluentChatMessage.humanText(
      id: '$timestamp',
      content: prompt,
      timestamp: timestamp,
      creator: AppCache.userName.value!,
      tokens: tokens,
    );
    _overlayEntry?.remove();
    // var posX = mouseLocalPosition.dx;
    var posY = mouseLocalPosition.dy;
    final screen = MediaQuery.of(context!).size; // '1920x1080'
    // final screenX = double.parse(screen.first);
    // ensure we don't go out of the screen
    // if (posX + 400 > screenX) {
    //   posX = screenX - 400;
    // }
    if (posY + 200 > screen.height) {
      posY = screen.height - 200;
    }
    final overlay = OverlayEntry(
      builder: (context) => CommandRequestAnswerOverlay(
        message: messageToSend,
        initPosTop: posY,
        // ignore it for now, because it will be near message anyway
        initPosLeft: 64,
        screenSize: MediaQuery.of(context).size,
      ),
    );
    _overlayEntry = overlay;
    Overlay.of(context!).insert(overlay);
  }

  void setMaxTokensForChat(int? v) {
    if (v == null) return;
    selectedChatRoom.maxTokenLength = v;
    notifyListeners();
  }

  set textSize(int v) {
    _messageTextSize = v;
    AppCache.messageTextSize.set(v);
    notifyListeners();
  }

  int get textSize => _messageTextSize;
  double autoScrollSpeed = 1.0;
  void setAutoScrollSpeed(double v) {
    autoScrollSpeed = v;
    AppCache.autoScrollSpeed.set(v);
    notifyListeners();
  }

  ChatProvider() {
    _messageTextSize = AppCache.messageTextSize.value ?? 14;
    selectedChatRoomId = AppCache.selectedChatRoomId.value ?? 'Default';
    init();
    listenTray();
  }

  Future<void> init() async {
    agentMessageActions = AgentGetMessageActions(this);
    initMessagesListener();
    await initChatModels();
    await initChatsFromDisk();
    initCustomActions();
    initSettingsFromCache();
    initTimers();
    initListeners();
  }

  void toggleScrollToBottomOnAnswer() {
    scrollToBottomOnAnswer = !scrollToBottomOnAnswer;
  }

  /// if [rooms] list is 1 element and it's current chat room, it will save messages to disk
  Future<void> saveToDisk(List<ChatRoom> rooms) async {
    if (rooms.length == 1) {
      if (rooms.first.id == selectedChatRoomId) {
        // if it's current chat room, save messages
        final messagesRaw = <Map<String, dynamic>>[];
        for (var message in messages.value.entries) {
          /// add key and message.toJson
          messagesRaw.add(message.value.toJson());
        }
        await FileUtils.saveChatMessages(
            rooms.first.id, jsonEncode(messagesRaw));
      }
    }
    for (var chatRoom in rooms) {
      var chatRoomRaw = chatRoom.toJson();
      final path = await FileUtils.getChatRoomsPath();
      await FileUtils.saveFile(
          '$path/${chatRoom.id}.json', jsonEncode(chatRoomRaw));
    }
  }

  Future<void> initChatsFromDisk() async {
    final path = await FileUtils.getChatRoomsPath();
    final files = FileUtils.getFilesRecursive(path);
    final currentDate = DateTime.now();
    final deleteChatsAfterXDays = AppCache.deleteOldChatsAfter.value;

    for (var file in files) {
      try {
        final fileContent = await file.readAsString();
        final chatRoomRaw = jsonDecode(fileContent) as Map<String, dynamic>;
        final chatRoom = ChatRoom.fromMap(chatRoomRaw);
        chatRooms[chatRoom.id] = chatRoom;
        // delete chat if it's old enough
        if (deleteChatsAfterXDays != null) {
          final date = DateTime.fromMillisecondsSinceEpoch(
              chatRoom.dateModifiedMilliseconds);
          final difference = currentDate.difference(date).inDays;
          if (difference >= deleteChatsAfterXDays &&
              !chatRoom.isPinned &&
              !chatRoom.isFolder) {
            log('Deleting chat room ${chatRoom.id} because it\'s old enough');
            await deleteChatRoom(chatRoom.id);
            continue;
          }
        }
        // root level check to load messages
        if (chatRoom.id == selectedChatRoomId) {
          _loadMessagesFromDisk(selectedChatRoomId);
        } else if (chatRoom.children != null) {
          // We allow only 2 levels deep
          for (var subItem in chatRoom.children!) {
            if (subItem.children != null) {
              // 2 deep level check level check to load mesages
              for (var subSubItem in subItem.children!) {
                if (subSubItem.id == selectedChatRoomId) {
                  selectedChatRoomId = chatRoom.id;
                  _loadMessagesFromDisk(selectedChatRoomId);
                }
              }
            } else if (subItem.id == selectedChatRoomId) {
              // 1 deep level check level check to load mesages
              selectedChatRoomId = chatRoom.id;
              _loadMessagesFromDisk(selectedChatRoomId);
            }
          }
        }
      } catch (e) {
        log('initChatsFromDisk error: $e');
        chatRooms[file.path] = ChatRoom(
          id: file.path,
          chatRoomName: 'Error ${file.path}',
          model: const ChatModelAi(modelName: 'error', apiKey: ''),
          temp: temp,
          topk: topk,
          promptBatchSize: promptBatchSize,
          topP: topP,
          maxTokenLength: maxTokenLenght,
          repeatPenalty: repeatPenalty,
          systemMessage: '',
          dateCreatedMilliseconds: DateTime.now().millisecondsSinceEpoch,
        );
      }
    }
    if (chatRooms.isEmpty) {
      final newChatRoom = _generateDefaultChatroom();
      chatRooms[newChatRoom.id] = newChatRoom;
      selectedChatRoomId = newChatRoom.id;
    }
    // safety check if does not contain selected chat room
    if (!chatRooms.containsKey(selectedChatRoomId)) {
      selectedChatRoomId = chatRooms.entries.first.key;
      _loadMessagesFromDisk(selectedChatRoomId);
    }
    selectedChatRoomId = selectedChatRoomId;
    if (openAI == null &&
        localModel == null &&
        selectedChatRoom.model.ownedBy != null) {
      initModelsApi();
    }
    // dumb way to notify UI listeners
    notifyRoomsStream();
  }

  void initMessagesListener() {
    messages.listen((messagesList) {
      messagesReversedList.clear();
      messagesReversedList.addAll(messagesList.values.toList().reversed);
    });
  }

  void initListeners() {
    if (AppCache.fetchChatsPeriodically.value == true) {
      /// If chats are located in the cloud, we need to fetch them twice
      AppWindowListener.windowVisibilityStream
          .distinct()
          .listen((isOpen) async {
        if (isOpen) {
          /// This waiting is needed to prevent errors wtih cloud storate
          await Future.delayed(const Duration(milliseconds: 1500));
          log('Window opened. Fetching chats from disk');
          // initChatsFromDisk();
        }
      });
    }
  }

  Timer? fetchChatsTimer;
  void initTimers() {
    fetchChatsTimer?.cancel();
    if (AppCache.fetchChatsPeriodically.value == true) {
      fetchChatsTimer = Timer.periodic(
          Duration(minutes: AppCache.fetchChatsPeriodMin.value ?? 10), (timer) {
        log('Fetching chats from disk. ${timer.tick}');
        if (AppCache.fetchChatsPeriodically.value == false) {
          timer.cancel();
          return;
        }
        initChatsFromDisk();
      });
    }
  }

  Future initSettingsFromCache() async {
    autoScrollSpeed = AppCache.autoScrollSpeed.value!;
  }

  Future initCustomActions() async {
    final actionsJson = await AppCache.customActions.value();
    if (actionsJson.isNotEmpty == true && actionsJson != '[]') {
      final actions = jsonDecode(actionsJson) as List;
      final listActions = actions
          .map((e) => OnMessageAction.fromJson(e as Map<String, dynamic>))
          .toList();
      onMessageActions.add(listActions);
    } else {
      onMessageActions.add(defaultCustomActionsList);
    }
  }

  Future initChatModels() async {
    final listModelsJsonString = await AppCache.savedModels.value();
    if (listModelsJsonString.isNotEmpty == true) {
      final listModelsJson = jsonDecode(listModelsJsonString) as List;
      final listModels = listModelsJson
          .map((e) => ChatModelAi.fromJson(e as Map<String, dynamic>))
          .toList();
      allModels.add(listModels);
    }
  }

  Future<void> addNewCustomModel(ChatModelAi model) async {
    final allModelsList = allModels.value;
    allModelsList.add(model);
    allModels.add(allModelsList);
    await saveModelsToDisk();
  }

  Future removeCustomModel(ChatModelAi model) async {
    final allModelsList = allModels.value;
    allModelsList.remove(model);
    allModels.add(allModelsList);
    await saveModelsToDisk();
  }

  Future<void> saveModelsToDisk() async {
    final allModelsList = allModels.value;
    final listModelsJson = allModelsList.map((e) => e.toJson()).toList();
    await AppCache.savedModels.set(jsonEncode(listModelsJson));
  }

  /// Should be called after we load all chat rooms
  void initModelsApi() {
    openAI = ChatOpenAI(apiKey: selectedModel.apiKey);
    if (selectedModel.uri != null && selectedModel.uri!.isNotEmpty)
      localModel = ChatOpenAI(
        baseUrl: selectedModel.uri!,
        apiKey: selectedModel.apiKey,
      );
  }

  void listenTray() {
    trayButtonStream.listen((value) async {
      var command = '';
      var text = '';
      Uri? uri;
      Map<String, String> params = {};
      if (value?.contains('fluentgpt:///') == true ||
          value?.contains('fluentgpt://') == true) {
        uri = Uri.tryParse(value!);
        command = uri!.queryParameters['command'] ?? '';
        text = uri.queryParameters['text'] ?? '';
        params = uri.queryParameters;
      } else {
        final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
        text = clipboard?.text ?? '';
        command = value ?? '';
      }

      /// wait for the app to appear
      await Future.delayed(const Duration(milliseconds: 150));
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      if (command == 'paste') {
        if (text.trim().isNotEmpty == true) {
          sendMessage(text, hidePrompt: true);
        }
      } else if (command == TrayCommand.custom.name) {
        messageController.clear();
        sendMessage(
          text,
          hidePrompt: true,
          includeConversationOnSend: params['includeConversation'] == 'true',
          useSystemPrompt: params['includeSystemPrompt'] == 'true',
          onFinishResponse: () {
            if (params['status'] == 'silent') {
              final lastMessage = messagesReversedList.first;
              NotificationService.showNotification(
                selectedChatRoom.characterName,
                lastMessage.content,
                id: text.length.toString(),
              );
            }
          },
        );
      } else if (command == TrayCommand.push_to_talk_message.name) {
        messageController.clear();
        sendMessage(text, hidePrompt: true, onFinishResponse: () async {
          /// if we already have enabled this, it will be played automatically in [onResponseEnd] function
          if (AppCache.autoPlayMessagesFromAi.value == true) return;
          final aiAnswer = messages.value.entries.last.value;
          // use text-to-speech to read the answer
          if (TextToSpeechService.isValid()) {
            isAnswering = true;
            notifyListeners();
            await TextToSpeechService.readAloud(aiAnswer.content,
                onCompleteReadingAloud: () {
              isAnswering = false;
              notifyListeners();
            });
          }
        });
      } else if (command == TrayCommand.show_dialog.name) {
        showDialog(
            context: context!,
            builder: (ctx) => ContentDialog(
                  content: Text(text),
                  actions: [
                    Button(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: Text('Close'.tr),
                    )
                  ],
                ));
      } else if (command == TrayCommand.grammar.name) {
        sendMessage('Check spelling and grammar: "$text"', hidePrompt: true);
      } else if (command == TrayCommand.explain.name) {
        sendMessage('Explain: "$text"', hidePrompt: true);
      } else if (command == TrayCommand.to_rus.name) {
        sendMessage('Translate to Rus: "$text"', hidePrompt: true);
      } else if (command == TrayCommand.to_eng.name) {
        sendMessage('Translate to English: "$text"', hidePrompt: true);
      } else if (command == TrayCommand.improve_writing.name) {
        sendMessage('Improve writing: "$text"', hidePrompt: true);
      } else if (command == TrayCommand.summarize_markdown_short.name) {
        sendMessage('Summarize using markdown. Use short summary: "$text"',
            hidePrompt: false);
      } else if (command == TrayCommand.answer_with_tags.name) {
        HotShurtcutsWidget.showAnswerWithTagsDialog(context!, text);
      } else if (command == TrayCommand.create_new_chat.name) {
        createNewChatRoom();
      } else if (command == TrayCommand.reset_chat.name) {
        clearChatMessages();
      } else if (command == TrayCommand.escape_cancel_select.name) {
      } else if (command == TrayCommand.paste_attachment_silent.name) {
        final base64String = text;
        addHumanMessageToList(
          FluentChatMessage.image(
            id: '$timestamp',
            content: base64String,
            creator: AppCache.userName.value!,
            timestamp: timestamp,
          ),
        );
      } else if (command == TrayCommand.paste_attachment_ai_lens.name) {
        final base64String = text;
        final bytes = base64Decode(base64String);
        addAttachmentAiLens(bytes);
      } else if (command == TrayCommand.generate_image.name) {
        final imagePrompt = text;
        if (imagePrompt.trim().isEmpty) {
          return;
        }
        addHumanMessageToList(
          FluentChatMessage.humanText(
              id: '$timestamp',
              content: text,
              creator: AppCache.userName.value!,
              timestamp: timestamp,
              tokens: await countTokensString(text)),
        );
        isGeneratingImage = true;
        notifyListeners();
        String? apiKey;
        if (AppCache.imageGeneratorApiKey.value != null) {
          apiKey = AppCache.imageGeneratorApiKey.value;
        } else {
          final openAiModel = allModels.value
              .firstWhereOrNull((element) => element.ownedBy == 'openai');
          apiKey = openAiModel?.apiKey;
        }
        if (apiKey == null) {
          return displayErrorInfoBar(
              title: 'API key error',
              message:
                  'No API key found for image generation. Please add an API key in the settings page',
              action: Button(
                child: Text('Settings'.tr),
                onPressed: () {
                  Navigator.of(context!).push(
                    FluentPageRoute(
                      builder: (context) => NewSettingsPage(
                          initialIndex: NewSettingsPage.apiUrlsIndex),
                    ),
                  );
                },
              ));
        }
        try {
          final imageChatMessage = await ImageGeneratorFeature.generateImage(
            prompt: imagePrompt,
            model: AppCache.imageGeneratorModel.value,
            apiKey: apiKey,
            n: 1,
            quality: AppCache.imageGeneratorQuality.value!,
            size: AppCache.imageGeneratorSize.value!,
            style: AppCache.imageGeneratorStyle.value ?? 'natural',
          );
          final newTimestamp = DateTime.now().millisecondsSinceEpoch;
          addCustomMessageToList(
            FluentChatMessage.imageAi(
              id: '$newTimestamp',
              content: imageChatMessage.content,
              creator: imageChatMessage.generatedBy,
              timestamp: newTimestamp,
              imagePrompt: imageChatMessage.revisedPrompt,
            ),
          );
        } catch (e) {
          logError('error generating image $e');
          final time = DateTime.now().millisecondsSinceEpoch;
          addBotErrorMessageToList(
            FluentChatMessage.ai(
              id: '$time',
              content: '$e',
              timestamp: time,
              creator: 'openai error',
            ),
          );
          if (e.toString().contains('401')) {
            displayErrorInfoBar(
                title: 'API key error',
                message: 'Please check your api key',
                action: Button(
                  child: Text('Settings'.tr),
                  onPressed: () {
                    Navigator.of(context!).push(
                      FluentPageRoute(
                        builder: (context) => NewSettingsPage(
                            initialIndex: NewSettingsPage.apiUrlsIndex),
                      ),
                    );
                  },
                ));
          }
        }

        isGeneratingImage = false;
        notifyListeners();
        // wait because the screen will update their size first
        await Future.delayed(const Duration(milliseconds: 1500));
        scrollToEnd();
      } else {
        throw Exception('Unknown command: $command');
      }
    });
  }

  Attachment? fileInput;

  void addFileToInput(XFile file) {
    fileInput = Attachment.fromFile(file);
    notifyListeners();
  }

  void addAttachmentToInput(Attachment attachment) {
    fileInput = attachment;
    notifyListeners();
  }

  Future<void> addAttachmentAiLens(Uint8List bytes,
      {bool showDialog = true}) async {
    final attachment = Attachment.fromInternalScreenshotBytes(bytes);
    addAttachmentToInput(attachment);
    if (showDialog) {
      final isSent = await AiLensDialog.show<bool>(context!, bytes);
      if (isSent != true) {
        removeFileFromInput();
      }
    }
  }

  void addWebResultsToMessages(List<WebSearchResult> webpage) {
    final values = messages.value;
    final dateTime = DateTime.now();
    final id = dateTime.toIso8601String();
    values[id] = FluentChatMessage(
      id: id,
      content: '',
      creator: 'search',
      timestamp: dateTime.millisecondsSinceEpoch,
      type: FluentChatMessageType.webResult,
      webResults: webpage,
    );
    messages.add(values);
    saveToDisk([selectedChatRoom]);
    scrollToEnd();
  }

  void renameCurrentChatRoom(String newName, [bool applyIcon = true]) {
    final chatRoom =
        chatRooms[selectedChatRoomId] ?? chatRooms.entries.first.value;

    chatRoom.chatRoomName = newName.removeWrappedQuotes;
    if (applyIcon) {
      final words = newName.split(' ');
      for (var word in words) {
        if (tagToIconMap.containsKey(word.toLowerCase())) {
          chatRoom.iconCodePoint = tagToIconMap[word.toLowerCase()]!.codePoint;
          break;
        }
        // for (var entry in tagToIconMap.entries) {
        //   if (entry.key.contains(word.toLowerCase())) {
        //     chatRoom.iconCodePoint = entry.value.codePoint;
        //     break;
        //   }
        // }
      }
    }
    selectedChatRoomIdStream.add(selectedChatRoomId);
  }

  /// returns generated info about user
  Future<String> generateUserKnowladgeBasedOnText(String text) async {
    final userName = AppCache.userName.value;
    final response = await retrieveResponseFromPrompt(
      'Based on this messages/conversation/text give me a short sentence to populate knowladge about $userName:'
      '"$text"',
    );
    log('Generated user knowladge: "$response"');
    final personalKnowladge = await AppCache.userInfo.value();
    // final currentDate = DateTime.now();
    // final stringDate = '${currentDate.year}/${currentDate.month}/${currentDate.day}';
    /// I think it would be better to keep it short...
    final finalString = response;
    // append to the end
    AppCache.userInfo.set('$personalKnowladge\n$finalString');
    return response;
  }

  /// returns generated info about user
  Future<void> generateUserKnowladgeBasedOnConversation() async {
    final userName = AppCache.userName.value!;
    final limitedMessages = await getLastMessagesLimitToTokens(4096);
    final mainPrompt =
        summarizeConversationToRememberUser.replaceAll('{user}', userName);
    final messagesAsString = await convertMessagesToString(limitedMessages);
    final finalPrompt = '$mainPrompt\n"$messagesAsString"';
    final messageToSend = ChatMessage.humanText(finalPrompt);
    log('prompt: \n"$finalPrompt"');

    final options = ChatOpenAIOptions(
      model: selectedChatRoom.model.modelName,
      maxTokens: 512,
    );
    AIChatMessage response;
    if (selectedModel.ownedBy == 'openai') {
      response = await openAI!.call([messageToSend], options: options);
    } else {
      response = await localModel!.call([messageToSend], options: options);
    }

    final personalKnowladge = await AppCache.userInfo.value();
    log('Generated user knowladge: "$response"');
    // final currentDate = DateTime.now();
    // final stringDate = '${currentDate.year}/${currentDate.month}/${currentDate.day}';
    /// I think it would be better to keep it short...
    final newKnowladge = response;
    if (newKnowladge.content == 'No important info' ||
        newKnowladge.content == 'No important info.' ||
        newKnowladge.content == '"No important info"') {
      return;
    }
    final appended = '$personalKnowladge\n${newKnowladge.content}';
    // append to the end
    AppCache.userInfo.set('$personalKnowladge\n${newKnowladge.content}');
    if (context != null) {
      displayInfoBar(
        context!,
        builder: (ctx, close) {
          return InfoBar(
            title: Text('Memory updated'.tr),
            content: Text(newKnowladge.content,
                maxLines: 2, overflow: TextOverflow.ellipsis),
            severity: InfoBarSeverity.info,
            isLong: true,
            action: Button(
              onPressed: () async {
                close();
                await Future.delayed(const Duration(milliseconds: 400));
                showDialog(
                  context: context!,
                  builder: (ctx) => const InfoAboutUserDialog(),
                  barrierDismissible: true,
                );
              },
              child: Text('Open memory'.tr),
            ),
          );
        },
        alignment: Alignment.topCenter,
        duration: const Duration(seconds: 6),
      );
    }
    // count tokens for personalKnowladge
    final tokensCount = await Tokenizer().count(appended, modelName: 'gpt-4');
    if (tokensCount > AppCache.maxTokensUserInfo.value!) {
      final shorterKnowladge = await retrieveResponseFromPrompt(
        summarizeUserKnowledge.replaceAll('{knowledge}', appended),
      );
      await AppCache.userInfo.set(shorterKnowladge);
    }
  }

  Future<String> convertMessagesToString(
    List<FluentChatMessage> messages, {
    bool includeSystemMessages = false,
  }) async {
    final aiName = selectedChatRoom.characterName;
    final userName = AppCache.userName.value ?? 'User';
    final result = messages.map((e) {
      if (e.type == FluentChatMessageType.textAi) {
        return '$aiName: ${e.content}';
      }
      if (e.type == FluentChatMessageType.textHuman) {
        return '$userName: ${e.content}';
      }
      if (e.type == FluentChatMessageType.webResult) {
        final results = e.webResults;
        return 'Web search results: ${results!.map((e) => '${e.title}->${e.description}').join(';')}';
      }
      if (includeSystemMessages && e.type == FluentChatMessageType.system) {
        return 'System: ${e.content}';
      }
      return '';
    }).join('\n');
    return result;
  }

  Future<String> convertMessagesToStringWithTimestamp(
    List<FluentChatMessage> messages, {
    bool includeSystemMessages = false,
  }) async {
    final aiName = selectedChatRoom.characterName;
    final userName = AppCache.userName.value ?? 'User';
    final dateFormatter = DateFormat('EEE M/d HH:mm');
    final result = messages.map((e) {
      final date = dateFormatter
          .format(DateTime.fromMillisecondsSinceEpoch(e.timestamp));
      if (e.type == FluentChatMessageType.textAi) {
        return '$date $aiName: ${e.content}';
      }
      if (e.type == FluentChatMessageType.textHuman) {
        return '$date $userName: ${e.content}';
      }
      if (e.type == FluentChatMessageType.webResult) {
        final results = e.webResults;
        return 'Web search results: ${results!.map((e) => '${e.title}->${e.description}').join(';')}';
      }
      if (includeSystemMessages && e.type == FluentChatMessageType.system) {
        return 'System: ${e.content}';
      }
      return '';
    }).join('\n');
    return result;
  }

  Stream<ChatResult>? responseStream;
  StreamSubscription<ChatResult>? listenerResponseStream;

  Future<void> sendMessage(
    String messageContent, {
    bool hidePrompt = false,
    bool sendStream = true,
    void Function()? onFinishResponse,
    void Function()? onMessageSent,
    bool sendAsUser = true,
    bool useSystemPrompt = true,
    bool includeConversationOnSend = true,
    int? seed,
  }) async {
    bool isFirstMessage = messages.value.isEmpty;
    bool isThirdMessage = messages.value.length == 2;
    final isToolsEnabled = AppCache.gptToolCopyToClipboardEnabled.value == true;
    String? ragPart;
    if (isFirstMessage && useSystemPrompt) {
      // regenerate system message to update time/weather etc
      // This is a first message, so it will regenerate the system message from the global prompt
      // for chat that been cleared. This is expected bug!
      selectedChatRoom.systemMessage = await getFormattedSystemPrompt(
        basicPrompt: (selectedChatRoom.systemMessage ?? '').isEmpty
            ? defaultGlobalSystemMessage
            : selectedChatRoom.systemMessage!
                .split(contextualInfoDelimeter)
                .first,
      );

      /// Name chat room
      if (AppCache.useAiToNameChat.value == false) {
        final first50CharsIfPossible = messageContent.length > 50
            ? messageContent.substring(0, 50)
            : messageContent;
        renameCurrentChatRoom(first50CharsIfPossible);
      }
    }
    if (messageContent.contains(TrayCommand.generate_image.name)) {
      onTrayButtonTapCommand(
        messageContent,
        TrayCommand.generate_image.name,
      );
      return;
    }
    if (isThirdMessage && AppCache.useAiToNameChat.value == true) {
      String lastMessages = await getLastFewMessagesForContextAsString();
      lastMessages += ' Human: $messageContent';
      retrieveResponseFromPrompt(
        '${nameTopicPrompt.replaceAll('{lang}', I18n.currentLocale.languageCode)} "$lastMessages"',
      ).then(renameCurrentChatRoom);
    }
    // Stops.
    if (isWebSearchEnabled) {
      await _sendMessageWebSearch(messageContent);
      return;
    }
    if (AppCache.useRAG.value == true) {
      final String? openAiKey = allModels.valueOrNull
          ?.firstWhereOrNull(
              (element) => element.ownedBy == OwnedByEnum.openai.name)
          ?.apiKey;
      final enhancedPrompt = await RAGOpenAi.getEnhancedPromptWithDocs(
        query: messageContent,
        apiKey: openAiKey!,
        scoreThreshold: AppCache.ragThreshold.value ?? 0.5,
        documents: [
          // test to see if model will answer based ONLY on this
          Document(
            id: 'Flutter docs',
            pageContent: 'Flutter is a game engine builder for mobile apps',
          ),
          Document(
            id: 'Personal knowledge base',
            pageContent: 'Donald likes apples',
          ),
        ],
      );
      ragPart = enhancedPrompt;
      return;
    }

    // to prevent empty messages posted to the chat
    if (messageContent.isNotEmpty && sendAsUser) {
      /// add additional styles to the message
      messageContent = modifyMessageStyle(messageContent);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      addHumanMessageToList(
        FluentChatMessage.humanText(
          id: '$timestamp',
          content: messageContent,
          creator: AppCache.userName.value ?? 'User',
          timestamp: timestamp,
        ),
      );
    }
    if (sendAsUser == false) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      addBotMessageToList(
        FluentChatMessage.ai(
          id: '$timestamp',
          content: messageContent,
          creator: selectedChatRoom.characterName,
          timestamp: timestamp,
        ),
      );
    }

    final isImageAttached =
        fileInput != null && fileInput!.mimeType?.contains('image') == true;
    final isTextFileAttached =
        fileInput != null && fileInput!.mimeType?.contains('text') == true;
    final isWordFileAttached =
        fileInput != null && (fileInput!.name.endsWith('.docx'));
    final isExcelFileAttached = fileInput != null &&
        (fileInput!.name.endsWith('.xlsx') || fileInput!.name.endsWith('.xls'));
    if (isImageAttached) {
      final bytes = await fileInput!.readAsBytes();
      final newBytes = await ImageUtil.resizeAndCompressImage(bytes);
      final base64 = base64Encode(newBytes);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      addCustomMessageToList(
        FluentChatMessage.image(
          id: '$timestamp',
          content: base64,
          creator: AppCache.userName.value!,
          timestamp: timestamp,
        ),
      );
    }
    if (isTextFileAttached) {
      final fileName = fileInput!.name;
      final bytes = await fileInput!.readAsBytes();
      final contentString = utf8.decode(bytes);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      addCustomMessageToList(
        FluentChatMessage(
          id: '$timestamp',
          content: contentString,
          creator: AppCache.userName.value!,
          timestamp: timestamp,
          type: FluentChatMessageType.file,
          fileName: fileName,
          path: fileInput?.path,
        ),
      );
    }
    if (isWordFileAttached) {
      final fileName = fileInput!.name;
      final bytes = await fileInput!.readAsBytes();
      final contentString = docxToText(bytes);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      addCustomMessageToList(
        FluentChatMessage(
          id: '$timestamp',
          content: contentString,
          creator: AppCache.userName.value!,
          timestamp: timestamp,
          type: FluentChatMessageType.file,
          fileName: fileName,
          path: fileInput?.path,
        ),
      );
    }
    if (isExcelFileAttached) {
      final fileName = fileInput!.name;
      final bytes = await fileInput!.readAsBytes();
      final excelToJson = ExcelToJson();
      final contentString = await excelToJson.convert(bytes);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      addCustomMessageToList(
        FluentChatMessage(
          id: '$timestamp',
          content: contentString ?? '<No data available>',
          creator: AppCache.userName.value!,
          timestamp: timestamp,
          type: FluentChatMessageType.file,
          fileName: fileName,
          path: fileInput?.path,
        ),
      );
    }
    if (fileInput != null) {
      // wait for the file to be populated. Otherwise addHumanMessage can be sent before the file is populated
      await Future.delayed(const Duration(milliseconds: 50));
    }
    if (messageContent.isNotEmpty) isAnswering = true;
    notifyListeners();
    final messagesToSend = <ChatMessage>[];
    if (includeConversationGlobal) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (includeConversationOnSend) {
        final lastMessages = await getLastMessagesLimitToTokens(
          selectedChatRoom.maxTokenLength -
              (selectedChatRoom.systemMessageTokensCount ?? 0),
          allowImages: true,
        );
        // if false it will just skip all messages in chat for this case
        final lastMessagesLangChain =
            lastMessages.map((e) => e.toLangChainChatMessage());
        messagesToSend.addAll(lastMessagesLangChain);
      } else {
        messagesToSend.add(
          sendAsUser
              ? HumanChatMessage(
                  content: ChatMessageContent.text(messageContent),
                )
              : AIChatMessage(content: messageContent),
        );
      }

      if (selectedChatRoom.systemMessage?.isNotEmpty == true &&
          useSystemPrompt) {
        messagesToSend.insert(
            0, SystemChatMessage(content: selectedChatRoom.systemMessage!));
      }
      // if (messages.value.length > 1)
      // messagesToSend.insert(
      //     0, ChatMessage.system('Previous chat hidden due to overflow'));
    }
    if (!includeConversationGlobal) {
      if (selectedChatRoom.systemMessage?.isNotEmpty == true &&
          useSystemPrompt) {
        final systemMessage = await getFormattedSystemPrompt(
          basicPrompt: selectedChatRoom.systemMessage!,
        );
        messagesToSend.add(SystemChatMessage(content: systemMessage));
      }

      if (messageContent.isNotEmpty)
        messagesToSend.add(
          sendAsUser
              ? HumanChatMessage(
                  content: ChatMessageContent.text(messageContent),
                )
              : AIChatMessage(content: messageContent),
        );
      if (isImageAttached) {
        messagesToSend.add(
          HumanChatMessage(
            content: ChatMessageContent.image(
              data: base64Encode(await fileInput!.readAsBytes()),
              mimeType: fileInput!.mimeType ?? 'image/jpeg',
            ),
          ),
        );
      }
    }
    onMessageSent?.call();
    String responseId = '';
    final options = ChatOpenAIOptions(
      model: selectedChatRoom.model.modelName,
      user: AppCache.userName.value,
      maxTokens: selectedChatRoom.maxTokensResponseLenght != null
          ? (selectedChatRoom.maxTokensResponseLenght! -
              (selectedChatRoom.systemMessageTokensCount ?? 0))
          : null,
      temperature: selectedChatRoom.temp,
      topP: selectedChatRoom.topP,
      frequencyPenalty: selectedChatRoom.repeatPenalty,
      seed: seed ?? selectedChatRoom.seed,
      toolChoice: isToolsEnabled ? const ChatToolChoiceAuto() : null,
      tools: isToolsEnabled
          ? [
              if (AppCache.gptToolCopyToClipboardEnabled.value!)
                ToolSpec(
                  name: 'copy_to_clipboard_tool',
                  description: 'Tool to copy text to user clipboard',
                  inputJsonSchema: copyToClipboardFunctionParameters,
                ),
              if (AppCache.gptToolAutoOpenUrls.value!)
                ToolSpec(
                  name: 'auto_open_urls_tool',
                  description: 'Tool to open urls in the browser',
                  inputJsonSchema: autoOpenUrlParameters,
                ),
              if (AppCache.gptToolGenerateImage.value!)
                ToolSpec(
                  name: 'generate_image_tool',
                  description: 'Tool to generate image',
                  inputJsonSchema: generateImageParameters,
                ),
              if (AppCache.gptToolRememberInfo.value!)
                ToolSpec(
                  name: 'remember_info_tool',
                  description:
                      'Tool to remember info. Use it to store info about user or important notes',
                  inputJsonSchema: rememberInfoParameters,
                ),
            ]
          : null,
    );
    if (ragPart != null) {
      // insert message above the last message
      messagesToSend.insert(
        messagesToSend.length - 1,
        SystemChatMessage(content: ragPart),
      );
    }
    try {
      initModelsApi();

      if (!sendStream) {
        late AIChatMessage response;
        if (selectedChatRoom.model.ownedBy == OwnedByEnum.openai.name) {
          response = await openAI!.call(messagesToSend, options: options);
        } else {
          response = await localModel!.call(messagesToSend, options: options);
        }
        if (response.toolCalls.isNotEmpty) {
          final lastChar = response.toolCalls.first.argumentsRaw;
          if (lastChar == '}') {
            final decoded = jsonDecode(response.toolCalls.first.argumentsRaw);
            _onToolsResponseEnd(messageContent, decoded, response.content);
          }
        }
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        addBotMessageToList(
          FluentChatMessage.ai(
            id: '$timestamp',
            content: response.content,
            timestamp: timestamp,
            tokens: await countTokensString(response.content),
            creator: selectedChatRoom.characterName,
          ),
        );
        saveToDisk([selectedChatRoom]);
        isAnswering = false;
        return;
      }
      if (selectedChatRoom.model.ownedBy == OwnedByEnum.openai.name) {
        responseStream =
            openAI!.stream(PromptValue.chat(messagesToSend), options: options);
      } else {
        if (selectedChatRoom.model.ownedBy == OwnedByEnum.gemini.name) {
          throw Exception('Gemini is not supported yet');
          // TODO: add more models
        } else if (selectedChatRoom.model.ownedBy == OwnedByEnum.claude.name) {
          throw Exception('Claude is not supported yet');
          // TODO: add more models
        }
        responseStream = localModel!
            .stream(PromptValue.chat(messagesToSend), options: options);
      }

      String functionCallString = '';
      String functionName = '';
      String responseContent = '';
      int chunkNumber = 0;
      int tokensReceivedInResponse = 0;
      int tokensSentInResponse = 0;

      listenerResponseStream = responseStream!.listen(
        (final chunk) {
          chunkNumber++;

          if (chunkNumber == 1) {
            if (fileInput?.isInternalScreenshot == true) {
              FileUtils.deleteFile(fileInput!.path);
            }
            fileInput = null;
            notifyListeners();
          }
          final message = chunk.output;
          // log tokens
          if (message.toolCalls.isEmpty && message.content.isNotEmpty) {
            responseId = chunk.id;
            responseContent += message.content;
            final time = DateTime.now().millisecondsSinceEpoch;
            addBotMessageToList(
              FluentChatMessage.ai(
                id: responseId,
                content: message.content,
                timestamp: time,
                creator: selectedChatRoom.characterName,
              ),
            );
          } else {
            if (message.toolCalls.isNotEmpty) {
              functionCallString += message.toolCalls.first.argumentsRaw;
              if (message.toolCalls.first.name.isNotEmpty == true) {
                functionName = message.toolCalls.first.name;
              }
            }
          }
          if (chunk.usage.totalTokens != null) {
            log('Total tokens: ${chunk.usage.toString()}');
            totalSentTokens += chunk.usage.promptTokens ?? 0;
            totalReceivedTokens += chunk.usage.responseTokens ?? 0;
            tokensReceivedInResponse += chunk.usage.responseTokens ?? 0;
            tokensSentInResponse += chunk.usage.promptTokens ?? 0;
          }
          // print('function: $functionCallString, chunk.finishReason: ${chunk.finishReason}');
          if (chunk.finishReason == FinishReason.stop) {
            /// TODO: add more logic here
            updateChatRoomTimestamp();
            saveToDisk([selectedChatRoom]);
            isAnswering = false;
            notifyListeners();
            onResponseEnd(messageContent, responseId);
            if (functionCallString.isNotEmpty) {
              final lastChar =
                  functionCallString[functionCallString.length - 1];
              if (lastChar == '}') {
                final decoded = jsonDecode(functionCallString);
                _onToolsResponseEnd(messageContent, decoded, functionName);
              }
            }
          } else if (chunk.finishReason == FinishReason.length) {
            /// Maximum tokens reached
            saveToDisk([selectedChatRoom]);
            isAnswering = false;
            notifyListeners();
          } else if (chunk.finishReason == FinishReason.toolCalls) {
            final lastChar = functionCallString[functionCallString.length - 1];
            if (lastChar == '}') {
              final decoded = jsonDecode(functionCallString);
              _onToolsResponseEnd(messageContent, decoded, functionName);
            }
            isAnswering = false;
          }
        },
        onDone: () async {
          onFinishResponse?.call();
          updateChatRoomTimestamp();
          if (tokensReceivedInResponse == 0) {
            log('No tokens received in response. Recalculate locally');
            tokensReceivedInResponse = await countTokensString(responseContent);
            totalTokensByMessages += tokensReceivedInResponse;
            totalReceivedTokens += tokensReceivedInResponse;
          }
          if (tokensSentInResponse == 0) {
            if (responseContent.isEmpty) {
              final time = DateTime.now().millisecondsSinceEpoch;
              addBotErrorMessageToList(
                FluentChatMessage.ai(
                    id: time.toString(),
                    content: 'Empty response. Try disabling tools',
                    creator: 'error',
                    timestamp: time,
                    buttons: [
                      MesssageListTileButtons.disable_tools_btn.name,
                    ]),
              );
              return;
            }
            // tokensSentInResponse = await countTokensString(messageContent);
            // totalSentTokens += tokensSentInResponse;
          }
          totalTokensByMessages = await countTokensFromMessagesCached([
            if (selectedChatRoom.systemMessage != null)
              FluentChatMessage.system(
                id: '-1',
                content: selectedChatRoom.systemMessage!,
              ),
            ...messages.value.values
          ]);
        },
        onError: (e, stack) {
          logError('Error while answering: $e', stack);
          addBotErrorMessageToList(
            FluentChatMessage.ai(
              id: DateTime.now().millisecondsSinceEpoch.toString(),
              content: '$e',
              creator: 'error',
            ),
          );
          isAnswering = false;
          notifyListeners();
        },
      );
    } catch (e, stack) {
      logError('Error while answering: $e', stack);
      addBotErrorMessageToList(
        FluentChatMessage.ai(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: '$e',
          creator: 'error',
        ),
      );
      isAnswering = false;
      notifyListeners();
    }
  }

  Future<void> _sendMessageWebSearch(String messageContent) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    await addHumanMessageToList(
      FluentChatMessage.humanText(
        id: '$timestamp',
        content: messageContent,
        creator: AppCache.userName.value!,
        timestamp: timestamp,
        tokens: await countTokensString(messageContent),
      ),
    );
    if (selectedModel.ownedBy == OwnedByEnum.openai.name) {
      isAnswering = true;
      notifyListeners();
      try {
        final messageResult = await OpenAiFeatures.webSearch(
          messageContent,
          apiKey: selectedChatRoom.model.apiKey,
          city: AppCache.userCityName.value,
        );
        addCustomMessageToList(messageResult);
      } catch (e) {
        displayErrorInfoBar(
          title: 'Error while searching',
          message: '$e',
        );
        logError('Error while searching: $e');
      } finally {
        isAnswering = false;
        notifyListeners();
      }
      return;
    }
    final lastMessages = await getLastFewMessagesForContextAsString();
    String searchPrompt = await retrieveResponseFromPrompt(
      '$webSearchPrompt """$lastMessages"""\n GIVE ME RESULT ONLY IN THIS FORMAT. DON\'T ADD ANYTHING ELSE'
      '{"query":"<your response>"}',
    );
    isAnswering = true;
    notifyListeners();
    final scrapper = WebScraper();
    try {
      final decoded = jsonDecode(searchPrompt);
      searchPrompt = decoded['query'];
    } catch (e) {
      // do nothing
    }
    try {
      final results = await scrapper.search(searchPrompt);
      if (AppCache.scrapOnlyDecription.value!) {
        final List<WebSearchResult> shortResults =
            results.take(15).map((e) => e).toList();
        addWebResultsToMessages(shortResults);
        await _answerBasedOnWebResults(shortResults,
            'User asked: $messageContent. Search prompt from search Agent: "$searchPrompt"');
      } else {
        final threeRessults = results.take(3).map((e) => e).toList();
        addWebResultsToMessages(threeRessults);
        await _answerBasedOnWebResults(threeRessults, messageContent);
      }
    } catch (e) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      addBotErrorMessageToList(FluentChatMessage.ai(
        id: '$timestamp',
        content: 'Error while searching: $e',
        creator: 'system',
        timestamp: timestamp,
      ));
    }

    isAnswering = false;
    notifyListeners();
  }

  bool isGeneratingQuestionHelpers = false;
  List<CustomPrompt> questionHelpers = [];

  void onResponseEnd(String userContent, String id) async {
    final FluentChatMessage? response = messages.value[id];
    if (response == null) return;
    if (response.type != FluentChatMessageType.textAi) {
      logError('aiResponse is not from AI');
      return;
    }

    if (AppCache.autoPlayMessagesFromAi.value!) {
      if (TextToSpeechService.isValid()) {
        isAnswering = true;
        notifyListeners();
        await TextToSpeechService.readAloud(
          response.content,
          onCompleteReadingAloud: () {
            isAnswering = false;
            notifyListeners();
          },
        );
      }
    }
    AnnoyFeature.lastTimeAiAnswered = DateTime.now();

    /// Will restart autonomous mode and all timers if enabled in cache settings
    AnnoyFeature.init();

    if (AppCache.enableQuestionHelpers.value == true) {
      isGeneratingQuestionHelpers = true;
      questionHelpers.clear();
      notifyListeners();
      agentMessageActions
          .askForPromptsFromLLM(userContent, response.content)
          .then(
        (questionMessages) {
          if (questionMessages.isNotEmpty) {
            questionHelpers.addAll(questionMessages);
          }
          isGeneratingQuestionHelpers = false;
          notifyListeners();
        },
        onError: (e, stack) {
          logError('Error while generating question helpers: $e', stack);
          isGeneratingQuestionHelpers = false;
          notifyListeners();
        },
      );
    }

    /// calculate tokens and swap message
    final tokens = await countTokensString(response.content);
    final newResponse = response.copyWith(tokens: tokens);
    final values = messages.value;
    values[id] = newResponse;
    messages.add(values);

    for (var action in onMessageActions.value) {
      if (action.isEnabled == false) continue;
      final hasMatch = action.regExp.hasMatch(response.content);
      if (hasMatch) {
        final match = action.regExp.firstMatch(response.content);
        if (action.actionEnum == OnMessageActionEnum.copyTextInsideQuotes) {
          final text = match?.group(1);
          await Clipboard.setData(ClipboardData(text: text ?? ''));
          displayCopiedToClipboard();
        } else if (action.actionEnum == OnMessageActionEnum.copyText) {
          await Clipboard.setData(ClipboardData(text: response.content));
          displayCopiedToClipboard();
        } else if (action.actionEnum == OnMessageActionEnum.remember) {
          final lastFewMessages = await getLastFewMessages(count: 3);
          final lastMessagesAsString =
              await convertMessagesToString(lastFewMessages);
          await generateUserKnowladgeBasedOnText(lastMessagesAsString);
        } else if (action.actionEnum == OnMessageActionEnum.generateImage) {
          _onResponseEndGenerateImage(response, action);
        } else if (action.actionEnum == OnMessageActionEnum.openUrl) {
          await launchUrlString(match!.group(1)!);
        } else if (action.actionEnum == OnMessageActionEnum.runShellCommand) {
          final result = await ShellDriver.runShellCommand(match!.group(1)!);
          if (result.trim().isEmpty) {
            addMessageSystem(
                'Shell command output: EMPTY result or returned an error');
          } else {
            addMessageSystem('Shell command result: $result');
          }
          // wait for the message to be added
          await Future.delayed(const Duration(milliseconds: 50));
          sendMessage('Answer based on the result (answer short)',
              onMessageSent: () {
            final lastMessage = messages.value.entries.last;
            deleteMessage(lastMessage.key, false);
          });
        }
      }
    }
  }

  /// Do not use it often because we don't know how many tokens it will consume
  Future<List<FluentChatMessage>> getLastFewMessages({int count = 15}) async {
    final values = messages.value;
    final list = <FluentChatMessage>[];
    // Start from end to get last messages
    final messagesIterator = values.values.toList().reversed;
    int countAdded = 0;
    for (var message in messagesIterator) {
      if (countAdded >= count) break;
      if (message.type != FluentChatMessageType.webResult) {
        // map custom messages to human messages because openAi doesn't support them
        if (message.type == FluentChatMessageType.file) {
          // insert at start to maintain order
          list.insert(0, message);
        } else if (message.type == FluentChatMessageType.image ||
            message.type == FluentChatMessageType.imageAi) {
          if (selectedChatRoom.model.imageSupported) list.insert(0, message);
        } else {
          // insert at start to maintain order
          list.insert(0, message);
        }
        countAdded++;
      }
    }
    // append current global system message to the very beginning
    if (selectedChatRoom.systemMessage?.isNotEmpty == true) {
      // if we exceed the limit, put the system message at the start
      // and add system message "Previous messages were trimmed"
      final timestamp = DateTime.now().millisecondsSinceEpoch;

      list.insert(
        0,
        FluentChatMessage(
          id: '$timestamp',
          content: selectedChatRoom.systemMessage ?? defaultGlobalSystemMessage,
          creator: 'system',
          timestamp: timestamp,
          type: FluentChatMessageType.system,
        ),
      );
      if (values.length > count) {
        list.insert(
          1,
          FluentChatMessage(
            id: '_$timestamp',
            content: '(Previous messages were trimmed)',
            creator: 'system',
            timestamp: timestamp,
            type: FluentChatMessageType.system,
          ),
        );
      }
    }

    return list;
  }

  /// Retrieves the last messages from the chat limited by the specified token count.
  ///
  /// This method iterates through the messages and accumulates their token counts
  /// until the specified token limit is reached. It supports different types of
  /// messages including `AIChatMessage`, `HumanChatMessage`, `SystemChatMessage`, and
  /// `TextFileCustomMessage`. If the `allowOverflow` parameter is set to true and no
  /// messages have been added to the result, the last message will be added regardless
  /// of the token limit.
  /// if [stripMessage] is true, it will strip the message from new lines and double spaces
  Future<List<FluentChatMessage>> getLastMessagesLimitToTokens(
    int tokens, {
    bool allowOverflow = true,
    bool allowImages = false,
    bool stripMessage = true,
  }) async {
    int currentTokens = 0;
    // for debug purposes
    // int currentTokensRaw = 0;
    // int currentTokensStripped = 0;
    final result = <FluentChatMessage>[];
    final chatModel = selectedChatRoom.model;

    /// We need to count from the bottom to the top. We cant use messagesReversedList because it takes time to populate it
    for (var message in messages.value.values.toList().reversed) {
      if (message.type == FluentChatMessageType.textAi ||
          message.type == FluentChatMessageType.textHuman ||
          message.type == FluentChatMessageType.system ||
          message.type == FluentChatMessageType.file) {
        var tokensCount = message.tokens;
        // await modelCounter.countTokens(PromptValue.string(message.content));
        if ((currentTokens + tokensCount) > tokens) {
          if (kDebugMode) {
            print(
                '[BREAK beacuse of limit] Tokens: $tokensCount; message: ${message.content.split('\n').first} ');
          }
          break;
        }
        // currentTokensRaw += message.tokens;
        if (stripMessage) {
          final countNewLines = message.content.split('\n\n').length;
          if (countNewLines > 1) {
            final newContent =
                message.content.replaceAll('\n\n', ' ').replaceAll('  ', ' ');
            // rough estimation of tokens because each model can count them differently
            tokensCount = message.tokens - countNewLines + 1;
            message =
                message.copyWith(content: newContent, tokens: tokensCount);
          }
        }
        currentTokens += tokensCount;
        // print(
        //     '${message.timestamp} Tokens stripped: $currentTokens; Tokens raw: $currentTokensRaw;');
        result.add(message);
      } else if (allowImages &&
          (message.type == FluentChatMessageType.image ||
              message.type == FluentChatMessageType.imageAi)) {
        if (chatModel.imageSupported) result.add(message);
      }
    }
    // if allowOverflow is true and we didn't add any element, add only the last one
    final messagesOriginal = messages.value.values;
    final lastElement = messagesOriginal.last;
    if (result.length == 1 && allowOverflow) {
      if (lastElement.type == FluentChatMessageType.textHuman) {
        final indexLast = messagesOriginal.length - 1;
        final beforeLast = indexLast == 0
            ? null
            : messagesOriginal.elementAtOrNull(indexLast - 1);

        /// The last message can be human message, so we need to add it and the previous one
        if (beforeLast != null) result.add(beforeLast);
      }
    } else if (result.isEmpty && allowOverflow) {
      result.add(lastElement);
    }
    // print(
    //     'SUM Tokens stripped: $currentTokensStripped; Tokens raw: $currentTokensRaw;');

    /// because we counted from the bottom to top we need to invert it to original order
    return result.reversed.toList();
  }

  Future<String> getLastFewMessagesForContextAsString(
      {int maxTokensLenght = 1024}) async {
    final lastMessages = await getLastMessagesLimitToTokens(maxTokensLenght);
    final userName = AppCache.userName.value ?? 'User';
    final characterName = selectedChatRoom.characterName;
    return lastMessages.map((e) {
      if (e.type == FluentChatMessageType.textHuman) {
        return '$userName: ${e.content}';
      }
      if (e.type == FluentChatMessageType.textAi) {
        return '$characterName: ${e.content}';
      }
      if (e.type == FluentChatMessageType.webResult) {
        final results = e.webResults;
        return 'Web search results: ${results?.map((e) => '${e.title}->${e.description}').join(';')}';
      }
      return '';
    }).join('\n');
  }

  Future<int> countTokensString(String text) async {
    if (text.isEmpty) return 0;
    final options = ChatOpenAIOptions(model: selectedChatRoom.model.modelName);
    if (selectedModel.ownedBy == 'openai') {
      return openAI!.countTokens(PromptValue.string(text), options: options);
    } else {
      return (localModel ?? openAI)!
          .countTokens(PromptValue.string(text), options: options);
    }
  }

  Future<int> countTokensFromMessages(List<ChatMessage> messages) async {
    int tokens = 0;
    if (selectedChatRoom.model.ownedBy == 'openai') {
      tokens = await openAI!.countTokens(PromptValue.chat(messages),
          options: ChatOpenAIOptions(
            model: selectedChatRoom.model.modelName,
          ));
    } else {
      tokens = await openAI!.countTokens(PromptValue.chat(messages),
          options: ChatOpenAIOptions(
            // for all unknown models we assume it's gpt 3.5 turbo
            model: 'gpt-3.5-turbo-16k-0613',
          ));
    }
    return tokens;
  }

  /// will calculate tokens for messages using cached tokens in each message.
  ///
  /// If the message has tokens, it will use them. Otherwise, it will use Future to calculate the tokens for the message.
  Future<int> countTokensFromMessagesCached(
      Iterable<FluentChatMessage> messages) async {
    int tokens = 0;
    for (int i = 0; i < messages.length; i++) {
      var message = messages.elementAt(i);
      if (message.tokens > 0) {
        tokens += message.tokens;
      } else {
        if (message.type == FluentChatMessageType.textAi ||
            message.type == FluentChatMessageType.textHuman ||
            message.type == FluentChatMessageType.system) {
          tokens += await countTokensString(message.content);
        }
      }
    }
    return tokens;
  }

  /// Will not use chat history.
  /// Use [showPromptInChat] to show [messageContent] as a request in the chat
  /// Use [showImageInChat] to show [imageBase64] in the chat
  /// Use [systemMessage] to put a system message in the request
  Future sendSingleMessage(
    String messageContent, {
    String? systemMessage,
    String? imageBase64,
    bool showPromptInChat = false,
    bool showImageInChat = false,
    bool sendAsStream = true,
  }) async {
    final messagesToSend = <ChatMessage>[];
    if (imageBase64 == null) {
      if (systemMessage != null) {
        messagesToSend.add(SystemChatMessage(content: systemMessage));
      }
      messagesToSend.add(
          HumanChatMessage(content: ChatMessageContent.text(messageContent)));
    } else {
      messagesToSend.add(
        HumanChatMessage(
            content: ChatMessageContent.multiModal([
          ChatMessageContent.text(messageContent),
          ChatMessageContent.image(data: imageBase64, mimeType: 'image/jpeg'),
        ])),
      );
    }
    if (showPromptInChat) {
      String messageId = DateTime.now().millisecondsSinceEpoch.toString();
      final tokens = await countTokensString(messageContent);
      addHumanMessageToList(
        FluentChatMessage.humanText(
          id: messageId,
          content: messageContent,
          creator: AppCache.userName.value!,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          tokens: tokens,
        ),
      );
    }
    if (showImageInChat && imageBase64 != null) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      addHumanMessageToList(
        FluentChatMessage.image(
          id: '$timestamp',
          content: imageBase64,
          creator: AppCache.userName.value!,
          timestamp: timestamp,
        ),
      );
    }
    final options = ChatOpenAIOptions(model: selectedChatRoom.model.modelName);
    String responseId = DateTime.now().millisecondsSinceEpoch.toString();
    try {
      if (sendAsStream) {
        Stream<ChatResult> stream;
        if (selectedModel.ownedBy == 'openai') {
          stream = openAI!
              .stream(PromptValue.chat(messagesToSend), options: options);
        } else {
          stream = localModel!
              .stream(PromptValue.chat(messagesToSend), options: options);
        }
        await stream.forEach(
          (final chunk) {
            final message = chunk.output;
            totalSentTokens += chunk.usage.promptTokens ?? 0;
            totalReceivedTokens += chunk.usage.responseTokens ?? 0;
            responseId = chunk.id;
            // total is the overral tokens count in current chat. Not in the message
            totalTokensByMessages += chunk.usage.responseTokens ?? 0;
            addBotMessageToList(
              FluentChatMessage.ai(
                id: responseId,
                content: message.content,
                tokens: chunk.usage.responseTokens ?? 0,
                creator: selectedChatRoom.characterName,
              ),
            );
            if (chunk.finishReason == FinishReason.stop) {
              saveToDisk([selectedChatRoom]);
            } else if (chunk.finishReason == FinishReason.length) {
              saveToDisk([selectedChatRoom]);
            }
          },
        );
      } else if (!sendAsStream) {
        AIChatMessage response;
        if (selectedModel.ownedBy == 'openai') {
          response = await openAI!.call(messagesToSend, options: options);
        } else {
          response = await localModel!.call(messagesToSend, options: options);
        }
        addBotMessageToList(
            FluentChatMessage.ai(id: responseId, content: response.content));
        saveToDisk([selectedChatRoom]);
        notifyListeners();
      }
    } catch (e) {
      logError('Error while sending single message: $e');
      final id = DateTime.now().millisecondsSinceEpoch.toString();
      addBotErrorMessageToList(
        FluentChatMessage.system(
            content: 'Error while sending single message: $e', id: id),
      );
      fileInput = null;
      notifyListeners();
    }
  }

  /// Will not use chat history.
  /// Will not populate messages
  /// Will increase token counter
  Future<String> retrieveResponseFromPrompt(
    String message, {
    String? systemMessage,
    List<FluentChatMessage> additionalPreMessages = const [],
  }) async {
    final messagesToSend = <ChatMessage>[];

    if (systemMessage != null) {
      messagesToSend.add(SystemChatMessage(content: systemMessage));
    }
    if (additionalPreMessages.isNotEmpty) {
      messagesToSend
          .addAll(additionalPreMessages.map((e) => e.toLangChainChatMessage()));
    }

    messagesToSend
        .add(HumanChatMessage(content: ChatMessageContent.text(message)));
    if (kDebugMode) {
      log('messagesToSend: $messagesToSend');
    }

    AIChatMessage response;
    final options = ChatOpenAIOptions(
      model: selectedChatRoom.model.modelName,
    );
    var sentTokens = selectedChatRoom.totalSentTokens ?? 0;
    var respTokens = selectedChatRoom.totalReceivedTokens ?? 0;
    if (selectedModel.ownedBy == 'openai') {
      sentTokens += await openAI!.countTokens(PromptValue.chat(messagesToSend));
      response = await openAI!.call(messagesToSend, options: options);
      respTokens +=
          await openAI!.countTokens(PromptValue.string(response.content));
    } else {
      sentTokens +=
          await localModel!.countTokens(PromptValue.chat(messagesToSend));
      response = await localModel!.call(messagesToSend, options: options);
      respTokens +=
          await localModel!.countTokens(PromptValue.string(response.content));
    }
    if (sentTokens != selectedChatRoom.totalSentTokens) {
      selectedChatRoom.totalSentTokens = sentTokens;
    }
    if (respTokens != selectedChatRoom.totalReceivedTokens) {
      selectedChatRoom.totalReceivedTokens = respTokens;
    }
    if (kDebugMode) {
      log('response: $response');
    }
    return response.content;
  }

  @Deprecated('Don not use it to set value. Only for StreamBuilder')

  /// Calculated by current messages in the chat.
  final BehaviorSubject<int> totalTokensForCurrentChatByMessages =
      BehaviorSubject.seeded(0);
  set totalTokensByMessages(int value) =>
      // ignore: deprecated_member_use_from_same_package
      totalTokensForCurrentChatByMessages.add(value);

  /// Calculated by current messages in the chat.
  // ignore: deprecated_member_use_from_same_package
  int get totalTokensByMessages => totalTokensForCurrentChatByMessages.value;

  @Deprecated('Don not use it to set value. Only for StreamBuilder')
  final BehaviorSubject<int> totalSentForCurrentChat =
      BehaviorSubject.seeded(0);
  set totalSentTokens(int value) {
    // ignore: deprecated_member_use_from_same_package
    totalSentForCurrentChat.add(value);
    selectedChatRoom.totalSentTokens = value;
  }

  // ignore: deprecated_member_use_from_same_package
  int get totalSentTokens => totalSentForCurrentChat.value;

  BehaviorSubject<int> totalReceivedForCurrentChat = BehaviorSubject.seeded(0);
  set totalReceivedTokens(int value) {
    totalReceivedForCurrentChat.add(value);
    selectedChatRoom.totalReceivedTokens = value;
  }

  int get totalReceivedTokens => totalReceivedForCurrentChat.value;

  void addBotMessageToList(FluentChatMessage message) {
    final values = messages.value;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final lastMessage = values[message.id];
    String newString = '';
    if (lastMessage != null) {
      newString = lastMessage.concat(message.content).content;
    } else {
      newString = message.content;
    }
    values[message.id] = FluentChatMessage(
      id: message.id,
      content: newString,
      creator: message.creator,
      timestamp: timestamp,
      type: message.type,
    );
    // if (kDebugMode) print(newString);
    messages.add(values);
    autoScrollToEnd(withDelay: false);
  }

  Future<void> addBotErrorMessageToList(FluentChatMessage message) async {
    final values = messages.value;
    values[message.id] = message;
    messages.add(values);
    await scrollToEnd();
    updateChatRoomTimestamp();
    final content = message.content;
    if (content.contains('Tool calling is not supported for model')) {
      ToolCallingNotSupportedDialog.show(context!);
    }
    if (content.contains('Multimodal is not supported for model')) {
      await MultimodalNotSupportedDialog.show(context!);
      // remove last 2 messages from list
      final values = messages.value;
      final indexError = values.keys.toList().indexOf(message.id);
      final newIdPrev = values.keys.toList()[indexError - 1];
      values.remove(message.id);
      values.remove(newIdPrev);
      messages.add(values);
      saveToDisk([selectedChatRoom]);
    }
  }

  Future addHumanMessageToList(FluentChatMessage message) async {
    if (message.content.isEmpty) return;

    final values = messages.value;
    values[message.id] = message;
    messages.add(values);
    saveToDisk([selectedChatRoom]);
    scrollToEnd();
    updateChatRoomTimestamp();
    notifyListeners();

    if (message.type == FluentChatMessageType.textHuman) {
      final tokens = await countTokensString(message.content);
      final updatedMessage = message.copyWith(tokens: tokens);
      values[message.id] = updatedMessage;
      messages.add(values);
      notifyListeners();
    }
  }

  void addCustomMessageToList(FluentChatMessage message) {
    final values = messages.value;
    values[message.id] = message;
    messages.add(values);
    saveToDisk([selectedChatRoom]);
    scrollToEnd();
    notifyListeners();
  }

  void updateChatRoomTimestamp() {
    final lastUpdated = selectedChatRoom.dateModifiedMilliseconds;
    selectedChatRoom.dateModifiedMillisecondsNullable =
        DateTime.now().millisecondsSinceEpoch;
    // notify if the chat room was not updated in the last 30 seconds. Just a safety mechanism
    if (selectedChatRoom.dateModifiedMilliseconds - lastUpdated > 30_000) {
      notifyRoomsStream();
    }
  }

  Future _onToolsResponseEnd(
    String userContent,
    Map<String, dynamic> toolArgs,
    String? toolName,
  ) async {
    log('assistantArgs: $toolArgs');
    if (toolName == 'copy_to_clipboard_tool' &&
        AppCache.gptToolCopyToClipboardEnabled.value!) {
      final text = toolArgs['responseMessage'];
      final textToCopy = toolArgs['clipboard'];
      await Clipboard.setData(ClipboardData(text: textToCopy));
      displayCopiedToClipboard();
      final newId = DateTime.now().millisecondsSinceEpoch.toString();
      addBotMessageToList(
        FluentChatMessage.ai(
            id: newId, content: "```Clipboard\n$textToCopy\n```\n$text"),
      );
    } else if (toolName == 'auto_open_urls_tool' &&
        AppCache.gptToolAutoOpenUrls.value!) {
      final url = toolArgs['url'];
      final text = toolArgs['responseMessage'];
      final appendedText = text + '```func\n$url\n```';
      final time = DateTime.now().millisecondsSinceEpoch;
      addBotMessageToList(
        FluentChatMessage.ai(
          id: time.toString(),
          content: appendedText,
          timestamp: time,
          creator: selectedChatRoom.characterName,
          tokens: await countTokensString(appendedText),
        ),
      );
      // User need time to read XD
      await Future.delayed(const Duration(milliseconds: 1500));
      if (await canLaunchUrlString(url)) await launchUrlString(url);
    } else if (toolName == 'generate_image_tool' &&
        AppCache.gptToolGenerateImage.value!) {
      final String prompt = toolArgs['prompt'];
      final String? size = toolArgs['size'];
      final String? responseMessage = toolArgs['responseMessage'];
      final appendedText = '\n```func\n$prompt\n```';
      final time = DateTime.now().millisecondsSinceEpoch;
      final botPromptMessage = FluentChatMessage.ai(
        id: time.toString(),
        content: prompt,
        timestamp: time,
        creator: selectedChatRoom.characterName,
      );

      await _onResponseEndGenerateImage(
        botPromptMessage,
        OnMessageAction(
          actionName: 'generate_image_tool',
          isEnabled: true,
          regExp: RegExp(''),
          actionEnum: OnMessageActionEnum.generateImage,
        ),
        size: size,
      );
      if (responseMessage != null) {
        final newTime = DateTime.now().millisecondsSinceEpoch;
        final botResponse = FluentChatMessage.ai(
          id: newTime.toString(),
          // safety mechanism to prevent generating an image from the response message
          content: appendedText.replaceAll('```image', ''),
          timestamp: newTime,
          creator: selectedChatRoom.characterName,
        );
        addBotMessageToList(botResponse);
      }
    } else if (toolName == 'remember_info_tool' &&
        AppCache.gptToolRememberInfo.value == true) {
      final info = toolArgs['info'];
      final responseMessage = toolArgs['responseMessage'];
      final time = DateTime.now().millisecondsSinceEpoch;
      final funcText = '```remember\n$info\n```';
      AppCache.userInfo.saveInfoToFile(info);
      addBotMessageToList(
        FluentChatMessage.ai(
          id: time.toString(),
          content: '$funcText\n$responseMessage',
          timestamp: time,
          creator: selectedChatRoom.characterName,
          tokens: await countTokensString('$funcText\n$responseMessage'),
        ),
      );
    } else {
      logError('Unknown tool: $toolName');
      final time = DateTime.now().millisecondsSinceEpoch;
      final id = time.toString();
      addBotErrorMessageToList(
        FluentChatMessage.ai(
          id: id,
          content: 'Unknown tool: $toolName.\n```json\n$toolArgs\n```',
          timestamp: time,
          creator: 'error',
        ),
      );
    }
    // if (toolName == 'search_files') {
    //   final fileName = '${toolArgs['filename']}';
    //   toolArgs.remove('filename');

    //   final result =
    //       await ShellDriver.runShellSearchFileCommand(fileName, toolArgs);
    //   addBotMessageToList(AIChatMessage(content: result));
    // } else
    // if (toolName == 'get_current_weather') {
    //   final location = toolArgs['location'];
    //   // final unit = toolArgs['unit'];
    //   final result = await ShellDriver.runShellCommand(
    //       'curl wttr.in/$location?format="%C+%t+%w+%h+%p"');
    //   addBotMessageToList(AIChatMessage(content: result));
    // } else if (toolName == 'write_python_code') {
    //   final code = toolArgs['code'];
    //   final responseMessage = toolArgs['responseMessage'];
    //   addBotMessageToList(AIChatMessage(content: '$code\n$responseMessage'));
    // } else {
    //   addBotMessageToList(AIChatMessage(content: 'Unknown tool: $toolName'));
    // }
  }

  Future<void> clearChatMessages() async {
    final confirmed = await ConfirmationDialog.show(
        context: context!, message: 'Clear current chat?');
    if (!confirmed) return;
    messages.add({});
    questionHelpers.clear();
    saveToDisk([selectedChatRoom]);
    notifyRoomsStream();
    notifyListeners();
  }

  void notifyRoomsStream() {
    final sortedChatRooms = chatRoomsStream.value.values.toList()
      ..sort((a, b) {
        if (a.indexSort == b.indexSort) {
          return b.dateModifiedMilliseconds
              .compareTo(a.dateModifiedMilliseconds);
        }
        return a.indexSort.compareTo(b.indexSort);
      });

    sortChatRoomChildren(sortedChatRooms);

    chatRoomsStream.add(
      {
        for (var e in sortedChatRooms) (e).id: e,
      },
    );
  }

  void sortChatRoomChildren(List<ChatRoom> chatRooms) {
    for (var chatRoom in chatRooms) {
      if (chatRoom.isFolder && chatRoom.children != null) {
        chatRoom.children!.sort((a, b) {
          if (a.indexSort == b.indexSort) {
            return b.dateModifiedMilliseconds
                .compareTo(a.dateModifiedMilliseconds);
          }
          return a.indexSort.compareTo(b.indexSort);
        });
        sortChatRoomChildren(chatRoom.children!);
      }
    }
  }

  void selectNewModel(ChatModelAi model) {
    if (chatRooms[selectedChatRoomId] == null) {
      // create new chat Room
      final id = generateChatID();
      chatRooms[id] = selectedChatRoom.copyWith(model: model);
      selectedChatRoomId = id;
    }
    chatRooms[selectedChatRoomId]!.model = model;
    initModelsApi();
    notifyListeners();
    saveToDisk([selectedChatRoom]);
  }

  void selectModelForChat(String chatRoomName, ChatModelAi model) {
    chatRooms[chatRoomName]!.model = model;
    notifyRoomsStream();
    saveToDisk([selectedChatRoom]);
  }

  Future<void> createNewChatRoom() async {
    // if (messages.value.isEmpty) return;
    if (AppCache.learnAboutUserAfterCreateNewChat.value!) {
      generateUserKnowladgeBasedOnConversation();
    }
    final chatRoomName = '${chatRooms.length + 1} Chat';
    final id = generateChatID();
    String systemMessage = '';

    systemMessage =
        await getFormattedSystemPrompt(basicPrompt: defaultGlobalSystemMessage);

    chatRooms[id] = ChatRoom(
      id: id,
      chatRoomName: chatRoomName,
      model: selectedModel,
      temp: temp,
      topk: topk,
      promptBatchSize: promptBatchSize,
      topP: topP,
      maxTokenLength: maxTokenLenght,
      repeatPenalty: repeatPenalty,
      systemMessage: systemMessage,
      dateCreatedMilliseconds: DateTime.now().millisecondsSinceEpoch,
      totalReceivedTokens: 0,
      totalSentTokens: 0,
    );
    totalTokensByMessages = 0;
    totalSentTokens = 0;
    totalReceivedTokens = 0;
    notifyListeners();
    notifyRoomsStream();
    selectedChatRoomId = id;
    messages.add({});

    saveToDisk([selectedChatRoom]);
  }

  Future<void> deleteAllChatRooms() async {
    chatRooms.clear();
    final path = await FileUtils.getChatRoomsPath();
    final files = FileUtils.getFilesRecursive(path);
    final messagesFiles = await FileUtils.getAllChatMessagesFiles();
    for (var file in files) {
      await file.delete();
    }
    for (var file in messagesFiles) {
      await file.delete();
    }
    notifyListeners();
    notifyRoomsStream();
  }

  Future<void> selectChatRoom(ChatRoom room) async {
    stopAnswering(StopReason.switch_chat);
    selectedChatRoomId = room.id;
    initModelsApi();

    messages.add({});

    await _loadMessagesFromDisk(room.id);
    totalSentTokens = room.totalSentTokens ?? 0;
    totalReceivedTokens = room.totalReceivedTokens ?? 0;
    totalReceivedForCurrentChat.add(totalReceivedTokens);
    AppCache.selectedChatRoomId.value = room.id;
    countTokensFromMessagesCached([
      //add system message
      if (room.systemMessage != null)
        FluentChatMessage.system(
          id: '-1',
          content: room.systemMessage!,
        ),
      ...messages.value.values
    ]).then((value) {
      totalTokensByMessages = value;
    });
    scrollToEnd();
  }

  Future<void> deleteChatRoom(String chatRoomId) async {
    final allChatRooms =
        getChatRoomsRecursive(chatRoomsStream.value.values.toList());
    final chatRoomToDelete = chatRooms[chatRoomId] ??
        allChatRooms.firstWhereOrNull((element) => element.id == chatRoomId);
    if (chatRoomToDelete?.isFolder == true) {
      ungroupByFolder(chatRoomToDelete!);
      return;
    }
    if (chatRoomToDelete == null) {
      displayErrorInfoBar(
        title: 'Error while deleting chat room',
        message: 'Chat room not found',
      );
      return;
    }
    chatRooms.remove(chatRoomId);
    // if last one - create a default one
    if (chatRooms.isEmpty) {
      final newChatRoom = _generateDefaultChatroom(
        systemMessage: await getFormattedSystemPrompt(
            basicPrompt: defaultGlobalSystemMessage),
      );
      chatRooms[newChatRoom.id] = newChatRoom;
      selectedChatRoomId = newChatRoom.id;
    }
    final dir = await FileUtils.getChatRoomsPath();

    final archivedChatRoomsPath = await FileUtils.getArchivedChatRoomPath();
    try {
      if (chatRoomToDelete.model.modelName == 'error') {
        // in this case id is the path
        FileUtils.deleteFile(chatRoomId);
      } else {
        await FileUtils.moveFile('$dir${FileUtils.separatior}$chatRoomId.json',
            '$archivedChatRoomsPath${FileUtils.separatior}$chatRoomId.json');
      }
    } catch (e) {
      displayErrorInfoBar(
          title: 'Error while deleting chat room', message: '$e');
    }

    /// 2. Delete messages file
    FileUtils.getChatRoomMessagesFileById(chatRoomId).then((file) async {
      final archivedChatRoomsPath = await FileUtils.getArchivedChatRoomPath();
      try {
        if (chatRoomToDelete.model.modelName == 'error') {
          FileUtils.deleteFile(chatRoomId);
        } else {
          await FileUtils.moveFile(file.path,
              '$archivedChatRoomsPath${FileUtils.separatior}$chatRoomId-messages.json');
        }
      } catch (e) {
        displayErrorInfoBar(
            title: 'Error while deleting chat room messages', message: '$e');
      }
    });
    if (chatRoomId == selectedChatRoomId) {
      selectedChatRoomId = chatRooms.keys.first;
      await _loadMessagesFromDisk(selectedChatRoomId);
    }
  }

  void editChatRoom(String oldChatRoomId, ChatRoom chatRoom,
      {switchToForeground = false}) {
    final oldChatRoom = chatRooms[oldChatRoomId];
    final isCharNameChanged =
        oldChatRoom!.characterName != chatRoom.characterName;
    chatRoom.dateModifiedMillisecondsNullable =
        DateTime.now().millisecondsSinceEpoch;
    if (selectedChatRoomId == oldChatRoomId) {
      switchToForeground = true;
      if (isCharNameChanged) {
        // ignore: no_leading_underscores_for_local_identifiers
        final Map<String, FluentChatMessage> _messages = {};
        // we need to go through all messages and change the creator name
        for (var message in messages.value.values) {
          if (message.type == FluentChatMessageType.textAi) {
            _messages[message.id] =
                message.copyWith(creator: chatRoom.characterName);
          } else {
            _messages[message.id] = message;
          }
        }
        messages.add(_messages);
      }
    }
    chatRooms.remove(oldChatRoomId);
    chatRooms[chatRoom.id] = chatRoom;
    if (switchToForeground) {
      selectedChatRoomId = chatRoom.id;
    }

    notifyRoomsStream();
    notifyListeners();
    saveToDisk([chatRoom]);
  }

  // void sendResultOfRunningShellCode(String result) {
  //   messages[lastTimeAnswer] = ({
  //     'role': Role.assistant.name,
  //     'content':
  //         'Result: \n${result.trim().isEmpty ? 'Done. No output' : '```plaintext\n$result```'}',
  //   });
  //   notifyRoomsStream();
  //   saveToDisk([selectedChatRoom]);
  //   // scroll to bottom
  //   listItemsScrollController.animateTo(
  //     listItemsScrollController.position.maxScrollExtent + 200,
  //     duration: const Duration(milliseconds: 400),
  //     curve: Curves.easeOut,
  //   );
  // }

  List<LastDeletedMessage> lastDeletedMessage = [];

  void deleteMessage(String id, [bool showInfo = true]) {
    final _messages = messages.value;
    final removedVal = _messages.remove(id);
    if (removedVal != null) {
      lastDeletedMessage = [
        LastDeletedMessage(messageChatRoomId: id, message: removedVal),
        ...lastDeletedMessage,
      ];

      messages.add(_messages);
      saveToDisk([selectedChatRoom]);
      notifyListeners();
      if (showInfo) {
        displayTextInfoBar(
          "Message deleted".tr,
          action: (close) => Button(
            onPressed: () {
              revertDeletedMessage();
              close();
            },
            child: Text('Undo'),
          ),
        );
      }
    } else {
      if (showInfo) displayErrorInfoBar(title: 'Message not found');
    }
  }

  void revertDeletedMessage() {
    if (lastDeletedMessage.isNotEmpty) {
      final lastDeleted = lastDeletedMessage.first;
      final _messages = messages.value;
      _messages[lastDeleted.message.id] = lastDeleted.message;
      messages.add(_messages);
      saveToDisk([selectedChatRoom]);
      lastDeletedMessage = lastDeletedMessage.sublist(1);
      notifyListeners();
    }
  }

  /// sort messages based on their timestamp
  void sortMessages() {
    final messagesList = messages.value.values.toList();
    messagesList.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final newMessages = <String, FluentChatMessage>{};
    for (var message in messagesList) {
      newMessages[message.id] = message;
    }
    messages.add(newMessages);
  }

  Future<void> stopAnswering(StopReason stopReason) async {
    try {
      if (TextToSpeechService.isReadingAloud) {
        TextToSpeechService.stopReadingAloud();
      }
    } catch (e) {
      log('Error while stopping reading aloud: $e');
    }
    try {
      cancelToken?.cancel('canceled ');
      listenerResponseStream?.cancel();
      log('Canceled');
    } catch (e) {
      log('Error while canceling: $e');
    } finally {
      listenerResponseStream = null;
      isAnswering = false;
      if (stopReason == StopReason.canceled) {
        final lastMessage = messages.value.entries.last;
        final tokens = await countTokensString(lastMessage.value.content);
        totalTokensByMessages += tokens;
        totalReceivedTokens += tokens;
        totalReceivedForCurrentChat.add(totalReceivedTokens);
        editMessage(lastMessage.value.id, lastMessage.value);
      }
    }
  }

  Future<void> addMessageSystem(String message) async {
    final value = messages.value;
    final timeStamp = DateTime.now().millisecondsSinceEpoch;
    final tokens = await countTokensString(message);
    value['$timeStamp'] = FluentChatMessage.system(
      id: '$timeStamp',
      content: message,
      timestamp: timeStamp,
      tokens: tokens,
    );
    messages.add(value);
    saveToDisk([selectedChatRoom]);
    scrollToEnd();
  }

  void setIncludeWholeConversation(bool v) {
    includeConversationGlobal = v;
    notifyListeners();
  }

  void removeFileFromInput() {
    if (fileInput?.isInternalScreenshot == true) {
      // FileUtils.deleteFile(fileInput!.path);
    }
    fileInput = null;
    notifyListeners();
  }

  Future<void> scrollToEnd({bool withDelay = true}) async {
    try {
      if (withDelay) await Future.delayed(const Duration(milliseconds: 100));
      if (messages.value.isEmpty) return;

      // '_positions.isNotEmpty': ScrollController not attached to any scroll views.
      if (listItemsScrollController.hasClients) {
        // 0 because list is reversed
        listItemsScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error while scrolling to end: $e');
      }
    }
  }

  Future autoScrollToEnd({bool withDelay = true}) async {
    if (scrollToBottomOnAnswer) {
      return scrollToEnd(withDelay: withDelay);
    }
  }

  Future<void> regenerateMessage(FluentChatMessage currentElementToDelete,
      {required int indexInReversedList}) async {
    final isLastMessage = indexInReversedList == 0;
    final isBeforeLastMessage = indexInReversedList == 1;
    final isSelectedMessageFromMe = currentElementToDelete.isTextFromMe;

    final previousItemInRevList =
        messagesReversedList.elementAtOrNull(indexInReversedList + 1);

    final nextItemInRevList =
        messagesReversedList.elementAtOrNull(indexInReversedList + 1);

    if (isLastMessage || isBeforeLastMessage) {
      // delete the message because we will regenerate from the chat history before that message appeared
      deleteMessage(currentElementToDelete.id, false);
      // if we just deleted ai text message it means we need to delete the previous (related) question from human
      if (currentElementToDelete.type == FluentChatMessageType.textAi) {
        //Just to confirm that the next message is AI message
        if (previousItemInRevList != null &&
            previousItemInRevList.type == FluentChatMessageType.textHuman) {
          deleteMessage(previousItemInRevList.id, false);
        }
      }
      if (currentElementToDelete.type == FluentChatMessageType.textHuman &&
          !isLastMessage) {
        //Just to confirm that the next message is AI message
        if (nextItemInRevList != null &&
            nextItemInRevList.type == FluentChatMessageType.textAi) {
          deleteMessage(nextItemInRevList.id, false);
        }
      }
    } else {
      displayErrorInfoBar(
        title: 'Not supported',
        message: 'You can only regenerate the last message or previous one',
      );
      return;
    }
    final messageForType = isSelectedMessageFromMe
        ? currentElementToDelete
        : previousItemInRevList;

    await sendMessage(
      isSelectedMessageFromMe
          ? currentElementToDelete.content
          : previousItemInRevList!.content,
      hidePrompt: true,
      sendAsUser: messageForType?.type == FluentChatMessageType.textHuman,
      seed: Random().nextInt(10000),
    );
  }

  void updateUI() {
    notifyListeners();
  }

  Future<void> archiveChatRoom(ChatRoom room) async {
    return deleteChatRoom(room.id);
  }

  void shortenMessage(String id) {
    final message = messages.value[id];
    sendSingleMessage(
      'Please shorten the following text while keeping all the essential information and key points intact. Remove any unnecessary details or repetition:'
      '\n"${message?.content}"',
    );
  }

  void lengthenMessage(String id) {
    final message = messages.value[id];
    sendSingleMessage(
      'Please expand the following text by providing more details and explanations. Make the text more specific and elaborate on the key points, while keeping it clear and understandable'
      '\n"${message?.content}"',
    );
  }

  Future _loadMessagesFromDisk(String id) async {
    final roomId = id;
    final fileContent = await FileUtils.getChatRoomMessagesFileById(roomId);
    final fileContentString = await fileContent.readAsString();

    final chatRoomRaw = jsonDecode(fileContentString) as List<dynamic>;
    // id is the key
    final roomMessages = <String, FluentChatMessage>{};
    for (var messageJson in chatRoomRaw) {
      try {
        final id = messageJson['id'] as String;
        final timestamp = messageJson['timestamp'] as int?;
        // if is not containing 'timestamp' break the loop and ask to upgrade
        if (timestamp == null) {
          onTrayButtonTapCommand(
              'You use deprecated chat format. Please go to the settings page->Application storage location->Import old chats in deprecated format',
              TrayCommand.show_dialog.name);
          break;
        }
        roomMessages[id] = FluentChatMessage.fromJson(messageJson);
      } catch (e) {
        logError('Error while loading message from disk: $e');
      }
    }

    messages.add(roomMessages);
    notifyListeners();
  }

  void toggleWebSearch() {
    isWebSearchEnabled = !isWebSearchEnabled;
    notifyListeners();
  }

  Future _answerBasedOnWebResults(
    List<WebSearchResult> results,
    String userMessage,
  ) async {
    String urlContent = '';
    for (var result in results) {
      final url = result.url;
      final title = result.title;
      final text = AppCache.scrapOnlyDecription.value!
          ? WebScraper.clearTextFromTags(result.description)
          : await WebScraper().extractFormattedContent(url);
      final characters = text.characters;
      final tokenCount = characters.length / 4;
      // print('[scrapper] Token count: $tokenCount');
      // print('[scrapper] Char count: ${characters.length}');
      // print('[scrapper] URL: $url');
      // print('[scrapper] Title: $title');
      // print('[scrapper] Text: $text');
      if (tokenCount > 6500) {
        urlContent += '[SYSTEM:Char count exceeded 3500. Stop the search]';
        break;
      }
      // if char count is more than 2000, append and skip the rest
      if (tokenCount > 2000) {
        // append the first 2000 chars
        urlContent += characters.take(2000).join('');
        urlContent +=
            '[SYSTEM:Char count exceeded 500. Skip the rest of the page]';
        continue;
      }

      urlContent += 'Page Title:$title\nBody:```$text```\n\n';
    }
    userMessage = modifyMessageStyle(userMessage);

    return sendSingleMessage(
      'You are an agent of LLM model that scraps the internet. Answer to the message based only on this search results from these web pages: $urlContent.\n'
      'In the end add a caption where did you find this info.'
      '''E.g. "I found this information on: 
      - [page1](link1) 
      - [page2](link2)
      "'''
      '.Answer in markdown with links. ALWAYS USE SOURCE NAMES AND LINKS!'
      'User message: $userMessage',
    );
  }

  String? blinkMessageId;
  Future<void> scrollToMessage(String messageKey) async {
    final index = indexOf(messagesReversedList, messages.value[messageKey]);
    blinkMessageId = messageKey;
    await listItemsScrollController.scrollToIndex(index);
    notifyListeners();
  }

  /// custom get index
  int indexOf(List<FluentChatMessage> list, FluentChatMessage? element,
      [int start = 0]) {
    if (start < 0) start = 0;
    for (int i = start; i < list.length; i++) {
      final first = list[i];
      if (first.content == element?.content) {
        return i;
      }
    }
    return -1;
  }

  Stream<List<int>>? micStream;
  DeepgramLiveTranscriber? transcriber;
  AudioRecorder? recorder;
  Future<bool> startListeningForInput() async {
    try {
      if (!DeepgramSpeech.isValid()) {
        displayInfoBar(context!, builder: (ctx, close) {
          return InfoBar(
            title: Text('Deepgram API key is not set'.tr),
            severity: InfoBarSeverity.warning,
            action: Button(
              onPressed: () async {
                close();
                // ensure its closed
                await Future.delayed(const Duration(milliseconds: 200));
                Navigator.of(context!).push(
                  FluentPageRoute(builder: (ctx) => const NewSettingsPage()),
                );
              },
              child: Text('Settings'.tr),
            ),
          );
        });
        return false;
      }
      recorder = AudioRecorder();
      micStream = await recorder!.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          device: AppCache.micrpohoneDeviceId.value != null
              ? InputDevice(
                  id: AppCache.micrpohoneDeviceId.value!,
                  label: AppCache.micrpohoneDeviceName.value ?? 'Unknown name')
              : null,
        ),
      );

      final streamParams = {
        'detect_language': false, // not supported by streaming API
        'language': AppCache.speechLanguage.value!,
        // must specify encoding and sample_rate according to the audio stream
        'encoding': 'linear16',
        'sample_rate': 16000,
      };
      transcriber = DeepgramSpeech.deepgram
          .createLiveTranscriber(micStream!, queryParams: streamParams);
      transcriber!.stream.listen((res) {
        if (res.transcript?.isNotEmpty == true) {
          messageController.text += '${res.transcript!} ';
        }
      });
      transcriber!.start();
    } catch (e, stack) {
      logError('Speech error:\n$e', stack);
      return false;
    }
    return true;
  }

  Future<void> stopListeningForInput() async {
    try {
      transcriber!.pause(keepAlive: false);
      await transcriber!.close();
      transcriber = null;
    } catch (e, stack) {
      logError('Error while stopping listening: $e', stack);
    }
    try {
      await recorder!.cancel();
      await Future.delayed(const Duration(milliseconds: 500));
      await recorder!.dispose();
    } catch (e, stack) {
      logError('Error while stopping audio stream: $e', stack);
    }
    micStream = null;
  }

  Future editMessage(String id, FluentChatMessage message) async {
    if (message.type == FluentChatMessageType.textHuman ||
        message.type == FluentChatMessageType.textAi) {
      final lastTokenLenght = messages.value[id]?.tokens ?? 0;
      final newLenghtTokens = await countTokensString(message.content);

      final messagesList = messages.value;
      messagesList[id] = message.copyWith(tokens: newLenghtTokens);
      messages.add(messagesList);
      // recalculate total tokens without iterating the list
      if (lastTokenLenght != newLenghtTokens) {
        totalTokensByMessages += newLenghtTokens - lastTokenLenght;
      }
    } else {
      final messagesList = messages.value;
      messagesList[id] = message;
      messages.add(messagesList);
    }

    saveToDisk([selectedChatRoom]);
    notifyListeners();
  }

  Future<void> createNewBranchFromLastMessage(String id) async {
    final listNewMessages = <String, FluentChatMessage>{};
    for (var message in messages.value.entries) {
      // All messages are sorted. So if we face the message with the same id, we add it and stop
      if (message.key == id) {
        listNewMessages[message.key] = message.value;
        break;
      }
      listNewMessages[message.key] = message.value;
    }
    // create new chat room with new messages
    final chatRoomName = '${selectedChatRoom.chatRoomName}*';
    final newChatId = generateChatID();
    final newChatRoom = selectedChatRoom.copyWith(
      id: newChatId,
      chatRoomName: chatRoomName,
      dateCreatedMilliseconds: DateTime.now().millisecondsSinceEpoch,
    );
    final chatRooms = chatRoomsStream.value;
    chatRooms[newChatId] = newChatRoom;
    chatRoomsStream.add(chatRooms);
    selectedChatRoomId = newChatId;
    messages.add(listNewMessages);
    notifyRoomsStream();
    saveToDisk([newChatRoom]);
    // wait until the new chat room is created and opened
    await Future.delayed(const Duration(milliseconds: 300));
    await scrollToEnd(withDelay: false);
  }

  Future continueMessage(String id) async {
    final FluentChatMessage? lastMessageToMerge = messages.value[id];
    final lastMessages = await getLastMessagesLimitToTokens(512);
    sendMessage(
      '$continuePrompt $lastMessages',
      hidePrompt: true,
      onMessageSent: () {
        final continueRequestMessage = messages.value.entries.last;
        final listMessages = messages.value;
        listMessages.remove(continueRequestMessage.key);
        messages.add(listMessages);
      },
      onFinishResponse: () {
        final aiAnswer = messages.value.entries.last;

        final concatMessage =
            lastMessageToMerge!.concat(aiAnswer.value.content);
        final listMessages = messages.value;
        listMessages.remove(aiAnswer.key);
        listMessages[id] = concatMessage;
        messages.add(listMessages);
        saveToDisk([selectedChatRoom]);
      },
    );
  }

  void pinChatRoom(ChatRoom chatRoom) {
    chatRoom.indexSort = chatRoom.indexSort - 1;
    notifyRoomsStream();
    saveChatWithoutMessages(chatRoom);
  }

  void unpinChatRoom(ChatRoom chatRoom) {
    chatRoom.indexSort = 999999;

    notifyRoomsStream();
    saveChatWithoutMessages(chatRoom);
  }

  Future<void> saveChatWithoutMessages(ChatRoom chatRoom) async {
    final chatRoomRaw = chatRoom.toJson();
    final path = await FileUtils.getChatRoomsPath();
    await FileUtils.saveFile(
        '$path/${chatRoom.id}.json', jsonEncode(chatRoomRaw));
  }

  Future<void> _onResponseEndGenerateImage(
    FluentChatMessage response,
    OnMessageAction action, {
    String? size,
  }) async {
    try {
      final promptMessage = messages.value.entries.last.value.copyWith();
      // deleteMessage(messagesReversedList.first.id);
      final prompt = response.content.replaceAll(action.regExp, '');

      String? apiKey = AppCache.imageGeneratorApiKey.value;
      if (AppCache.imageGeneratorApiKey.value == null) {
        final openAiModel = allModels.value.firstWhereOrNull(
          (element) => element.ownedBy == 'openai' && element.apiKey.isNotEmpty,
        );
        if (openAiModel != null) {
          apiKey = openAiModel.apiKey;
        }
      }
      if (apiKey == null) {
        return displayErrorInfoBar(
          title: 'Error while generating image'.tr,
          message:
              'No API key found for image generation. Please add an API key in the settings page',
          action: Button(
            child: Text('Settings'.tr),
            onPressed: () {
              Navigator.of(context!).push(FluentPageRoute(
                  builder: (ctx) => NewSettingsPage(
                      initialIndex: NewSettingsPage.apiUrlsIndex)));
            },
          ),
        );
      }

      isGeneratingImage = true;
      notifyListeners();
      final imageChatMessage = await ImageGeneratorFeature.generateImage(
        prompt: prompt,
        apiKey: apiKey,
        size: size ?? AppCache.imageGeneratorSize.value!,
        quality: AppCache.imageGeneratorQuality.value!,
        style: AppCache.imageGeneratorStyle.value!,
        n: 1,
      );
      final newTimestamp = DateTime.now().millisecondsSinceEpoch;
      addCustomMessageToList(
        FluentChatMessage.imageAi(
          id: '$newTimestamp',
          content: imageChatMessage.content,
          creator: imageChatMessage.generatedBy,
          timestamp: newTimestamp,
          imagePrompt: imageChatMessage.revisedPrompt,
        ),
      );
      final questionAboutImage = await retrieveResponseFromPrompt(
        'You just generated an image. Ask user how they feel about your drawing in "{lang}" language using short 1 sentence'
            .replaceAll('{lang}', I18n.currentLocale.languageCode),
        systemMessage: selectedChatRoom.systemMessage,
        additionalPreMessages: [
          messagesReversedList[0],
          promptMessage,
        ],
      );
      final newTimestamp2 = DateTime.now().millisecondsSinceEpoch;
      final countTokens = await countTokensString(questionAboutImage);
      addBotMessageToList(
        FluentChatMessage.ai(
          id: newTimestamp2.toString(),
          content: questionAboutImage,
          timestamp: newTimestamp2,
          creator: selectedChatRoom.characterName,
          tokens: countTokens,
        ),
      );
      saveToDisk([selectedChatRoom]);
    } catch (e) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      addBotErrorMessageToList(
        FluentChatMessage.ai(
          id: timestamp.toString(),
          content: 'Error while generating image: $e',
          creator: 'error',
          timestamp: timestamp,
        ),
      );
    } finally {
      isGeneratingImage = false;
      notifyListeners();
    }
  }

  bool isTypingSimulate = false;

  Future simulateAiTyping() async {
    isTypingSimulate = true;
    notifyListeners();
    await Future.delayed(const Duration(seconds: 2));
    isTypingSimulate = false;
    notifyListeners();
  }

  /// Finds the last message that is visible for the ai to see
  /// Scrolls up to the last message that is visible for the ai to see
  Future<void> scrollToLastOverflowMessage() async {
    final maxTokens = maxTokenLenght;
    final messagesList = messagesReversedList.toList();
    messagesList.add(FluentChatMessage.system(
        id: '000', content: selectedChatRoom.systemMessage ?? ''));
    int tokens = 0;
    for (var message in messagesList) {
      tokens += message.tokens == 0
          ? await countTokensString(message.content)
          : message.tokens;
      if (tokens > maxTokens) {
        scrollToMessage(message.id);
        break;
      }
    }
  }

  void createChatRoomFolder({
    List<ChatRoom> chatRoomsForFolder = const [],
    String? parentFolderId,
  }) {
    final chatRoomName = '${chatRooms.length + 1} Folder';
    final id = generateChatID();
    final chRooms = chatRoomsStream.value;
    if (chatRoomsForFolder.isEmpty) {
      // just create empty folder
      chRooms[id] = ChatRoom.folder(
        model: selectedModel,
        id: id,
        chatRoomName: chatRoomName,
        dateCreatedMilliseconds: DateTime.now().millisecondsSinceEpoch,
      );
      chatRoomsStream.add(chRooms);
      return;
    }
    if (parentFolderId != null) {
      final allChatRooms =
          getChatRoomsFoldersRecursive(chRooms.values.toList());
      final parentFolder = allChatRooms.firstWhereOrNull(
        (element) => element.id == parentFolderId,
      );
      if (parentFolder != null) {
        parentFolder.children ??= [];
        parentFolder.children!.add(
          ChatRoom.folder(
            model: selectedModel,
            id: id,
            chatRoomName: chatRoomName,
            children: chatRoomsForFolder,
          ),
        );

        for (var chatRoom in chatRoomsForFolder) {
          chRooms.remove(chatRoom.id);
          parentFolder.children!
              .removeWhere((element) => element.id == chatRoom.id);
        }
        chRooms[parentFolder.id] = parentFolder;
        chatRoomsStream.add(chRooms);
        notifyRoomsStream();
        // delete files because we already have them in the other folder
        for (var chatRoom in chatRoomsForFolder) {
          FileUtils.getChatRoomFilePath(chatRoom.id).then((path) {
            FileUtils.deleteFile(path);
          });
        }
        saveToDisk(chatRoomsStream.value.values.toList());
        return;
      }
    }
    chRooms[id] = ChatRoom.folder(
      model: selectedModel,
      id: id,
      chatRoomName: chatRoomName,
      children: chatRoomsForFolder,
    );
    for (var chatRoom in chatRoomsForFolder) {
      chRooms.remove(chatRoom.id);
    }
    chatRoomsStream.add(chRooms);
    notifyRoomsStream();
    // delete files because we already have them in the other folder
    for (var chatRoom in chatRoomsForFolder) {
      FileUtils.getChatRoomFilePath(chatRoom.id).then((path) {
        FileUtils.deleteFile(path);
      });
    }
    saveToDisk(chatRoomsStream.value.values.toList());
  }

  void moveChatRoomToFolder(ChatRoom chatRoom, ChatRoom folder,
      {required String? parentFolder}) {
    // remove chat room from the list
    // add chat room to the folder
    final chatRooms = chatRoomsStream.value;
    if (parentFolder == null) {
      chatRooms.removeWhere(
        (key, value) {
          // can be folder or chat room
          if (value.id == chatRoom.id) {
            return true;
          }
          if (value.isFolder) {
            return value.children!.any((element) => element.id == chatRoom.id);
          }
          return false;
        },
      );
    } else {
      // parent folder is not null and we need to find it and remove child from there
      final allChatRooms =
          getChatRoomsFoldersRecursive(chatRooms.values.toList());
      final parent = allChatRooms
          .firstWhereOrNull((element) => element.id == parentFolder);
      if (parent != null) {
        parent.children!.removeWhere((element) => element.id == chatRoom.id);
        // ungroup if no children
        if (parent.children?.isEmpty == true) {
          parent.children = null;
        }
      }
    }

    folder.children ??= [];
    folder.children!.add(chatRoom);
    chatRooms[folder.id] = folder;
    chatRoomsStream.add(chatRooms);
    // delete files because we already have them in the other folder
    FileUtils.getChatRoomFilePath(chatRoom.id).then((path) {
      FileUtils.deleteFile(path);
    });
    saveToDisk(chatRoomsStream.value.values.toList());
  }

  void moveChatRoomToParentFolder(ChatRoom chatRoom) {
    final chatRooms =
        getChatRoomsFoldersRecursive(chatRoomsStream.value.values.toList());
    final chRooms = chatRoomsStream.value;
    final parent = chatRooms.firstWhereOrNull(
        (element) => element.children!.any((e) => e.id == chatRoom.id));
    if (parent != null) {
      parent.children!.removeWhere((element) => element.id == chatRoom.id);
      chRooms[parent.id] = parent;
      chRooms[chatRoom.id] = chatRoom;
      chatRoomsStream.add(chRooms);
      // delete files because we already have them in the other folder
      FileUtils.getChatRoomFilePath(chatRoom.id).then((path) {
        FileUtils.deleteFile(path);
      });
      notifyRoomsStream();
      saveToDisk(chatRoomsStream.value.values.toList());
    }
  }

  void ungroupByFolder(ChatRoom chatFolder) {
    // get all children from folder
    // remove folder
    // paste children to the main list
    final chatRooms = chatRoomsStream.value;
    final folder = chatFolder;
    final children = folder.children!;
    chatRooms.removeWhere((key, value) => value.id == folder.id);
    // delete file
    FileUtils.getChatRoomFilePath(folder.id)
        .then((path) => FileUtils.deleteFile(path));
    for (var child in children) {
      chatRooms[child.id] = child;
    }
    chatRoomsStream.add(chatRooms);
    notifyRoomsStream();
    saveToDisk(chatRoomsStream.value.values.toList());
  }

  Future<void> recalculateTokensFromLocalMessages(
      [bool showPromptToOverride = true]) async {
    var _sentTokens = 0;
    var _receivedTokens = 0;
    for (var message in messages.value.values) {
      if (message.type == FluentChatMessageType.textAi) {
        _receivedTokens += message.tokens;
      } else {
        _sentTokens += message.tokens;
      }
    }
    totalTokensByMessages = await countTokensFromMessagesCached([
      //add system message
      if (selectedChatRoom.systemMessage != null)
        FluentChatMessage.system(
          id: '-1',
          content: selectedChatRoom.systemMessage!,
        ),
      ...messages.value.values
    ]);
    notifyListeners();
    if (showPromptToOverride == false) return;
    final shouldOverrideChatTokens = await ConfirmationDialog.show(
      context: context!,
      message:
          'Do you want to save and override chat tokens with the new value?',
    );
    if (shouldOverrideChatTokens) {
      selectedChatRoom.totalSentTokens = _sentTokens;
      selectedChatRoom.totalReceivedTokens = _receivedTokens;
      totalReceivedForCurrentChat.add(_receivedTokens);
      totalSentTokens = _sentTokens;
      saveToDisk([selectedChatRoom]);
    }
  }

  Future<void> deleteMessagesAbove(String id) async {
    final confirmed = await ConfirmationDialog.show(
        context: context!,
        message: 'Everything above will be deleted in current chat');
    if (!confirmed) return;
    final messagesList = messages.value;
    final keys = messagesList.keys.toList();
    final index = keys.indexOf(id);
    for (var i = 0; i < index; i++) {
      messagesList.remove(keys[i]);
    }
    messages.add(messagesList);
    recalculateTokensFromLocalMessages(false);
    saveToDisk([selectedChatRoom]);
  }

  Future<void> deleteMessagesBelow(String id) async {
    final confirmed = await ConfirmationDialog.show(
        context: context!,
        message: 'Everything below will be deleted in current chat');
    if (!confirmed) return;
    final messagesList = messages.value;
    final keys = messagesList.keys.toList();
    final index = keys.indexOf(id);
    for (var i = index + 1; i < keys.length; i++) {
      messagesList.remove(keys[i]);
    }
    messages.add(messagesList);
    recalculateTokensFromLocalMessages(false);
    saveToDisk([selectedChatRoom]);
  }

  Future<void> duplicateChatRoom(ChatRoom chatRoom) async {
    final newChatRoom = chatRoom.copyWith(
      id: generateChatID(),
      chatRoomName: '${chatRoom.chatRoomName} copy',
      dateCreatedMilliseconds: DateTime.now().millisecondsSinceEpoch,
      dateModifiedMilliseconds: DateTime.now().millisecondsSinceEpoch,
    );
    chatRooms[newChatRoom.id] = newChatRoom;
    // if it's current chat room, save messages
    final messagesRaw = <Map<String, dynamic>>[];
    final fileMessagesOfSelectedChat =
        await FileUtils.getChatRoomMessagesFileById(
      chatRoom.id,
    );
    final stringMessages = await fileMessagesOfSelectedChat.readAsString();
    final mappedMessages = jsonDecode(stringMessages) as List<dynamic>;
    for (var message in mappedMessages) {
      messagesRaw.add(message as Map<String, dynamic>);
    }

    await FileUtils.saveChatMessages(
      newChatRoom.id,
      jsonEncode(messagesRaw),
    );

    notifyListeners();
    notifyRoomsStream();
    saveToDisk([newChatRoom]);
  }

  void onMessageButtonTap(String button) {
    if (button == MesssageListTileButtons.disable_tools_btn.name) {
      final allValues = [
        AppCache.gptToolCopyToClipboardEnabled,
        AppCache.gptToolAutoOpenUrls,
        AppCache.gptToolGenerateImage,
        AppCache.gptToolRememberInfo,
      ];
      for (var value in allValues) {
        value.value = false;
      }
      displayTextInfoBar('Tools disabled'.tr);
      notifyListeners();
    }
  }
}

enum MesssageListTileButtons {
  disable_tools_btn,
}

List<ChatRoom> getChatRoomsFoldersRecursive(List<ChatRoom> chatRooms) {
  final folders = <ChatRoom>[];
  for (var chatRoom in chatRooms) {
    if (chatRoom.isFolder) {
      folders.add(chatRoom);
      if (chatRoom.children != null) {
        folders.addAll(getChatRoomsFoldersRecursive(chatRoom.children!));
      }
    }
  }
  return folders;
}

List<ChatRoom> getChatRoomsRecursive(List<ChatRoom> chatRooms) {
  final folders = <ChatRoom>[];
  for (var chatRoom in chatRooms) {
    folders.add(chatRoom);
    if (chatRoom.children != null) {
      folders.addAll(getChatRoomsRecursive(chatRoom.children!));
    }
  }
  return folders;
}

ChatRoom _generateDefaultChatroom({String? systemMessage}) {
  return ChatRoom(
    id: generateChatID(),
    chatRoomName: 'Default',
    model: selectedModel,
    temp: temp,
    topk: topk,
    promptBatchSize: promptBatchSize,
    topP: topP,
    systemMessageTokensCount: 0,
    totalReceivedTokens: 0,
    totalSentTokens: 0,
    maxTokenLength: maxTokenLenght,
    repeatPenalty: repeatPenalty,
    systemMessage: '',
    dateCreatedMilliseconds: DateTime.now().millisecondsSinceEpoch,
  );
}
