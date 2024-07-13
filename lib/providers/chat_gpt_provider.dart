import 'dart:convert';
// ignore: implementation_imports
import 'package:chat_gpt_sdk/src/model/complete_text/response/usage.dart';
import 'package:chatgpt_windows_flutter_app/common/cost_calculator.dart';
import 'package:chatgpt_windows_flutter_app/gpt_tools.dart';
import 'package:chatgpt_windows_flutter_app/log.dart';

import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:chatgpt_windows_flutter_app/common/chat_room.dart';
import 'package:chatgpt_windows_flutter_app/common/prefs/app_cache.dart';
import 'package:chatgpt_windows_flutter_app/file_utils.dart';
import 'package:chatgpt_windows_flutter_app/main.dart';
import 'package:chatgpt_windows_flutter_app/navigation_provider.dart';
import 'package:chatgpt_windows_flutter_app/shell_driver.dart';
import 'package:chatgpt_windows_flutter_app/system_messages.dart';
import 'package:chatgpt_windows_flutter_app/tray.dart';
import 'package:chatgpt_windows_flutter_app/widgets/input_field.dart';
import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tiktoken/tiktoken.dart';

BehaviorSubject<Map<String, ChatRoom>> chatRoomsStream =
    BehaviorSubject.seeded({});
Map<String, ChatRoom> get chatRooms => chatRoomsStream.value;

BehaviorSubject<String> selectedChatRoomNameStream =
    BehaviorSubject.seeded('Default');
String get selectedChatRoomName => selectedChatRoomNameStream.value;
set selectedChatRoomName(String v) => selectedChatRoomNameStream.add(v);

ChatModel get selectedModel =>
    chatRooms[selectedChatRoomName]?.model ?? allModels.first;
ChatRoom get selectedChatRoom =>
    chatRooms[selectedChatRoomName] ??
    (chatRooms.values.isEmpty == true
        ? _generateDefaultChatroom()
        : chatRooms.values.first);
double get temp => chatRooms[selectedChatRoomName]?.temp ?? 0.9;
get topk => chatRooms[selectedChatRoomName]?.topk ?? 40;
get promptBatchSize => chatRooms[selectedChatRoomName]?.promptBatchSize ?? 128;
get repeatPenaltyTokens =>
    chatRooms[selectedChatRoomName]?.repeatPenaltyTokens ?? 64;
get topP => chatRooms[selectedChatRoomName]?.topP ?? 0.4;
get maxLenght => chatRooms[selectedChatRoomName]?.maxTokenLength ?? 512;
get repeatPenalty => chatRooms[selectedChatRoomName]?.repeatPenalty ?? 1.18;

/// the key is (chatcmpl-9QZ8C6NhBc5MBrFCVQRZ2uNhAMAW2) the answer is message
Map<String, Map<String, String>> get messages =>
    chatRooms[selectedChatRoomName]?.messages ?? {};

class ChatGPTProvider with ChangeNotifier {
  final listItemsScrollController = ScrollController();
  final TextEditingController messageController = TextEditingController();

  bool selectionModeEnabled = false;
  bool includeConversationGlobal = true;

  var lastTimeAnswer = DateTime.now().toIso8601String();
  final dialogApiKeyController = TextEditingController();
  final selectedMessages = <String>{};
  bool isAnswering = false;
  CancelToken? cancelToken;

  /// It's not a good practice to use [context] directly in the provider...
  BuildContext? context;

  int _textSize = 14;

  bool useSecondRequestForNamingChats = true;
  set textSize(int v) {
    _textSize = v;
    notifyListeners();
  }

  int get textSize => _textSize;

  void saveToDisk() {
    var rooms = {};
    for (var chatRoom in chatRooms.entries) {
      var timeRaw = chatRoom.key;
      var chatRoomRaw = chatRoom.value.toJson();
      rooms[timeRaw] = chatRoomRaw;
    }
    final chatRoomsRaw = jsonEncode(rooms);
    AppCache.chatRooms.set(chatRoomsRaw);
    AppCache.selectedChatRoomName.set(selectedChatRoomName);
  }

