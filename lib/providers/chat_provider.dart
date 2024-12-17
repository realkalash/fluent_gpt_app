import 'dart:async';
import 'dart:convert';
import 'package:deepgram_speech_to_text/deepgram_speech_to_text.dart';
import 'package:docx_to_text/docx_to_text.dart';
import 'package:fluent_gpt/common/attachment.dart';
import 'package:fluent_gpt/common/chat_model.dart';
import 'package:fluent_gpt/common/conversaton_style_enum.dart';
import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/common/excel_to_json.dart';
import 'package:fluent_gpt/common/on_message_actions/on_message_action.dart';
import 'package:fluent_gpt/common/scrapper/web_scrapper.dart';
import 'package:fluent_gpt/common/window_listener.dart';
import 'package:fluent_gpt/dialogs/ai_lens_dialog.dart';
import 'package:fluent_gpt/dialogs/error_message_dialogs.dart';
import 'package:fluent_gpt/dialogs/info_about_user_dialog.dart';
import 'package:fluent_gpt/features/annoy_feature.dart';
import 'package:fluent_gpt/features/dalle_api_generator.dart';
import 'package:fluent_gpt/features/deepgram_speech.dart';
import 'package:fluent_gpt/features/text_to_speech.dart';
import 'package:fluent_gpt/fluent_icons_list.dart';
import 'package:fluent_gpt/gpt_tools.dart';
import 'package:fluent_gpt/log.dart';

