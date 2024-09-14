import 'dart:convert';
// ignore: implementation_imports
import 'package:fluent_gpt/common/chat_model.dart';
import 'package:fluent_gpt/common/conversaton_style_enum.dart';
import 'package:fluent_gpt/common/scrapper/web_scrapper.dart';
import 'package:fluent_gpt/gpt_tools.dart';
import 'package:fluent_gpt/log.dart';

import 'package:fluent_gpt/common/chat_room.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/pages/home_page.dart';
import 'package:fluent_gpt/system_messages.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/input_field.dart';
import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gpt_tokenizer/flutter_gpt_tokenizer.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';
import 'package:rxdart/rxdart.dart';
import 'package:scroll_to_index/scroll_to_index.dart';

ChatOpenAI? openAI;
ChatOpenAI? localModel;
// ChatOllama? llamaAi;

/// First is ID, second is ChatRoom
BehaviorSubject<Map<String, ChatRoom>> chatRoomsStream =
    BehaviorSubject.seeded({});

/// first is ID, second is ChatRoom
Map<String, ChatRoom> get chatRooms => chatRoomsStream.value;

BehaviorSubject<String> selectedChatRoomIdStream =
    BehaviorSubject.seeded('Default');
String get selectedChatRoomId => selectedChatRoomIdStream.value;
set selectedChatRoomId(String v) => selectedChatRoomIdStream.add(v);

ChatModelAi get selectedModel =>
    chatRooms[selectedChatRoomId]?.model ?? allModels.value.last;
ChatRoom get selectedChatRoom =>
    chatRooms[selectedChatRoomId] ??
    (chatRooms.values.isEmpty == true
        ? _generateDefaultChatroom()
        : chatRooms.values.first);
double get temp => chatRooms[selectedChatRoomId]?.temp ?? 0.9;
get topk => chatRooms[selectedChatRoomId]?.topk ?? 40;
get promptBatchSize => chatRooms[selectedChatRoomId]?.promptBatchSize ?? 128;
get repeatPenaltyTokens =>
    chatRooms[selectedChatRoomId]?.repeatPenaltyTokens ?? 64;
get topP => chatRooms[selectedChatRoomId]?.topP ?? 0.4;
get maxLenght => chatRooms[selectedChatRoomId]?.maxTokenLength ?? 512;
get repeatPenalty => chatRooms[selectedChatRoomId]?.repeatPenalty ?? 1.18;

/// the key is id or DateTime.now() (chatcmpl-9QZ8C6NhBc5MBrFCVQRZ2uNhAMAW2)  the answer is message
BehaviorSubject<Map<String, ChatMessage>> messages = BehaviorSubject.seeded({});

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
    if (conversationLenghtStyleStream.value.prompt != null) {
      selectedChatRoom.maxTokenLength =
          conversationLenghtStyleStream.value.maxTokenLenght ??
              selectedChatRoom.maxTokenLength;
    }
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

const defaultChatModels = [
  ChatModelAi(name: 'gpt-4o', apiKey: '', ownedBy: 'openai'),
];

final allModels = BehaviorSubject<List<ChatModelAi>>.seeded([
  /// gpt-4o
  const ChatModelAi(name: 'gpt-4o', apiKey: '', ownedBy: 'openai'),
]);

class ChatProvider with ChangeNotifier {
  final listItemsScrollController = AutoScrollController();
  final TextEditingController messageController = TextEditingController();

  bool includeConversationGlobal = true;
  bool scrollToBottomOnAnswer = true;
  bool isSendingFile = false;
  bool isWebSearchEnabled = false;

  final dialogApiKeyController = TextEditingController();
  bool isAnswering = false;
  CancelToken? cancelToken;

  /// It's not a good practice to use [context] directly in the provider...
  BuildContext? context;

  int _messageTextSize = 14;

  int maxMessagesToIncludeInHistory = 30;