  ChatGPTProvider() {
    var token = prefs?.getString('token') ?? 'empty';
    var orgID = prefs?.getString('orgID') ?? '';
    openAI.setOrgId(orgID);
    openAI.setToken(token);
    AppCache.chatRooms.value().then((chatRoomsinSP) {
      if (chatRoomsinSP != null && chatRoomsinSP.isNotEmpty) {
        final map = jsonDecode(chatRoomsinSP) as Map;
        for (var chatRoom in map.entries) {
          var timeRaw = chatRoom.key;
          var chatRoomRaw = chatRoom.value as Map<String, dynamic>;
          chatRooms[timeRaw] = ChatRoom.fromMap(chatRoomRaw);
        }
      }
      if (chatRooms.isEmpty) {
        chatRooms[selectedChatRoomName] = _generateDefaultChatroom();
      } else {
        // notify stream
        chatRoomsStream.add(chatRooms);
        selectedChatRoomName =
            prefs?.getString('selectedChatRoomName') ?? 'Default';
      }
      if (selectedChatRoom.token != 'empty') {
        openAI.setToken(selectedChatRoom.token);
        log('setOpenAIKeyForCurrentChatRoom: ${selectedChatRoom.securedToken}');
      }
      if (selectedChatRoom.orgID != '') {
        openAI.setOrgId(selectedChatRoom.orgID ?? '');
        log('setOpenAIGroupIDForCurrentChatRoom: ${selectedChatRoom.orgID}');
      }
    });

    listenTray();
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
          sendMessage(text, false, true);
        }
      } else if (command == 'custom') {
        sendMessage(text, false, true);
      } else if (command == 'grammar') {
        sendCheckGrammar(text.trim());
      } else if (command == 'explain') {
        sendMessage('Explain: "$text"', false, true);
      } else if (command == 'to_rus') {
        sendMessage('Translate to Rus: "$text"', false, true);
      } else if (command == 'to_eng') {
        sendMessage('Translate to English: "$text"', false, true);
      } else if (command == 'impove_writing') {
        sendMessage('Improve writing: "$text"', false, true);
      } else if (command == 'summarize_markdown_short') {
        sendMessage(
            'Summarize using markdown. Use short summary: "$text"', false);
      } else if (command == 'answer_with_tags') {
        HotShurtcutsWidget.showAnswerWithTagsDialog(context!, text);
      } else if (command == 'create_new_chat') {
        createNewChatRoom();
      } else if (command == 'reset_chat') {
        clearConversation();
      } else if (command == 'escape_cancel_select') {
        disableSelectionMode();
      } else {
        throw Exception('Unknown command: $command');
      }
    });
  }

  @Deprecated('Use [sendMessage] instead')
  void sendCheckGrammar(String text) {
    sendMessage(
      'Check spelling and grammar: "$text"',
      false,
    );
  }

  XFile? fileInput;
  void addFileToInput(XFile file) {
    fileInput = file;
    notifyListeners();
  }

  Future<void> sendMessage(
    String messageContent, [
    bool includeConversation = true,
    bool hidePrompt = false,
  ]) async {
    bool includeConversation0 = includeConversation;
    bool isFirstMessage = messages.isEmpty;
    if (includeConversationGlobal == false) {
      includeConversation0 = false;
    }
    final dateTime = DateTime.now().toIso8601String();
    final isImageAttached =
        fileInput != null && fileInput!.mimeType?.contains('image') == true;
    if (isImageAttached) {
      await sendImageMessage(fileInput!, messageContent);
      isAnswering = false;
      notifyRoomsStream();
      listItemsScrollController.animateTo(
        listItemsScrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
      return;
    } else if (!isImageAttached) {
      messages[dateTime] = {
        'role': 'user',
        'content': messageContent,
        'created': dateTime,
        'hidePrompt': hidePrompt.toString(),
        'commandMessage': hidePrompt.toString(),
      };
    }
    isAnswering = true;
    notifyListeners();

    late ChatCompleteText request;

    request = ChatCompleteText(
      messages: [
        if (selectedChatRoom.systemMessage != null)
          {'role': Role.system.name, 'content': selectedChatRoom.systemMessage},
        if (includeConversation0)
          for (var message in messages.entries)
            {
              'role': message.value['role'],
              'content': message.value['content'],
            },
        if (!includeConversation0)
          {
            'role': Role.user.name,
            'content': messageContent,
            'created': dateTime,
          },
      ],
      maxToken: maxLenght,
      model: selectedModel,
      temperature: temp,
      topP: topP,
      frequencyPenalty: repeatPenalty,
      presencePenalty: repeatPenalty,
      tools: [
        if (AppCache.gptToolSearchEnabled.value!) searchFilesFunction,
        if (AppCache.gptToolPythonEnabled.value!) writePythonCodeFunction,
      ],
    );
    final stream = openAI.onChatCompletionSSE(
      request: request,
      onCancel: (cancelData) {
        cancelToken = cancelData.cancelToken;
      },
    );
    lastTimeAnswer = DateTime.now().toIso8601String();

    Map<String, dynamic>? toolResponseJson;
    String? toolResponseArgsString;
    String responseMessage = '';
    stream.listen(
      (event) {
        if (event.choices?.isEmpty == true) {
          log('Received empty response');
          return;
        }
        responseMessage += event.choices!.last.message?.content ?? '';
        // log('Received response: ${event.toJson()}');
        final choice = event.choices!.last;
        if (choice.finishReason == 'tool_calls') {
          toolResponseJson?['function']['arguments'] = toolResponseArgsString;
          _onToolsResponseEnd(
            messageContent,
            toolResponseJson!,
            event,
          );
        }
        if (choice.finishReason == 'stop') {
          _onResponseEnd(
            isFirstMessage,
            messageContent,
            messages.values.last['content'] ?? ' ',
            event,
          );
        } else {
          if (choice.message!.toolCalls?.isNotEmpty == true) {
            final tools = choice.message!.toolCalls!;

            /// TODO: add more tools
            if (tools[0]['function']['name'] != null) {
              toolResponseJson = tools[0];
            }
            final appendedArgText =
                '${toolResponseArgsString ?? ''}${tools[0]['function']['arguments'] ?? ''}';
            toolResponseArgsString = appendedArgText;

            return;
          }
          addBotMessageToList(responseMessage, event.id);
        }
      },
      onError: (e, stack) {
        isAnswering = false;
        String message = 'unknown error';
        lastTimeAnswer = DateTime.now().toIso8601String();
        if (e is OpenAIServerError) {
          message = 'Server error: ${e.data?.message}. Code: ${e.code}';
        } else if (e is OpenAIAuthError) {
          message = 'Authentication error: ${e.data?.message}. Code: ${e.code}';
        } else if (e is OpenAIRateLimitError) {
          message = 'Rate limit error: ${e.data?.message}. Code: ${e.code}';
        } else if (e is RequestError) {
          message = 'Request error: ${e.data?.message}. Code: ${e.code}';
        } else if (e is Exception) {
          message = 'Exception: $e';
        }
        addBotErrorMessageToList('Error response: $message');
      },
      cancelOnError: true,
    );

    fileInput = null;
    notifyListeners();
    saveToDisk();
  }

  void addBotMessageToList(String appendedText, [String? id]) {
    messages[id ?? lastTimeAnswer] = {
      'role': Role.assistant.name,
      'content': appendedText,
      'created': DateTime.now().toIso8601String(),
    };
    chatRoomsStream.add(chatRooms);
  }

  void addBotErrorMessageToList(String appendedText, [String? id]) {
    messages[id ?? lastTimeAnswer] = {
      'role': Role.assistant.name,
      'content': appendedText,
      'created': DateTime.now().toIso8601String(),
      'error': 'true',
    };
    chatRoomsStream.add(chatRooms);
  }

  Future _onToolsResponseEnd(
    String userContent,
    Map<String, dynamic> assistantArgs,
    ChatResponseSSE assistantLastEmptyResponse,
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
      addBotMessageToList(result, assistantLastEmptyResponse.id);
    } else if (toolName == 'get_current_weather') {
      final location = toolArgs['location'];
      // final unit = toolArgs['unit'];
      final result = await ShellDriver.runShellCommand(
          'curl wttr.in/$location?format="%C+%t+%w+%h+%p"');
      addBotMessageToList(result, assistantLastEmptyResponse.id);
    } else if (toolName == 'write_python_code') {
      final code = toolArgs['code'];
      final responseMessage = toolArgs['responseMessage'];
      addBotMessageToList(
          '$code\n$responseMessage', assistantLastEmptyResponse.id);
    } else {
      addBotMessageToList(
          'Unknown tool: $toolName', assistantLastEmptyResponse.id);
    }
  }

  Future<void> _onResponseEnd(
    bool isFirstMessage,
    String userContent,
    String assistantContent,
    ChatResponseSSE response,
  ) async {
    isAnswering = false;
    lastTimeAnswer = DateTime.now().toIso8601String();

    calcUsageTokens(response.usage);
    notifyListeners();

    if (shellCommandRegex.hasMatch(assistantContent)) {
      final match = shellCommandRegex.firstMatch(assistantContent);
      final command = match?.group(1);
      if (command != null) {
        if (command.contains('del') == true) return;
        final result = await ShellDriver.runShellCommand(command);
        sendResultOfRunningShellCode(result);
      }
    } else if (pythonCommandRegex.hasMatch(assistantContent)) {
      final match = pythonCommandRegex.firstMatch(assistantContent);
      final command = match?.group(1);
      if (command != null) {
        final result = await ShellDriver.runPythonCode(command);
        sendResultOfRunningShellCode(result);
      }
    } else if (everythingSearchCommandRegex.hasMatch(assistantContent)) {
      // final match = everythingSearchCommandRegex.firstMatch(assistantContent);
      // final command = match?.group(1);
      // if (command != null) {
      //   if (command.contains('del') == true) return;
      //   final result = await ShellDriver.runShellSearchFileCommand(command);
      //   sendResultOfRunningShellCode(result);
      // }
    } else if (copyToCliboardRegex.hasMatch(assistantContent)) {
      final match = copyToCliboardRegex.firstMatch(assistantContent);
      final command = match?.group(1);
      if (command != null) {
        displayInfoBar(
          navigatorKey.currentContext!,
          builder: (context, close) => const InfoBar(
            title: Text('The result is copied to clipboard'),
            severity: InfoBarSeverity.info,
          ),
        );
        Clipboard.setData(ClipboardData(text: command));
      }
    }

    saveToDisk();
    if (isFirstMessage) {
      if (useSecondRequestForNamingChats) {
        _requestForTitleChat(userContent);
      } else {
        final lastMessage = messages.values.last['content'];
        if (lastMessage != null) {
          final title = lastMessage.split('\n').first;
          if (title.isNotEmpty) {
            final tilteWords = title.split(' ');
            final titleShort = tilteWords.length > 5
                ? tilteWords.sublist(0, 5).join(' ')
                : title;
            final chatRoom = chatRooms[selectedChatRoomName];
            chatRoom!.chatRoomName = titleShort;
            chatRooms[selectedChatRoomName] = chatRoom;
            notifyRoomsStream();
            saveToDisk();
          }
        }
      }
    }
  }

  _requestForTitleChat(String userMessage) async {
    final request = ChatCompleteText(
      messages: [
        {
          'role': Role.user.name,
          'content':
              'Name this chat: "$userMessage". Use VERY SHORT name using 3-5 words.',
        }
      ],
      maxToken: 100,
      model: GptTurboChatModel(),
    );
    final response = await openAI.onChatCompletion(request: request);
    if (response?.choices.last.message?.content != null &&
        response!.choices.last.message!.content.isNotEmpty) {
      final message =
          response.choices.last.message!.content.replaceAll('"', '');
      editChatRoom(
        selectedChatRoomName,
        selectedChatRoom.copyWith(chatRoomName: message),
        switchToForeground: true,
      );
    }
  }

  void clearChatMessages() {
    messages.clear();
    saveToDisk();
    notifyRoomsStream();
  }

  void notifyRoomsStream() {
    chatRoomsStream.add(chatRooms);
  }

  void selectNewModel(ChatModel model) {
    chatRooms[selectedChatRoomName]!.model = model;
    notifyListeners();
    saveToDisk();
  }

  void selectModelForChat(String chatRoomName, ChatModel model) {
    chatRooms[chatRoomName]!.model = model;
    calcUsageTokens(null);
    notifyRoomsStream();
    saveToDisk();
    if (model is LocalChatModel) {
      AppCache.llmUrl.set(model.url);
      resetOpenAiUrl(url: model.url, token: selectedChatRoom.token);
    } else {
      resetOpenAiUrl(token: selectedChatRoom.token);
    }
  }

  void createNewChatRoom() {
    NavigationProvider? navProvider;
    try {
      navProvider = Provider.of<NavigationProvider>(context!, listen: false);
    } catch (e) {}
    final chatRoomName = 'Chat ${chatRooms.length + 1}';
    chatRooms[chatRoomName] = ChatRoom(
      token: openAI.token,
      chatRoomName: chatRoomName,
      model: selectedModel,
      messages: {},
      temp: temp,
      topk: topk,
      promptBatchSize: promptBatchSize,
      repeatPenaltyTokens: repeatPenaltyTokens,
      topP: topP,
      maxTokenLength: maxLenght,
      repeatPenalty: repeatPenalty,
      systemMessage: defaultSystemMessage,
    );
    selectedChatRoomName = chatRoomName;
    if (navProvider != null) {
      navProvider.index = chatRooms.length - 1;
      navProvider.refreshNavItems();
    }
    notifyListeners();
    saveToDisk();
    notifyRoomsStream();
  }

  void setOpenAIKeyForCurrentChatRoom(String v) {
    final trimmed = v.trim();
    chatRooms[selectedChatRoomName]!.token = trimmed;
    openAI.setToken(trimmed);
    AppCache.token.set(trimmed);
    log('setOpenAIKeyForCurrentChatRoom: ${chatRooms[selectedChatRoomName]!.securedToken}');
    notifyListeners();
    saveToDisk();
  }

  void setOpenAIGroupIDForCurrentChatRoom(String v) {
    chatRooms[selectedChatRoomName]!.orgID = v;
    openAI.setOrgId(v);
    AppCache.orgID.set(v);
    notifyListeners();
    saveToDisk();
  }

  void deleteAllChatRooms() {
    chatRooms.clear();
    notifyListeners();
    notifyRoomsStream();
    saveToDisk();
  }

  void selectChatRoom(ChatRoom room) {
    selectedChatRoomName = room.chatRoomName;
    saveToDisk();
  }

  void deleteChatRoom(String chatRoomName) {
    chatRooms.remove(chatRoomName);
    // if last one - create a default one
    if (chatRooms.isEmpty) {
      chatRooms['Default'] = _generateDefaultChatroom();
      selectedChatRoomName = 'Default';
    }
    notifyListeners();
    saveToDisk();
  }

  /// Will remove all chat rooms with selected name
  void deleteChatRoomHard(String chatRoomName) {
    chatRooms.removeWhere((key, value) => value.chatRoomName == chatRoomName);
    notifyListeners();
    saveToDisk();
  }

  void editChatRoom(String oldChatRoomName, ChatRoom chatRoom,
      {switchToForeground = false}) {
    // if token is changed, update openAI
    if (chatRoom.token != chatRooms[oldChatRoomName]?.token) {
      openAI.setToken(chatRoom.token);
      log('setOpenAIKeyForCurrentChatRoom: ${chatRoom.securedToken}');
    }
    // if orgID is changed, update openAI
    if (chatRoom.orgID != chatRooms[oldChatRoomName]?.orgID) {
      openAI.setOrgId(chatRoom.orgID ?? '');
      log('setOpenAIGroupIDForCurrentChatRoom: ${chatRoom.orgID}');
    }
    chatRooms.remove(oldChatRoomName);
    chatRooms[chatRoom.chatRoomName] = chatRoom;
    if (switchToForeground) {
      selectedChatRoomName = chatRoom.chatRoomName;
    }
    notifyRoomsStream();
    saveToDisk();
  }

  void clearConversation() {
    messages.clear();
    calcUsageTokens(null);
    notifyRoomsStream();
    saveToDisk();
  }

  void sendResultOfRunningShellCode(String result) {
    lastTimeAnswer = DateTime.now().toIso8601String();
    messages[lastTimeAnswer] = ({
      'role': Role.assistant.name,
      'content':
          'Result: \n${result.trim().isEmpty ? 'Done. No output' : result}',
    });
    notifyRoomsStream();
    saveToDisk();
    // scroll to bottom
    listItemsScrollController.animateTo(
      listItemsScrollController.position.maxScrollExtent + 200,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  void deleteMessage(String id) {
    messages.remove(id);
    notifyRoomsStream();
    saveToDisk();
  }

  void enableSelectionMode() {
    selectionModeEnabled = true;
    selectedMessages.clear();
    notifyListeners();
  }

  void disableSelectionMode() {
    selectionModeEnabled = false;
    for (var message in messages.entries) {
      message.value['selected'] = 'false';
    }
    selectedMessages.clear();
    notifyListeners();
  }

  void deleteSelectedMessages() {
    final selectedMessagesInMainList = messages.entries.where((element) {
      return element.value['selected'] == 'true';
    }).toList();
    for (var message in selectedMessagesInMainList) {
      messages.remove(message.key);
      selectedMessages.remove(message.key);
    }
    disableSelectionMode();
    saveToDisk();
  }

  void toggleSelectMessage(String id) {
    if (messages[id]!['selected'] == 'true') {
      messages[id]!['selected'] = 'false';
      selectedMessages.remove(id);
      notifyListeners();
      return;
    }
    selectionModeEnabled = true;
    messages[id]!['selected'] = 'true';
    selectedMessages.add(id);
    notifyListeners();
  }

  void enableSelectMessage(String id) {
    selectionModeEnabled = true;
    messages[id]!['selected'] = 'true';
    selectedMessages.add(id);
    notifyListeners();
  }

  void disableSelectMessage(DateTime dateTime) {
    messages[dateTime.toIso8601String()]!['selected'] = 'false';
    selectedMessages.remove(dateTime.toIso8601String());
    notifyListeners();
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
    lastTimeAnswer = DateTime.now().toIso8601String();
    messages[lastTimeAnswer] = ({
      'role': Role.system.name,
      'content': message,
    });
    notifyRoomsStream();
    saveToDisk();
    scrollToEnd();
  }

  void setIncludeWholeConversation(bool v) {
    includeConversationGlobal = v;
    notifyListeners();
  }

  bool isSendingFile = false;

  Future<bool> sendFile(XFile file) async {
    bool isSuccess = false;
    isSendingFile = true;
    notifyListeners();
    try {
      final fileName = fileInput!.name;

      final uploadFile = UploadFile(
          file: FileInfo(fileInput!.path, fileName), purpose: 'assistants');
      final response = await OpenAI.instance.file.uploadFile(uploadFile);
      addMessageSystem('File uploaded: ${response.filename}');
      isSuccess = true;
    } catch (e) {
      log('Error while ending file: $e');
      isSuccess = false;
    } finally {
      isSendingFile = false;
      notifyListeners();
    }
    return isSuccess;
  }

  bool isRetrievingFiles = false;
  List<FileData> filesInOpenAi = [];
  Future retrieveFiles() async {
    if (isRetrievingFiles) return;
    if (openAI.token.trim().isEmpty) {
      return;
    }
    return;
    isRetrievingFiles = true;
    notifyListeners();
    try {
      final response = await OpenAI.instance.file.get();
      filesInOpenAi = response.data;
    } catch (e) {
      log('Error while retrieving files: $e');
    } finally {
      isRetrievingFiles = false;
      notifyListeners();
    }
  }

  Future<void> downloadOpenFile(FileData file) async {
    final info = await openAI.file.retrieveContent(file.id);
    if (info is String) {
      final dirPath =
          await FilePicker.platform.saveFile(allowedExtensions: ['*']);
      if (dirPath != null) {
        final newFile = await FileUtils.saveFile(dirPath, info);
        if (newFile != null) {
          addMessageSystem('File downloaded: ${file.filename}');
        }
      }
    }
  }

  Future<void> deleteFileFromOpenAi(FileData file) async {
    isRetrievingFiles = true;
    notifyListeners();
    try {
      await OpenAI.instance.file.delete(file.id);
      filesInOpenAi.removeWhere((element) => element.id == file.id);
      notifyListeners();
    } catch (e) {
      log('Error while deleting file: $e');
    } finally {
      isRetrievingFiles = false;
      notifyListeners();
    }
  }

  void removeFileFromInput() {
    fileInput = null;
    notifyListeners();
  }

  Future<void> sendImageMessage(XFile file,
      [String prompt = "What's in this image?"]) async {
    isSendingFile = true;

    var base64Image = await encodeImage(file);
    messages[lastTimeAnswer] = ({
      'role': 'user',
      if (prompt.isEmpty) 'hiddent_content': "What's in this image?",
      'content': prompt,
      'image': base64Image,
      'created': DateTime.now().toIso8601String(),
    });
    notifyListeners();
    Map<String, String> headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer ${selectedChatRoom.token}"
    };

    Map<String, dynamic> payload = {
      "model": GPT4OModel().model,
      "messages": [
        {
          "role": "user",
          "content": [
            {"type": "text", "text": prompt},
            {
              "type": "image_url",
              "image_url": {"url": "data:image/jpeg;base64,$base64Image"}
            }
          ]
        }
      ],
      "max_tokens": 300,
    };
    log('Sending image to chat/completions: $payload');

    final response = await http.post(
      Uri.parse("https://api.openai.com/v1/chat/completions"),
      headers: headers,
      body: jsonEncode(payload),
    );
    isSendingFile = false;
    fileInput = null;
    notifyListeners();
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final choices = data['choices'] as List?;
      if (choices != null && choices.isNotEmpty) {
        final message = choices.last['message'];
        final messageID = data['id'];

        if (message != null) {
          final content = message['content'];
          if (content != null) {
            addBotMessageToList(content, messageID);
          }
        }
      }
    } else {
      addMessageSystem('Error while sending image: ${response.body}');
    }
  }

  Future<void> scrollToEnd() async {
    await Future.delayed(const Duration(milliseconds: 100));
    await listItemsScrollController.animateTo(
      listItemsScrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  void editMessage(Map<String, String> message, String text) {
    message['content'] = text;
    notifyListeners();
    saveToDisk();
  }

  Future<void> regenerateMessage(Map<String, String> message) async {
    final content = message['content'];
    if (content != null) {
      await sendMessage(content, true);
    }
  }

  void calcUsageTokens(Usage? usage) {
    if (usage != null) {
      log('Usage: $usage');
      selectedChatRoom.tokens == usage.totalTokens;
      return;
    }
    selectedChatRoom.tokens = 0;
    selectedChatRoom.costUSD = 0;
    if (selectedModel is LocalChatModel) {
      return;
    }
    String modelName = selectedModel.model;
    if (selectedModel is GPT4OModel) {
      modelName = 'gpt-4-0125-preview';
    }
    final encoding = encodingForModel(modelName);
    final listTexts = messages.values.map((e) => e['content']).toList();
    final oneLine = listTexts.join('');
    final uint = encoding.encode(oneLine);
    selectedChatRoom.tokens = uint.length;
    selectedChatRoom.costUSD = CostCalculator.calculateCostPerToken(
      selectedChatRoom.tokens ?? 0,
      modelName,
    );
    AppCache.tokensUsedTotal.value = selectedChatRoom.tokens ?? 0;
    AppCache.costTotal.value = selectedChatRoom.costUSD ?? 0;
  }

  void mergeSelectedMessagesToAssistant() {
    final selected = messages.entries
        .where((element) {
          return element.value['selected'] == 'true';
        })
        .map((e) => e.key)
        .toList();
    String lastId = '';
    // merge selected messages to one
    final mergedContent = selected.map((e) {
      final message = messages[e];
      return message!['content'];
    }).join('\n');

    // remove selected messages from original list
    for (var id in selected) {
      final message = messages[id];
      if (message != null) {
        messages.remove(id);
        selectedMessages.remove(id);
        lastId = id;
      }
    }
    // add merged message to the list
    addBotMessageToList(mergedContent, lastId);
    selectionModeEnabled = false;
    notifyListeners();
  }

  toggleUseSecondRequestForNamingChats() {
    useSecondRequestForNamingChats = !useSecondRequestForNamingChats;
    notifyListeners();
  }

  void toggleHidePrompt(String id) {
    final message = messages[id];
    if (message != null) {
      message['hidePrompt'] =
          message['hidePrompt'] == 'true' ? 'false' : 'true';
    }
    chatRoomsStream.add(chatRooms);
  }
}

ChatRoom _generateDefaultChatroom() {
  return ChatRoom(
    chatRoomName: 'Default',
    model: selectedModel,
    messages: messages,
    temp: temp,
    topk: topk,
    promptBatchSize: promptBatchSize,
    repeatPenaltyTokens: repeatPenaltyTokens,
    topP: topP,
    maxTokenLength: maxLenght,
    repeatPenalty: repeatPenalty,
    token: openAI.token,
    orgID: openAI.orgId,
    systemMessage: defaultSystemMessage,
  );
}