import 'package:fluent_gpt/common/chat_room.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/pages/settings_page.dart';
import 'package:fluent_gpt/shell_driver.dart';
import 'package:fluent_gpt/system_messages.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/command_request_answer_overlay.dart';
import 'package:fluent_gpt/widgets/input_field.dart';
import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gpt_tokenizer/flutter_gpt_tokenizer.dart';
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
        DateTime.fromMillisecondsSinceEpoch(chatRoom.dateCreatedMilliseconds);
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
int get repeatPenaltyTokens =>
    chatRooms[selectedChatRoomId]?.repeatPenaltyTokens ?? 64;
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

  void toggleScrollToBottomOnAnswer() {
    scrollToBottomOnAnswer = !scrollToBottomOnAnswer;
    notifyListeners();
  }

  Future<void> saveToDisk(List<ChatRoom> rooms) async {
    // ignore: no_leading_underscores_for_local_identifiers
    final _chatRooms = rooms;
    for (var chatRoom in _chatRooms) {
      var chatRoomRaw = chatRoom.toJson();
      final path = await FileUtils.getChatRoomsPath();
      FileUtils.saveFile('$path/${chatRoom.id}.json', jsonEncode(chatRoomRaw));
      // if it's current chat room, save messages
      if (chatRoom.id == selectedChatRoomId) {
        final messagesRaw = <Map<String, dynamic>>[];
        for (var message in messages.value.entries) {
          /// add key and message.toJson
          messagesRaw.add(message.value.toJson());
        }
        FileUtils.saveChatMessages(chatRoom.id, jsonEncode(messagesRaw));
      }
    }
  }

  Future<void> initChatsFromDisk() async {
    final path = await FileUtils.getChatRoomsPath();
    final files = FileUtils.getFilesRecursive(path);
    // ChatRoom? _selectedChatRoomFromCache;
    for (var file in files) {
      try {
        if (file.path.contains('.DS_Store')) continue;
        final fileContent = await file.readAsString();
        final chatRoomRaw = jsonDecode(fileContent) as Map<String, dynamic>;
        final chatRoom = ChatRoom.fromMap(chatRoomRaw);
        chatRooms[chatRoom.id] = chatRoom;
        if (chatRoom.children != null) {
          // TODO: this can fix init selection only for first 2 levels deep
          // for (var subItem in chatRoom.children!) {
          //   if (subItem.children != null) {
          //     for (var subSubItem in subItem.children!) {
          //       if (subSubItem.id == selectedChatRoomId) {
          //         // _selectedChatRoomFromCache = chatRoom;
          //       }
          //     }
          //   } else if (subItem.id == selectedChatRoomId) {
          //     // _selectedChatRoomFromCache = chatRoom;
          //   }
          // }
        } else {
          // TODO: isnt this will load messages in a loop for the same chat for each chat?
          initModelsApi();
          await _loadMessagesFromDisk(selectedChatRoomId);
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
          repeatPenaltyTokens: repeatPenaltyTokens,
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
    // if (_selectedChatRoomFromCache != null) {}

    /// notify listeners
    selectedChatRoomId = selectedChatRoomId;

    notifyRoomsStream();
  }

  ChatProvider() {
    _messageTextSize = AppCache.messageTextSize.value ?? 14;
    selectedChatRoomId = AppCache.selectedChatRoomId.value ?? 'Default';
    init();
    listenTray();
  }

  Future<void> init() async {
    initMessagesListener();
    await initChatModels();
    await initChatsFromDisk();
    initCustomActions();
    initSettingsFromCache();
    initTimers();
    initListeners();
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
      if (value?.contains('fluentgpt:///') == true ||
          value?.contains('fluentgpt://') == true) {
        final uri = Uri.parse(value!);
        command = uri.queryParameters['command'] ?? '';
        text = uri.queryParameters['text'] ?? '';
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
        sendMessage(text, hidePrompt: true);
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
                      child: const Text('Close'),
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
        addAttachemntAiLens(base64String);
      } else if (command == TrayCommand.generate_dalle_image.name) {
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
        final openAiModel = allModels.value
            .firstWhereOrNull((element) => element.ownedBy == 'openai');
        if (openAiModel == null) {
          throw Exception(
              'OpenAI model not found. Please add at least one OpenAI model to use this feature');
        }
        final imageChatMessage = await DalleApiGenerator.generateImage(
          prompt: imagePrompt,
          model: 'dall-e-3',
          apiKey: openAiModel.apiKey,
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

  Future<void> addAttachemntAiLens(String base64String) async {
    final attachment = Attachment.fromInternalScreenshot(base64String);
    addAttachmentToInput(attachment);
    final isSent = await showDialog(
      context: context!,
      barrierDismissible: true,
      builder: (ctx) => AiLensDialog(base64String: base64String),
    );
    if (isSent != true) {
      removeFileFromInput();
    }
  }

  void addWebResultsToMessages(List<SearchResult> webpage) {
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
    final chatRoom = chatRooms[selectedChatRoomId]!;
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
    notifyRoomsStream();
    saveToDisk([selectedChatRoom]);
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
            title: Text('Memory updated'),
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
              child: Text('Open memory'),
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

  Future<String> convertMessagesToString(List<FluentChatMessage> messages,
      {bool includeSystemMessages = false}) async {
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

  Stream<ChatResult>? responseStream;
  StreamSubscription<ChatResult>? listenerResponseStream;

  Future<void> sendMessage(
    String messageContent, {
    bool hidePrompt = false,
    bool sendStream = true,
    void Function()? onFinishResponse,
    void Function()? onMessageSent,
  }) async {
    bool isFirstMessage = messages.value.isEmpty;
    bool isThirdMessage = messages.value.length == 2;
    final isToolsEnabled = AppCache.gptToolCopyToClipboardEnabled.value == true;
    if (isFirstMessage) {
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
    if (messageContent.contains(TrayCommand.generate_dalle_image.name)) {
      onTrayButtonTapCommand(
        messageContent,
        TrayCommand.generate_dalle_image.name,
      );
      return;
    }
    if (isThirdMessage) {
      String lastMessages = await getLastFewMessagesForContextAsString();
      lastMessages += ' Human: $messageContent';
      retrieveResponseFromPrompt(
        '$nameTopicPrompt "$lastMessages"',
      ).then(renameCurrentChatRoom);
    }
    if (isWebSearchEnabled) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      addHumanMessageToList(
        FluentChatMessage.humanText(
          id: '$timestamp',
          content: messageContent,
          creator: AppCache.userName.value!,
          timestamp: timestamp,
          tokens: await countTokensString(messageContent),
        ),
      );
      final lastMessages = getLastFewMessagesForContextAsString();
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
          final shortResults = results.take(15).map((e) => e).toList();
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
      return;
    }

    // to prevent empty messages posted to the chat
    if (messageContent.isNotEmpty) {
      /// add additional styles to the message
      messageContent = modifyMessageStyle(messageContent);
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      addHumanMessageToList(
        FluentChatMessage.humanText(
          id: '$timestamp',
          content: messageContent,
          creator: AppCache.userName.value!,
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
      /// beacuse timestamp is very sensetive
      await Future.delayed(const Duration(milliseconds: 10));
      final bytes = await fileInput!.readAsBytes();
      final base64 = base64Encode(bytes);
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
      final lastMessages = await getLastMessagesLimitToTokens(
        selectedChatRoom.maxTokenLength,
        allowImages: true,
      );
      final lastMessagesLangChain =
          lastMessages.map((e) => e.toLangChainChatMessage());
      messagesToSend.addAll(lastMessagesLangChain);

      if (selectedChatRoom.systemMessage?.isNotEmpty == true) {
        messagesToSend.insert(
            0, SystemChatMessage(content: selectedChatRoom.systemMessage!));
      }
      if (messages.value.length > 1)
        messagesToSend.insert(
            0, ChatMessage.system('Previous chat hidden due to overflow'));
    }
    if (!includeConversationGlobal) {
      if (selectedChatRoom.systemMessage?.isNotEmpty == true) {
        final systemMessage = await getFormattedSystemPrompt(
          basicPrompt: selectedChatRoom.systemMessage!,
        );
        messagesToSend.add(SystemChatMessage(content: systemMessage));
      }

      if (messageContent.isNotEmpty)
        messagesToSend.add(
          HumanChatMessage(content: ChatMessageContent.text(messageContent)),
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
    try {
      initModelsApi();
      if (!sendStream) {
        late AIChatMessage response;
        if (selectedChatRoom.model.ownedBy == OwnedByEnum.openai.name) {
          response = await openAI!.call(
            messagesToSend,
            options: ChatOpenAIOptions(
              model: selectedChatRoom.model.modelName,
              maxTokens: selectedChatRoom.maxTokenLength,
              user: AppCache.userName.value,
            ),
          );
        } else {
          response = await localModel!.call(
            messagesToSend,
            options: ChatOpenAIOptions(
              model: selectedChatRoom.model.modelName,
              maxTokens: selectedChatRoom.maxTokenLength,
            ),
          );
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
        responseStream = openAI!.stream(
          PromptValue.chat(messagesToSend),
          options: ChatOpenAIOptions(
            model: selectedChatRoom.model.modelName,
            user: AppCache.userName.value,
            maxTokens: selectedChatRoom.maxTokenLength,
            toolChoice: isToolsEnabled ? const ChatToolChoiceAuto() : null,
            tools: isToolsEnabled
                ? [
                    if (AppCache.gptToolCopyToClipboardEnabled.value!)
                      ToolSpec(
                        name: 'copy_to_clipboard_tool',
                        description: 'Tool to copy text to users clipboard',
                        inputJsonSchema: copyToClipboardFunctionParameters,
                      ),
                  ]
                : null,
          ),
        );
      } else {
        if (selectedChatRoom.model.ownedBy == OwnedByEnum.gemini.name) {
          throw Exception('Gemini is not supported yet');
          // TODO: add more models
        } else if (selectedChatRoom.model.ownedBy == OwnedByEnum.claude.name) {
          throw Exception('Claude is not supported yet');
          // TODO: add more models
        }
        responseStream = localModel!.stream(
          PromptValue.chat(messagesToSend),
          options: ChatOpenAIOptions(
            model: selectedChatRoom.model.modelName,
            user: AppCache.userName.value,
            maxTokens: selectedChatRoom.maxTokenLength,
            toolChoice: isToolsEnabled ? const ChatToolChoiceAuto() : null,
            tools: isToolsEnabled
                ? [
                    if (AppCache.gptToolCopyToClipboardEnabled.value!)
                      ToolSpec(
                        name: 'copy_to_clipboard_tool',
                        description: 'Tool to copy text to users clipboard',
                        inputJsonSchema: copyToClipboardFunctionParameters,
                      ),
                  ]
                : null,
          ),
        );
      }

      String functionCallString = '';
      String functionName = '';
      int chunkNumber = 0;

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
            totalTokens += chunk.usage.totalTokens ?? 0;
            totalSentTokens += chunk.usage.promptTokens ?? 0;
            totalReceivedTokens += chunk.usage.responseTokens ?? 0;
          }
          // print('function: $functionCallString, chunk.finishReason: ${chunk.finishReason}');
          if (chunk.finishReason == FinishReason.stop) {
            /// TODO: add more logic here
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
        onDone: () {
          onFinishResponse?.call();
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
          _onResponseEndGenerateImage(response.content, response, action);
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

  Future<int> getTokensFromMessages(List<ChatMessage> messages) async {
    int tokens = 0;
    if (selectedChatRoom.model.ownedBy == 'openai') {
      final tokenizer = Tokenizer();
      if (selectedChatRoom.model.modelName == 'gpt-4o' ||
          selectedChatRoom.model.modelName == 'gpt-3.5-turbo') {
        for (var message in messages) {
          if (message is AIChatMessage) {
            tokens += await tokenizer.count(
              message.content,
              modelName: 'gpt-4-',
            );
          }
        }
      } else {
        for (var message in messages) {
          if (message is AIChatMessage) {
            tokens +=
                await tokenizer.count(message.content, modelName: 'gpt-4');
          }
        }
      }
    }
    return tokens;
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
  Future<List<FluentChatMessage>> getLastMessagesLimitToTokens(
    int tokens, {
    bool allowOverflow = true,
    bool allowImages = false,
  }) async {
    int currentTokens = 0;
    final result = <FluentChatMessage>[];
    final chatModel = selectedChatRoom.model;

    /// We need to count from the bottom to the top. We cant use messagesReversedList because it takes time to populate it
    for (var message in messages.value.values.toList().reversed) {
      if (message.type == FluentChatMessageType.textAi ||
          message.type == FluentChatMessageType.textHuman ||
          message.type == FluentChatMessageType.system ||
          message.type == FluentChatMessageType.file) {
        final tokensCount = message.tokens;
        // await modelCounter.countTokens(PromptValue.string(message.content));
        if ((currentTokens + tokensCount) > tokens) {
          if (kDebugMode) {
            print(
                '[BREAK beacuse of limit] Tokens: $tokensCount; message: ${message.content.split('\n').first} ');
          }
          break;
        }
        currentTokens += tokensCount;
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
    if (selectedModel.ownedBy == 'openai') {
      return openAI!.countTokens(PromptValue.string(text));
    } else {
      return localModel!.countTokens(PromptValue.string(text));
    }
  }

  Future<int> countTokensForMessagesString(List<ChatMessage> messages) async {
    if (selectedModel.ownedBy == 'openai') {
      return openAI!.countTokens(PromptValue.chat(messages));
    } else {
      return localModel!.countTokens(PromptValue.chat(messages));
    }
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
            totalTokens += chunk.usage.totalTokens ?? 0;
            totalSentTokens += chunk.usage.promptTokens ?? 0;
            totalReceivedTokens += chunk.usage.responseTokens ?? 0;
            responseId = chunk.id;
            addBotMessageToList(
                FluentChatMessage.ai(id: responseId, content: message.content));
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

  BehaviorSubject<int> totalTokensForCurrentChat = BehaviorSubject.seeded(0);
  set totalTokens(int value) => totalTokensForCurrentChat.add(value);
  int get totalTokens => totalTokensForCurrentChat.value;

  BehaviorSubject<int> totalSentForCurrentChat = BehaviorSubject.seeded(0);
  set totalSentTokens(int value) {
    totalSentForCurrentChat.add(value);
    selectedChatRoom.totalSentTokens = value;
  }

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

  _requestForTitleChat(String userMessage) async {}

  void clearChatMessages() {
    messages.add({});
    saveToDisk([selectedChatRoom]);
    notifyRoomsStream();
    notifyListeners();
  }

  void notifyRoomsStream() {
    final sortedChatRooms = chatRoomsStream.value.values.toList()
      ..sort((a, b) {
        if (a.indexSort == b.indexSort) {
          return b.dateCreatedMilliseconds.compareTo(a.dateCreatedMilliseconds);
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
            return b.dateCreatedMilliseconds
                .compareTo(a.dateCreatedMilliseconds);
          }
          return a.indexSort.compareTo(b.indexSort);
        });
        sortChatRoomChildren(chatRoom.children!);
      }
    }
  }

  void selectNewModel(ChatModelAi model) {
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
    if (messages.value.isEmpty) return;
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
      repeatPenaltyTokens: repeatPenaltyTokens,
      topP: topP,
      maxTokenLength: maxTokenLenght,
      repeatPenalty: repeatPenalty,
      systemMessage: systemMessage,
      dateCreatedMilliseconds: DateTime.now().millisecondsSinceEpoch,
      totalReceivedTokens: 0,
      totalSentTokens: 0,
    );
    totalTokens = 0;
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
    stopAnswering();
    selectedChatRoomId = room.id;
    initModelsApi();

    messages.add({});
    totalTokens = (room.totalReceivedTokens ?? 0) + (room.totalSentTokens ?? 0);
    totalSentTokens = room.totalSentTokens ?? 0;
    totalReceivedTokens = room.totalReceivedTokens ?? 0;
    await _loadMessagesFromDisk(room.id);
    AppCache.selectedChatRoomId.value = room.id;
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
        if (chatRoomToDelete?.model.modelName == 'error') {
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

  /// Will remove all chat rooms with selected name
  void deleteChatRoomHard(String chatRoomName) {
    chatRooms.removeWhere((key, value) => value.chatRoomName == chatRoomName);
    notifyListeners();
  }

  void editChatRoom(String oldChatRoomId, ChatRoom chatRoom,
      {switchToForeground = false}) {
    final oldChatRoom = chatRooms[oldChatRoomId];
    final isCharNameChanged =
        oldChatRoom!.characterName != chatRoom.characterName;
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
      if (showInfo)
        displayInfoBar(context!, builder: (context, close) {
          return InfoBar(
            title: Text('Message deleted'),
            action: Button(
              onPressed: () {
                revertDeletedMessage();
                close();
              },
              child: Text('Undo'),
            ),
          );
        });
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

  void stopAnswering() {
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
      notifyListeners();
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
      FileUtils.deleteFile(fileInput!.path);
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

  Future<void> regenerateMessage(FluentChatMessage message) async {
    await sendMessage(message.content, hidePrompt: true);
  }

  void updateUI() {
    notifyListeners();
  }

  Future<void> archiveChatRoom(ChatRoom room) async {
    deleteChatRoom(room.id);
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
    final chatRoomRaw =
        jsonDecode(await fileContent.readAsString()) as List<dynamic>;
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
    List<SearchResult> results,
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
            title: const Text('Deepgram API key is not set'),
            severity: InfoBarSeverity.warning,
            action: Button(
              onPressed: () async {
                close();
                // ensure its closed
                await Future.delayed(const Duration(milliseconds: 200));
                Navigator.of(context!).push(
                  FluentPageRoute(builder: (ctx) => const SettingsPage()),
                );
              },
              child: const Text('Settings'),
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
      final newLenghtTokens = await countTokensString(message.content);

      final messagesList = messages.value;
      messagesList[id] = message.copyWith(tokens: newLenghtTokens);
      messages.add(messagesList);
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
    // dont save chat right now because it will override messages in the file with empty list
  }

  void unpinChatRoom(ChatRoom chatRoom) {
    chatRoom.indexSort = 999999;
    notifyRoomsStream();
    // dont save chat right now because it will override messages in the file with empty list
  }

  Future<void> _onResponseEndGenerateImage(String content,
      FluentChatMessage response, OnMessageAction action) async {
    final promptMessage = messages.value.entries.last.value.copyWith();
    // deleteMessage(messagesReversedList.first.id);
    final prompt = response.content.replaceAll(action.regExp, '');

    final openAiModel = allModels.value.firstWhereOrNull(
      (element) => element.ownedBy == 'openai' && element.apiKey.isNotEmpty,
    );
    if (openAiModel == null) {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      addBotErrorMessageToList(
        FluentChatMessage.ai(
          id: timestamp.toString(),
          content:
              'OpenAI model with valid API token not found. Please add at least one openai model with API key.',
          creator: 'error',
          timestamp: timestamp,
        ),
      );
      return;
    }
    isGeneratingImage = true;
    notifyListeners();
    try {
      final imageChatMessage = await DalleApiGenerator.generateImage(
        prompt: prompt,
        apiKey: openAiModel.apiKey,
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
        'Ask user how they feel about your drawing',
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
    final messagesList = messagesReversedList;
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
    repeatPenaltyTokens: repeatPenaltyTokens,
    topP: topP,
    maxTokenLength: maxTokenLenght,
    repeatPenalty: repeatPenalty,
    systemMessage: '',
    dateCreatedMilliseconds: DateTime.now().millisecondsSinceEpoch,
  );
}