  set textSize(int v) {
    _messageTextSize = v;
    AppCache.messageTextSize.set(v);
    notifyListeners();
  }

  int get textSize => _messageTextSize;

  void toggleScrollToBottomOnAnswer() {
    scrollToBottomOnAnswer = !scrollToBottomOnAnswer;
    notifyListeners();
  }

  Future<void> saveToDisk(List<ChatRoom> rooms) async {
    // ignore: no_leading_underscores_for_local_identifiers
    final _chatRooms = rooms;
    for (var chatRoom in _chatRooms) {
      var chatRoomRaw = await chatRoom.toJson();
      final path = await FileUtils.getChatRoomPath();
      FileUtils.saveFile('$path/${chatRoom.id}.json', jsonEncode(chatRoomRaw));
      final messagesRaw = <Map<String, dynamic>>[];
      for (var message in messages.value.entries) {
        /// add key and message.toJson
        messagesRaw.add({
          'id': message.key,
          'message': message.value.toJson(),
        });
      }
      FileUtils.saveChatMessages(chatRoom.id, jsonEncode(messagesRaw));
    }
    if (_chatRooms.length == 1)
      AppCache.selectedChatRoomId.set(selectedChatRoomId);
  }

  Future<void> initChatsFromDisk() async {
    final path = await FileUtils.getChatRoomPath();
    final files = FileUtils.getFilesRecursive(path);
    for (var file in files) {
      try {
        if (file.path.contains('.DS_Store')) continue;
        final fileContent = await file.readAsString();
        final chatRoomRaw = jsonDecode(fileContent) as Map<String, dynamic>;
        final chatRoom = await ChatRoom.fromMap(chatRoomRaw);
        chatRooms[chatRoom.id] = chatRoom;
        if (chatRoom.id == selectedChatRoomId) {
          initCurrentChat();
          await _loadMessagesFromDisk(chatRoom.id);
          if (messages.value.isNotEmpty) scrollToEnd();
        }
      } catch (e) {
        log('initChatsFromDisk error: $e');
        chatRooms[file.path] = ChatRoom(
          id: file.path,
          chatRoomName: 'Error ${file.path}',
          model: const ChatModelAi(name: 'error', apiKey: ''),
          messages: ConversationBufferMemory(),
          temp: temp,
          topk: topk,
          promptBatchSize: promptBatchSize,
          repeatPenaltyTokens: repeatPenaltyTokens,
          topP: topP,
          maxTokenLength: maxLenght,
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
    selectedChatRoomId = selectedChatRoomId;
    notifyRoomsStream();
  }

  ChatProvider() {
    _messageTextSize = AppCache.messageTextSize.value ?? 14;
    selectedChatRoomId = AppCache.selectedChatRoomId.value ?? 'Default';
    init();
    listenTray();
  }
  init() async {
    await initChatModels();
    await initChatsFromDisk();
  }

  _retrieveLocalModels() async {
    var localApi = AppCache.localApiUrl.value;
    if (localApi == null || localApi.isEmpty == true) return;

    localApi = localApi.replaceAll('/api', '');
    // retrieve models
    // curl http://0.0.0.0:1234/v1/models/
    try {
      final dio = Dio();
      final response = await dio.get('$localApi/models/');
      final respJson = response.data as Map<String, dynamic>;
      final models = respJson['data'] as List;
      final listModels = models
          .map(
            (e) => ChatModelAi.fromServerJson(e as Map<String, dynamic>,
                apiKey: AppCache.openAiApiKey.value ?? ''),
          )
          .toList();
      allModels.add([...defaultChatModels, ...listModels]);
    } catch (e) {
      logError('Error retrieving local models: $e');
    }
  }

  initChatModels() async {
    // final listModelsJsonString = await AppCache.savedModels.value();
    // if (listModelsJsonString?.isNotEmpty == true) {
    //   final listModelsJson = jsonDecode(listModelsJsonString!) as List;
    //   final listModels = listModelsJson
    //       .map((e) => ChatModelAi.fromJson(e as Map<String, dynamic>))
    //       .toList();
    //   allModels.add(listModels);
    // }
    allModels.add(defaultChatModels);
    await _retrieveLocalModels();
  }

  /// Should be called after we load all chat rooms
  void initCurrentChat() {
    openAI = ChatOpenAI(apiKey: AppCache.openAiApiKey.value);
    if (AppCache.localApiUrl.value != null &&
        AppCache.localApiUrl.value!.isNotEmpty)
      localModel = ChatOpenAI(
        baseUrl: AppCache.localApiUrl.value!,
        apiKey: AppCache.openAiApiKey.value,
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
      if (command == 'paste') {
        if (text.trim().isNotEmpty == true) {
          sendMessage(text, true);
        }
      } else if (command == 'custom') {
        sendMessage(text, true);
      } else if (command == 'show_dialog') {
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
      } else if (command == 'grammar') {
        sendMessage('Check spelling and grammar: "$text"', true);
      } else if (command == 'explain') {
        sendMessage('Explain: "$text"', true);
      } else if (command == 'to_rus') {
        sendMessage('Translate to Rus: "$text"', true);
      } else if (command == 'to_eng') {
        sendMessage('Translate to English: "$text"', true);
      } else if (command == 'impove_writing') {
        sendMessage('Improve writing: "$text"', true);
      } else if (command == 'summarize_markdown_short') {
        sendMessage(
            'Summarize using markdown. Use short summary: "$text"', false);
      } else if (command == 'answer_with_tags') {
        HotShurtcutsWidget.showAnswerWithTagsDialog(context!, text);
      } else if (command == 'create_new_chat') {
        createNewChatRoom();
      } else if (command == 'reset_chat') {
        clearChatMessages();
      } else if (command == 'escape_cancel_select') {
      } else {
        throw Exception('Unknown command: $command');
      }
    });
  }

  XFile? fileInput;
  void addFileToInput(XFile file) {
    fileInput = file;
    notifyListeners();
  }

  void addWebResultsToMessages(List<SearchResult> webpage) {
    final values = messages.value;
    List results = [];
    for (var result in webpage) {
      results.add(result.toJson());
    }
    values[DateTime.now().toIso8601String()] = CustomChatMessage(
      content: jsonEncode(results),
      role: ChatMessageRole.custom.name,
    );
    messages.add(values);
    saveToDisk([selectedChatRoom]);
    scrollToEnd();
  }

  void renameCurrentChatRoom(String newName) {
    final chatRoom = chatRooms[selectedChatRoomId]!;
    chatRoom.chatRoomName = newName;
    notifyRoomsStream();
    saveToDisk([selectedChatRoom]);
  }

  Future<void> generateUserKnowladgeBasedOnText(String text) async {
    final userName = AppCache.userName.value;
    final response = await retrieveResponseFromPrompt(
      'Based on this messages/conversation/text give me a short sentence to populate knowladge about $userName:'
      '"$text"',
    );
  }

  Future<void> sendMessage(
    String messageContent, [
    bool hidePrompt = false,
  ]) async {
    bool isFirstMessage = messages.value.isEmpty;
    if (isFirstMessage) {
      /// Name chat room
      if (AppCache.useSecondRequestForNamingChats.value!) {
        retrieveResponseFromPrompt(
          '$nameTopicPrompt "$messageContent"',
        ).then(renameCurrentChatRoom);
      } else {
        final first50CharsIfPossible = messageContent.length > 50
            ? messageContent.substring(0, 50)
            : messageContent;
        renameCurrentChatRoom(first50CharsIfPossible);
      }
    }
    if (isWebSearchEnabled) {
      addHumanMessageToList(
        HumanChatMessage(content: ChatMessageContent.text(messageContent)),
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
        addBotErrorMessageToList(
          SystemChatMessage(content: 'Error while searching: $e'),
        );
      }

      isAnswering = false;
      notifyListeners();
      return;
    }

    /// add additional styles to the message
    messageContent = modifyMessageStyle(messageContent);

    final isImageAttached =
        fileInput != null && fileInput!.mimeType?.contains('image') == true;
    if (isImageAttached) {
      final bytes = await fileInput!.readAsBytes();
      final base64 = base64Encode(bytes);
      if (messageController.text.trim().isNotEmpty) {
        addHumanMessageToList(
          HumanChatMessage(content: ChatMessageContent.text(messageContent)),
        );
      }
      addHumanMessageToList(
        HumanChatMessage(
          content: ChatMessageContent.image(
            data: base64,
            mimeType: fileInput!.mimeType,
          ),
        ),
        DateTime.now().add(const Duration(milliseconds: 50)).toIso8601String(),
      );
    } else {
      addHumanMessageToList(
        HumanChatMessage(content: ChatMessageContent.text(messageContent)),
      );
    }
    await selectedChatRoom.messages.chatHistory
        .addHumanChatMessage(messageContent);
    isAnswering = true;
    notifyListeners();
    late Stream<ChatResult> stream;
    final messagesToSend = <ChatMessage>[];
    if (includeConversationGlobal) {
      messagesToSend.addAll(
        await getLastFewMessages(count: maxMessagesToIncludeInHistory),
      );
    } 
    if (!includeConversationGlobal) {
      if (selectedChatRoom.systemMessage?.isNotEmpty == true) {
        final systemMessage = await getFormattedSystemPrompt(
          basicPrompt: selectedChatRoom.systemMessage!,
        );
        messagesToSend.add(SystemChatMessage(content: systemMessage));
      }

      messagesToSend.add(
        HumanChatMessage(content: ChatMessageContent.text(messageContent)),
      );
      if (isImageAttached){
        messagesToSend.add(
          HumanChatMessage(
            content: ChatMessageContent.image(
              data: base64Encode(await fileInput!.readAsBytes()),
              mimeType: fileInput!.mimeType,
            ),
          ),
        );
      }
    }
    if (selectedChatRoom.model.ownedBy == 'openai') {
      if (openAI?.apiKey == null || openAI?.apiKey.isEmpty == true) {
        openAI = ChatOpenAI(apiKey: AppCache.openAiApiKey.value);
      }
      stream = openAI!.stream(
        PromptValue.chat(messagesToSend),
        options: ChatOpenAIOptions(
          model: selectedChatRoom.model.name,
          maxTokens: selectedChatRoom.maxTokenLength,
          toolChoice: const ChatToolChoiceAuto(),
          tools: const [
            ToolSpec(
              name: 'copy_to_clipboard_tool',
              description: 'Tool to copy text to users clipboard',
              inputJsonSchema: copyToClipboardFunctionParameters,
            ),
          ],
        ),
      );
    } else {
      stream = localModel!.stream(
        PromptValue.chat(messagesToSend),
        options: ChatOpenAIOptions(
          model: selectedChatRoom.model.name,
          maxTokens: selectedChatRoom.maxTokenLength,
          toolChoice: const ChatToolChoiceAuto(),
          tools: const [
            ToolSpec(
              name: 'copy_to_clipboard_tool',
              description: 'Tool to copy text to users clipboard',
              inputJsonSchema: copyToClipboardFunctionParameters,
            ),
          ],
        ),
      );
    }

    try {
      String functionCallString = '';
      String functionName = '';
      await stream.forEach(
        (final chunk) {
          final message = chunk.output;
          // totalTokensForCurrentChat += chunk.usage.totalTokens ?? 0;
          if (message.toolCalls.isEmpty)
            addBotMessageToList(message, chunk.id);
          else {
            functionCallString += message.toolCalls.first.argumentsRaw;
            if (message.toolCalls.first.name.isNotEmpty == true) {
              functionName = message.toolCalls.first.name;
            }
          }
          // print(
          //     'function: $functionCallString, chunk.finishReason: ${chunk.finishReason}');
          if (chunk.finishReason == FinishReason.stop) {
            /// TODO: add more logic here
            saveToDisk([selectedChatRoom]);
            isAnswering = false;
            refreshTokensForCurrentChat();
            onResponseEnd(messageContent, chunk.id);
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
            refreshTokensForCurrentChat();
          } else if (chunk.finishReason == FinishReason.toolCalls) {
            final lastChar = functionCallString[functionCallString.length - 1];
            if (lastChar == '}') {
              final decoded = jsonDecode(functionCallString);
              _onToolsResponseEnd(messageContent, decoded, functionName);
            }
            isAnswering = false;
            refreshTokensForCurrentChat();
          }
        },
      );
    } catch (e, stack) {
      logError('Error while answering: $e', stack);
      addBotErrorMessageToList(
        SystemChatMessage(content: 'Error while answering: $e'),
      );
      isAnswering = false;
    }

    fileInput = null;
    notifyListeners();
    saveToDisk([selectedChatRoom]);
  }

  void onResponseEnd(String userContent, String id) async {
    /* do nothing for now */
  }

  Future<int> getTokensFromMessages(List<ChatMessage> messages) async {
    int tokens = 0;
    if (selectedChatRoom.model.ownedBy == 'openai') {
      final tokenizer = Tokenizer();
      if (selectedChatRoom.model.name == 'gpt-4o' ||
          selectedChatRoom.model.name == 'gpt-3.5-turbo') {
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

  Future refreshTokensForCurrentChat() async {
    final tokens = await getTokensFromMessages(messages.value.values.toList());
    totalTokensForCurrentChat = tokens;
    notifyListeners();
  }

  List<ChatMessage> getLastFewMessagesForContext() {
    final values = messages.value;
    final lastMessages = values.values.toList().take(15).toList();
    return lastMessages;
  }

  Future<List<ChatMessage>> getLastFewMessages({int count = 15}) async {
    final values = messages.value;
    final list = values.values
        .where(
          (element) => element is! CustomChatMessage,
        )
        .take(count)
        .toList();
    // append current global system message to the very beginning
    if (selectedChatRoom.systemMessage?.isNotEmpty == true) {
      list.insert(
        0,
        SystemChatMessage(
          content: await getFormattedSystemPrompt(
            basicPrompt: selectedChatRoom.systemMessage!,
          ),
        ),
      );
    }

    return list;
  }

  String getLastFewMessagesForContextAsString() {
    final lastMessages = getLastFewMessagesForContext();
    return lastMessages.map((e) {
      if (e is HumanChatMessage && e.content is ChatMessageContentText) {
        return 'Human: ${(e.content as ChatMessageContentText).text}';
      }
      if (e is AIChatMessage) {
        return 'Ai: ${e.content}';
      }
      if (e is CustomChatMessage) {
        final jsonContent = jsonDecode(e.content);
        if (jsonContent is List) {
          final results =
              jsonContent.map((e) => SearchResult.fromJson(e)).toList();
          return 'Web search results: ${results.map((e) => '${e.title}->${e.description}').join(';')}';
        }
      }
      return '';
    }).join('\n');
  }

  /// Will not use chat history.
  /// Will populate messages
  Future sendSingleMessage(String messageContent, {int? maxTokens}) async {
    final messagesToSend = <ChatMessage>[];
    messagesToSend.add(
        HumanChatMessage(content: ChatMessageContent.text(messageContent)));
    Stream<ChatResult> stream;
    if (selectedModel.ownedBy == 'openai') {
      stream = openAI!.stream(PromptValue.chat(messagesToSend),
          options: ChatOpenAIOptions(
            model: selectedChatRoom.model.name,
            maxTokens: maxTokens,
          ));
    } else {
      stream = localModel!.stream(
        PromptValue.chat(messagesToSend),
        options: ChatOpenAIOptions(
          model: selectedChatRoom.model.name,
          maxTokens: maxTokens,
        ),
      );
    }

    await stream.forEach(
      (final chunk) {
        final message = chunk.output;
        totalTokensForCurrentChat += chunk.usage.totalTokens ?? 0;
        addBotMessageToList(message, chunk.id);
        if (chunk.finishReason == FinishReason.stop) {
          saveToDisk([selectedChatRoom]);
        } else if (chunk.finishReason == FinishReason.length) {
          saveToDisk([selectedChatRoom]);
        }
      },
    );
  }

  /// will not use chat history.
  /// Will not populate messages
  Future<String> retrieveResponseFromPrompt(String message) async {
    final messagesToSend = <ChatMessage>[];

    messagesToSend
        .add(HumanChatMessage(content: ChatMessageContent.text(message)));

    AIChatMessage response;
    if (selectedModel.ownedBy == 'openai') {
      response = await openAI!.call(messagesToSend);
    } else {
      response = await localModel!.call(messagesToSend);
    }
    return response.content;
  }

  int totalTokensForCurrentChat = 0;

  void addBotMessageToList(AIChatMessage message, [String? id]) {
    final values = messages.value;
    final lastMessage = values[id ?? DateTime.now().toIso8601String()];
    String newString = '';
    if (lastMessage != null) {
      newString = lastMessage.concat(message).contentAsString;
    } else {
      newString = message.contentAsString;
    }
    values[id ?? DateTime.now().toIso8601String()] =
        AIChatMessage(content: newString);
    messages.add(values);
    if (scrollToBottomOnAnswer) {
      listItemsScrollController.animateTo(
        listItemsScrollController.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 1),
        curve: Curves.easeOut,
      );
    }
  }

  void addBotErrorMessageToList(SystemChatMessage message, [String? id]) {
    final values = messages.value;
    values[id ?? DateTime.now().toIso8601String()] = message;
    messages.add(values);
    scrollToEnd();
  }

  /// Used to add message silently to the list
  void addHumanMessageToList(HumanChatMessage message, [String? id]) {
    final values = messages.value;
    values[id ?? DateTime.now().toIso8601String()] = message;
    messages.add(values);
    saveToDisk([selectedChatRoom]);
    scrollToEnd();
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
      addBotMessageToList(
          AIChatMessage(content: "```Clipboard\n$textToCopy\n```\n$text"));
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
    selectedChatRoom.messages.clear();
    saveToDisk([selectedChatRoom]);
    notifyRoomsStream();
  }

  void notifyRoomsStream() {
    final chatRooms = chatRoomsStream.value;
    final sortedChatRooms = chatRooms.values.toList()
      ..sort((a, b) {
        if (a.indexSort == b.indexSort) {
          return b.dateCreatedMilliseconds.compareTo(a.dateCreatedMilliseconds);
        }
        return a.indexSort.compareTo(b.indexSort);
      });
    chatRoomsStream.add(
      {
        for (var e in sortedChatRooms) (e).id: e,
      },
    );
  }

  void selectNewModel(ChatModelAi model) {
    chatRooms[selectedChatRoomId]!.model = model;
    notifyListeners();
    saveToDisk([selectedChatRoom]);
  }

  void selectModelForChat(String chatRoomName, ChatModelAi model) {
    chatRooms[chatRoomName]!.model = model;
    notifyRoomsStream();
    saveToDisk([selectedChatRoom]);
  }

  Future<void> createNewChatRoom() async {
    final chatRoomName = 'Chat ${chatRooms.length + 1}';
    final id = generateChatID();
    String systemMessage = '';
    if (defaultSystemMessage.isNotEmpty == true) {
      systemMessage =
          await getFormattedSystemPrompt(basicPrompt: defaultSystemMessage);
    }

    chatRooms[id] = ChatRoom(
      id: id,
      chatRoomName: chatRoomName,
      model: selectedModel,
      messages: ConversationBufferMemory(),
      temp: temp,
      topk: topk,
      promptBatchSize: promptBatchSize,
      repeatPenaltyTokens: repeatPenaltyTokens,
      topP: topP,
      maxTokenLength: maxLenght,
      repeatPenalty: repeatPenalty,
      systemMessage: systemMessage,
      dateCreatedMilliseconds: DateTime.now().millisecondsSinceEpoch,
    );
    totalTokensForCurrentChat = 0;
    notifyListeners();
    notifyRoomsStream();
    selectedChatRoomId = id;
    messages.add({});

    saveToDisk([selectedChatRoom]);
  }

  Future<void> deleteAllChatRooms() async {
    chatRooms.clear();
    final path = await FileUtils.getChatRoomPath();
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
    selectedChatRoomId = room.id;
    openAI = ChatOpenAI(apiKey: AppCache.openAiApiKey.value);
    messages.add({});
    if (AppCache.localApiUrl.value!.isNotEmpty)
      localModel = ChatOpenAI(
        apiKey: AppCache.openAiApiKey.value,
        baseUrl: AppCache.localApiUrl.value!,
      );
    totalTokensForCurrentChat = 0;
    await _loadMessagesFromDisk(room.id);
    refreshTokensForCurrentChat();
    scrollToEnd();
  }

  Future<void> deleteChatRoom(String chatRoomId) async {
    final chatRoomToDelete = chatRooms[chatRoomId];
    chatRooms.remove(chatRoomId);
    // if last one - create a default one
    if (chatRooms.isEmpty) {
      final newChatRoom = _generateDefaultChatroom(
        systemMessage:
            await getFormattedSystemPrompt(basicPrompt: defaultSystemMessage),
      );
      chatRooms[newChatRoom.id] = newChatRoom;
      selectedChatRoomId = newChatRoom.id;
    }
    if (chatRoomId == selectedChatRoomId) {
      selectedChatRoomId = chatRooms.keys.last;
    }
    FileUtils.getChatRoomPath().then((dir) async {
      final archivedChatRoomsPath = await FileUtils.getArchivedChatRoomPath();
      if (chatRoomToDelete?.model.name == 'error') {
        // in this case id is the path
        FileUtils.deleteFile(chatRoomId);
      } else {
        FileUtils.moveFile(
            '$dir/$chatRoomId.json', '$archivedChatRoomsPath/$chatRoomId.json');
      }
    });

    /// 2. Delete messages file
    FileUtils.getChatRoomMessagesFileById(chatRoomId).then((file) async {
      final archivedChatRoomsPath = await FileUtils.getArchivedChatRoomPath();
      if (chatRoomToDelete?.model.name == 'error') {
        FileUtils.deleteFile(chatRoomId);
      } else {
        FileUtils.moveFile(
            file.path, '$archivedChatRoomsPath/${file.path.split('/').last}');
      }
    });
    notifyListeners();
  }

  /// Will remove all chat rooms with selected name
  void deleteChatRoomHard(String chatRoomName) {
    chatRooms.removeWhere((key, value) => value.chatRoomName == chatRoomName);
    notifyListeners();
  }

  void editChatRoom(String oldChatRoomId, ChatRoom chatRoom,
      {switchToForeground = false}) {
    if (selectedChatRoomId == oldChatRoomId) {
      openAI = ChatOpenAI(apiKey: AppCache.openAiApiKey.value);
      switchToForeground = true;
    }
    chatRooms.remove(oldChatRoomId);
    chatRooms[chatRoom.id] = chatRoom;
    if (switchToForeground) {
      selectedChatRoomId = chatRoom.id;
    }
    notifyRoomsStream();
    saveToDisk([selectedChatRoom]);
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

  void deleteMessage(String id) {
    // messages.remove(id);
    final value = messages.value;
    value.remove(id);
    messages.add(value);
    saveToDisk([selectedChatRoom]);
  }

  @Deprecated('Is not implemented on the plugin level')
  void stopAnswering() {
    try {
      cancelToken?.cancel('canceled ');
      log('Canceled');
    } catch (e) {
      log('Error while canceling: $e');
    } finally {
      isAnswering = false;
      notifyListeners();
    }
  }

  void addMessageSystem(String message) {
    final value = messages.value;
    value[DateTime.now().toIso8601String()] =
        SystemChatMessage(content: message);
    messages.add(value);
    saveToDisk([selectedChatRoom]);
    scrollToEnd();
  }

  void setIncludeWholeConversation(bool v) {
    includeConversationGlobal = v;
    notifyListeners();
  }

  void removeFileFromInput() {
    fileInput = null;
    notifyListeners();
  }

  Future<void> scrollToEnd() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (messages.value.isEmpty) return;
    if (listItemsScrollController.hasClients == false) return;
    listItemsScrollController.animateTo(
      listItemsScrollController.position.maxScrollExtent + 200,
      duration: const Duration(milliseconds: 1),
      curve: Curves.easeOut,
    );
    // await scrollOffsetController.animateScroll(
    //   offset: 200,
    //   duration: const Duration(milliseconds: 400),
    // );
  }

  Future<void> regenerateMessage(ChatMessage message) async {
    await sendMessage(message.contentAsString, true);
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
      '\n"${message?.contentAsString}"',
    );
  }

  void lengthenMessage(String id) {
    final message = messages.value[id];
    sendSingleMessage(
      'Please expand the following text by providing more details and explanations. Make the text more specific and elaborate on the key points, while keeping it clear and understandable'
      '\n"${message?.contentAsString}"',
    );
  }

  Future _loadMessagesFromDisk(String id) async {
    final roomId = id;
    final fileContent = await FileUtils.getChatRoomMessagesFileById(roomId);
    final chatRoomRaw =
        jsonDecode(await fileContent.readAsString()) as List<dynamic>;
    // id is the key
    final roomMessages = <String, ChatMessage>{};
    for (var messageJson in chatRoomRaw) {
      try {
        final key = messageJson['id'] as String;
        final content = messageJson['message'] as Map<String, dynamic>;
        roomMessages[key] = ChatRoom.chatMessageFromJson(content);
      } catch (e) {
        logError('Error while loading message from disk: $e');
      }
    }
    selectedChatRoom.messages = ConversationBufferMemory(
      chatHistory: ChatMessageHistory(messages: roomMessages.values.toList()),
    );
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

  Future<void> scrollToMessage(String messageKey) async {
    final index =
        indexOf(messages.value.values.toList(), messages.value[messageKey]);
    await listItemsScrollController.scrollToIndex(index);
  }

  /// custom get index
  int indexOf(List<ChatMessage> list, ChatMessage? element, [int start = 0]) {
    if (start < 0) start = 0;
    for (int i = start; i < list.length; i++) {
      final first = list[i];
      if (first is HumanChatMessage && element is HumanChatMessage) {
        if (first.content is ChatMessageContentText &&
            element.content is ChatMessageContentText) {
          if ((first.content as ChatMessageContentText).text ==
              (element.content as ChatMessageContentText).text) {
            return i;
          }
        }
      } else if (first is AIChatMessage && element is AIChatMessage) {
        if (first.content == element.content) {
          return i;
        }
      }
    }
    return -1;
  }
}

ChatRoom _generateDefaultChatroom({String? systemMessage}) {
  return ChatRoom(
    id: generateChatID(),
    chatRoomName: 'Default',
    model: selectedModel,
    messages: ConversationBufferMemory(),
    temp: temp,
    topk: topk,
    promptBatchSize: promptBatchSize,
    repeatPenaltyTokens: repeatPenaltyTokens,
    topP: topP,
    maxTokenLength: maxLenght,
    repeatPenalty: repeatPenalty,
    systemMessage: '',
    dateCreatedMilliseconds: DateTime.now().millisecondsSinceEpoch,
  );
}
