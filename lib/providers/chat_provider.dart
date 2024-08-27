import 'dart:convert';
// ignore: implementation_imports
import 'package:fluent_gpt/common/chat_model.dart';
import 'package:fluent_gpt/common/conversaton_style_enum.dart';
import 'package:fluent_gpt/common/scrapper/web_scrapper.dart';
import 'package:fluent_gpt/log.dart';

import 'package:fluent_gpt/common/chat_room.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/shell_driver.dart';
import 'package:fluent_gpt/system_messages.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/input_field.dart';
import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tiktoken/tiktoken.dart';

ChatOpenAI? openAI;
ChatOpenAI? llamaAi;
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

final allModels = BehaviorSubject<List<ChatModelAi>>.seeded([
  /// gpt-4o
  ChatModelAi(name: 'gpt-4o', apiKey: '', ownedBy: 'openai'),
]);

class ChatProvider with ChangeNotifier {
  final listItemsScrollController = ScrollController();
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

  bool useSecondRequestForNamingChats = true;
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

  Future<void> saveToDisk([List<ChatRoom>? rooms]) async {
    // ignore: no_leading_underscores_for_local_identifiers
    final _chatRooms = rooms ?? chatRooms.values.toList();
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
          _loadMessagesFromDisk(chatRoom.id);
        }
      } catch (e) {
        log('initChatsFromDisk error: $e');
        chatRooms[file.path] = ChatRoom(
          id: file.path,
          chatRoomName: 'Error ${file.path}',
          model: ChatModelAi(name: 'error', apiKey: ''),
          messages:
              ConversationBufferMemory(systemPrefix: defaultSystemMessage),
          temp: temp,
          topk: topk,
          promptBatchSize: promptBatchSize,
          repeatPenaltyTokens: repeatPenaltyTokens,
          topP: topP,
          maxTokenLength: maxLenght,
          repeatPenalty: repeatPenalty,
          systemMessage: defaultSystemMessage,
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
    allModels.add([...allModels.value, ...listModels]);
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
    allModels.add(allModels.value);
    await _retrieveLocalModels();
  }

  /// Should be called after we load all chat rooms
  void initCurrentChat() {
    openAI = ChatOpenAI(apiKey: AppCache.openAiApiKey.value);
    llamaAi = ChatOpenAI(
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

  Future<void> sendMessage(
    String messageContent, [
    bool hidePrompt = false,
  ]) async {
    bool isFirstMessage = messages.value.isEmpty;
    if (isWebSearchEnabled) {
      final scrapper = WebScraper();
      final results = await scrapper.search(messageContent);

      for (var result in results) {
        addBotMessageToList(
          AIChatMessage(content: '${result.title}\n\n${result.description}'),
        );
        // TODO parse and feed to LLM
      }
      return;
    }

    /// add additional styles to the message
    messageContent = modifyMessageStyle(messageContent);

    final isImageAttached =
        fileInput != null && fileInput!.mimeType?.contains('image') == true;
    if (isImageAttached) {
      final bytes = await fileInput!.readAsBytes();
      final base64 = base64Encode(bytes);
      addUserMessageToList(
        HumanChatMessage(
          content: ChatMessageContent.image(
              data: base64, mimeType: fileInput!.mimeType),
        ),
      );
    } else {
      addUserMessageToList(
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
      messagesToSend.addAll(messages.value.values);
    } else {
      messagesToSend.add(
          HumanChatMessage(content: ChatMessageContent.text(messageContent)));
    }
    if (selectedChatRoom.model.ownedBy == 'openai') {
      if (openAI?.apiKey == null || openAI?.apiKey.isEmpty == true) {
        openAI = ChatOpenAI(apiKey: AppCache.openAiApiKey.value);
      }
      stream = openAI!.stream(PromptValue.chat(messagesToSend),
          options: ChatOpenAIOptions(
            model: selectedChatRoom.model.name,
          ));
    } else {
      stream = llamaAi!.stream(
        PromptValue.chat(messagesToSend),
        options: ChatOpenAIOptions(
          model: selectedChatRoom.model.name,
        ),
      );
    }

    await stream.forEach(
      (final chunk) {
        final message = chunk.output;
        totalTokensForCurrentChat += chunk.usage.totalTokens ?? 0;
        addBotMessageToList(message, chunk.id);
        if (chunk.finishReason == FinishReason.stop) {
          /// TODO: add more logic here
          saveToDisk([selectedChatRoom]);
        } else if (chunk.finishReason == FinishReason.length) {
          /// Maximum tokens reached
          saveToDisk([selectedChatRoom]);
        }
      },
    );

    fileInput = null;
    notifyListeners();
    saveToDisk([selectedChatRoom]);
  }

  /// Will not use chat history
  Future sendSingleMessage(String messageContent) async {
    final messagesToSend = <ChatMessage>[];
    messagesToSend.add(
        HumanChatMessage(content: ChatMessageContent.text(messageContent)));
    final stream = openAI!.stream(PromptValue.chat(messagesToSend),
        options: ChatOpenAIOptions(
          model: selectedChatRoom.model.name,
        ));
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

  // LanguageModelUsage? usageForCurrentChat;
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
      scrollToEnd();
    }
  }

  void addBotErrorMessageToList(CustomChatMessage message, [String? id]) {
    final values = messages.value;
    values[id ?? DateTime.now().toIso8601String()] = message;
    messages.add(values);
    scrollToEnd();
  }

  /// Used to add message silently to the list
  void addUserMessageToList(HumanChatMessage message, [String? id]) {
    final values = messages.value;
    values[id ?? DateTime.now().toIso8601String()] = message;
    messages.add(values);
    saveToDisk([selectedChatRoom]);
    scrollToEnd();
  }

  Future _onToolsResponseEnd(
    String userContent,
    Map<String, dynamic> assistantArgs,
  ) async {
    //e.g. {index: 0, id: call_ko18NuZ0HCgKkk5rcBZyUQ3B, type: function, function: {name: search_files, arguments: {"filename":"1.png","offset":0,"maxNumberFiles":10}}}
    log('assistantArgs: $assistantArgs');
    final toolFunction = assistantArgs['function'] as Map<String, dynamic>;
    final toolName = toolFunction['name'];
    final toolArgsString = toolFunction['arguments'] as String;
    final toolArgs = jsonDecode(toolArgsString) as Map<String, dynamic>;
    if (toolName == 'search_files') {
      final fileName = '${toolArgs['filename']}';
      toolArgs.remove('filename');

      final result =
          await ShellDriver.runShellSearchFileCommand(fileName, toolArgs);
      addBotMessageToList(AIChatMessage(content: result));
    } else if (toolName == 'get_current_weather') {
      final location = toolArgs['location'];
      // final unit = toolArgs['unit'];
      final result = await ShellDriver.runShellCommand(
          'curl wttr.in/$location?format="%C+%t+%w+%h+%p"');
      addBotMessageToList(AIChatMessage(content: result));
    } else if (toolName == 'write_python_code') {
      final code = toolArgs['code'];
      final responseMessage = toolArgs['responseMessage'];
      addBotMessageToList(AIChatMessage(content: '$code\n$responseMessage'));
    } else {
      addBotMessageToList(AIChatMessage(content: 'Unknown tool: $toolName'));
    }
  }

  _requestForTitleChat(String userMessage) async {}

  void clearChatMessages() {
    messages.add({});
    selectedChatRoom.messages.clear();
    saveToDisk();
    notifyRoomsStream();
  }

  void notifyRoomsStream() {
    chatRoomsStream.add(chatRooms);
  }

  void selectNewModel(ChatModelAi model) {
    chatRooms[selectedChatRoomId]!.model = model;
    notifyListeners();
    saveToDisk();
  }

  void selectModelForChat(String chatRoomName, ChatModelAi model) {
    chatRooms[chatRoomName]!.model = model;
    calcUsageTokens(null);
    notifyRoomsStream();
    saveToDisk();
  }

  void createNewChatRoom() {
    final chatRoomName = 'Chat ${chatRooms.length + 1}';
    final id = generateChatID();
    chatRooms[id] = ChatRoom(
      id: id,
      chatRoomName: chatRoomName,
      model: selectedModel,
      messages: ConversationBufferMemory(systemPrefix: defaultSystemMessage),
      temp: temp,
      topk: topk,
      promptBatchSize: promptBatchSize,
      repeatPenaltyTokens: repeatPenaltyTokens,
      topP: topP,
      maxTokenLength: maxLenght,
      repeatPenalty: repeatPenalty,
      systemMessage: defaultSystemMessage,
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
    llamaAi = ChatOpenAI(
        apiKey: AppCache.openAiApiKey.value,
        baseUrl: AppCache.localApiUrl.value!);
    totalTokensForCurrentChat = 0;
    _loadMessagesFromDisk(room.id);
    notifyListeners();
  }

  void deleteChatRoom(String chatRoomId) {
    chatRooms.remove(chatRoomId);
    // if last one - create a default one
    if (chatRooms.isEmpty) {
      final newChatRoom = _generateDefaultChatroom();
      chatRooms[newChatRoom.id] = newChatRoom;
      selectedChatRoomId = newChatRoom.id;
    }
    if (chatRoomId == selectedChatRoomId) {
      selectedChatRoomId = chatRooms.keys.last;
    }
    FileUtils.getChatRoomPath().then((dir) async {
      final archivedChatRoomsPath = await FileUtils.getArchivedChatRoomPath();
      FileUtils.moveFile(
          '$dir/$chatRoomId.json', '$archivedChatRoomsPath/$chatRoomId.json');
    });
    notifyListeners();
  }

  /// Will remove all chat rooms with selected name
  void deleteChatRoomHard(String chatRoomName) {
    chatRooms.removeWhere((key, value) => value.chatRoomName == chatRoomName);
    notifyListeners();
    saveToDisk();
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
    saveToDisk();
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

  void stopAnswering() {
    try {
      cancelToken?.cancel('canceled ');
      log('Canceled');
    } catch (e) {
      log('Error while canceling: $e');
    } finally {
      calcUsageTokens(null);
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
    await listItemsScrollController.animateTo(
      listItemsScrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  Future<void> regenerateMessage(ChatMessage message) async {
    await sendMessage(message.contentAsString, true);
  }

  void calcUsageTokens(double? totalTokens) {
    if (totalTokens != null) {
      log('Usage: $totalTokens');
      return;
    }

    String modelName = selectedModel.name;

    final encoding = encodingForModel(modelName);
    final listTexts =
        messages.value.values.map((e) => e.contentAsString).toList();
    final oneLine = listTexts.join('');
    final uint = encoding.encode(oneLine);
    // selectedChatRoom.tokens = uint.length;
    // selectedChatRoom.costUSD = CostCalculator.calculateCostPerToken(
    //   selectedChatRoom.tokens ?? 0,
    //   modelName,
    // );
    // AppCache.tokensUsedTotal.value = selectedChatRoom.tokens ?? 0;
    // AppCache.costTotal.value = selectedChatRoom.costUSD ?? 0;
  }

  toggleUseSecondRequestForNamingChats() {
    useSecondRequestForNamingChats = !useSecondRequestForNamingChats;
    notifyListeners();
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
}

ChatRoom _generateDefaultChatroom() {
  return ChatRoom(
    id: generateChatID(),
    chatRoomName: 'Default',
    model: selectedModel,
    messages: ConversationBufferMemory(systemPrefix: defaultSystemMessage),
    temp: temp,
    topk: topk,
    promptBatchSize: promptBatchSize,
    repeatPenaltyTokens: repeatPenaltyTokens,
    topP: topP,
    maxTokenLength: maxLenght,
    repeatPenalty: repeatPenalty,
    systemMessage: defaultSystemMessage,
  );
}
