import 'dart:convert';
import 'dart:developer';

import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:chatgpt_windows_flutter_app/chat_room.dart';
import 'package:chatgpt_windows_flutter_app/file_utils.dart';
import 'package:chatgpt_windows_flutter_app/main.dart';
import 'package:chatgpt_windows_flutter_app/onedrive_utils.dart';
import 'package:chatgpt_windows_flutter_app/tray.dart';
import 'package:chatgpt_windows_flutter_app/widgets/input_field.dart';
import 'package:cross_file/cross_file.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

class ChatGPTProvider with ChangeNotifier {
  final listItemsScrollController = ScrollController();
  final TextEditingController messageController = TextEditingController();
  final OneDriveUtils oneDriveUtils = OneDriveUtils();

  Map<String, ChatRoom> chatRooms = {};
  String selectedChatRoomName = 'Default';

  bool selectionModeEnabled = false;
  bool includeConversationGlobal = true;

  ChatModel get selectedModel =>
      chatRooms[selectedChatRoomName]?.model ?? allModels.first;
  ChatRoom get selectedChatRoom =>
      chatRooms[selectedChatRoomName] ?? chatRooms.values.first;
  double get temp => chatRooms[selectedChatRoomName]?.temp ?? 0.9;
  get topk => chatRooms[selectedChatRoomName]?.topk ?? 40;
  get promptBatchSize =>
      chatRooms[selectedChatRoomName]?.promptBatchSize ?? 128;
  get repeatPenaltyTokens =>
      chatRooms[selectedChatRoomName]?.repeatPenaltyTokens ?? 64;
  get topP => chatRooms[selectedChatRoomName]?.topP ?? 0.4;
  get maxLenght => chatRooms[selectedChatRoomName]?.maxLength ?? 512;
  get repeatPenalty => chatRooms[selectedChatRoomName]?.repeatPenalty ?? 1.18;

  var lastTimeAnswer = DateTime.now().toIso8601String();
  int countWordsInAllMessages = 0;

  Map<String, Map<String, String>> get messages =>
      chatRooms[selectedChatRoomName]?.messages ?? {};

  final dialogApiKeyController = TextEditingController();
  final selectedMessages = <String>{};
  bool isAnswering = false;
  CancelToken? cancelToken;

  /// It's not a good practice to use [context] directly in the provider...
  BuildContext? context;

  void saveToDisk() {
    var rooms = {};
    for (var chatRoom in chatRooms.entries) {
      var timeRaw = chatRoom.key;
      var chatRoomRaw = chatRoom.value.toJson();
      rooms[timeRaw] = chatRoomRaw;
    }
    final chatRoomsRaw = jsonEncode(rooms);
    prefs?.setString('chatRooms', chatRoomsRaw);
    prefs?.setString('selectedChatRoomName', selectedChatRoomName);
  }

  ChatGPTProvider() {
    var token = prefs?.getString('token') ?? 'empty';
    var orgID = prefs?.getString('orgID') ?? '';
    openAI.setOrgId(orgID);
    openAI.setToken(token);
    final chatRoomsinSP = prefs?.getString('chatRooms');
    if (chatRoomsinSP != null) {
      final map = jsonDecode(chatRoomsinSP) as Map;
      for (var chatRoom in map.entries) {
        var timeRaw = chatRoom.key;
        var chatRoomRaw = chatRoom.value as Map<String, dynamic>;
        chatRooms[timeRaw] = ChatRoom.fromMap(chatRoomRaw);
      }
    }
    if (chatRooms.isEmpty) {
      chatRooms[selectedChatRoomName] = ChatRoom(
        chatRoomName: 'Default',
        model: selectedModel,
        messages: messages,
        temp: temp,
        topk: topk,
        promptBatchSize: promptBatchSize,
        repeatPenaltyTokens: repeatPenaltyTokens,
        topP: topP,
        maxLength: maxLenght,
        repeatPenalty: repeatPenalty,
        token: token,
        orgID: orgID,
      );
    } else {
      selectedChatRoomName =
          prefs?.getString('selectedChatRoomName') ?? 'Default';
    }
    if (selectedChatRoom.token != 'empty') {
      openAI.setToken(selectedChatRoom.token);
      log('setOpenAIKeyForCurrentChatRoom: ${selectedChatRoom.token}');
    }
    if (selectedChatRoom.orgID != '') {
      openAI.setOrgId(selectedChatRoom.orgID ?? '');
      log('setOpenAIGroupIDForCurrentChatRoom: ${selectedChatRoom.orgID}');
    }
    calcWordsInAllMessages();
    listenTray();
  }

  void listenTray() {
    trayButtonStream.listen((value) async {
      /// wait for the app to appear
      await Future.delayed(const Duration(milliseconds: 150));
      final clipboard = await Clipboard.getData(Clipboard.kTextPlain);
      if (value == 'paste') {
        if (clipboard?.text?.trim().isNotEmpty == true) {
          sendMessage(clipboard!.text!);
        }
      } else if (value == 'grammar') {
        sendCheckGrammar(clipboard!.text!.trim());
      } else if (value == 'explain') {
        sendMessage('Explain: "${clipboard?.text}"', false);
      } else if (value == 'to_rus') {
        sendMessage('Translate to Rus: "${clipboard?.text}"', false);
      } else if (value == 'to_eng') {
        sendMessage('Translate to English: "${clipboard?.text}"', false);
      } else if (value == 'answer_with_tags') {
        HotShurtcutsWidget.showAnswerWithTagsDialog(context!, clipboard!.text!);
      } else if (value == 'create_new_chat') {
        createNewChatRoom();
      } else if (value == 'reset_chat') {
        clearConversation();
      }
    });
  }

  void sendCheckGrammar(String text) {
    sendMessage(
      'Check spelling and grammar: "$text". '
      'If it contains issues, write a revised version at the very start of your message and then your short description.',
      false,
    );
  }

  void calcWordsInAllMessages() {
    countWordsInAllMessages = 0;
    for (var message in messages.entries) {
      countWordsInAllMessages += message.value['content']!.split(' ').length;
    }
  }

  final listSupportedImageFormats = [
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
    'webp',
    'tiff',
    'svg',
    'ico',
    'webp',
  ];
  Future sendImageInput(
    XFile file, {
    String textPrompt = "Whats in this image?",
  }) async {
    final fileExt = file.path.split('.').last;
    if (!listSupportedImageFormats.contains(fileExt)) {
      addMessageSystem('Unsupported file format: $fileExt');
      return;
    }
    final encodedImage = await encodeImage(file);
    final request = ChatCompleteText(
      messages: [
        {
          "role": Role.user.name,
          "content": [
            {"type": "text", "text": textPrompt},
            {
              "type": "image_url",
              "image_url": {"url": "data:image/$fileExt;base64,${encodedImage}"}
            }
          ]
        }
      ],
      maxToken: 200,
      model: Gpt4VisionPreviewChatModel(),
    );

    ChatCTResponse? response = await openAI.onChatCompletion(request: request);
    debugPrint("$response");
  }

  XFile? fileInput;
  void addFileToInput(XFile file) {
    fileInput = file;
    notifyListeners();
  }

  Future<void> sendMessage(
    String messageContent, [
    bool includeConversation = true,
  ]) async {
    bool includeConversation0 = includeConversation;
    if (includeConversationGlobal == false) {
      includeConversation0 = false;
    }
    final dateTime = DateTime.now().toIso8601String();
    final isImageAttached =
        fileInput != null && fileInput!.mimeType?.contains('image') == true;
    if (isImageAttached) {
      await sendImageMessage(fileInput!, messageContent);
      isAnswering = false;
      notifyListeners();
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
      };
    }
    isAnswering = true;
    notifyListeners();

    late ChatCompleteText request;
    if (isImageAttached) {
      final fileExt = fileInput!.path.split('.').last;
      if (!listSupportedImageFormats.contains(fileExt)) {
        await sendFile(fileInput!);
        request = ChatCompleteText(
          messages: [
            if (selectedChatRoom.commandPrefix != null)
              {
                'role': Role.system.name,
                'content': selectedChatRoom.commandPrefix
              },
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
              },
          ],
          maxToken: maxLenght,
          model: selectedModel,
          temperature: temp,
          topP: topP,
          frequencyPenalty: repeatPenalty,
          presencePenalty: repeatPenalty,
        );
      }
    } else {
      request = ChatCompleteText(
        messages: [
          if (selectedChatRoom.commandPrefix != null)
            {
              'role': Role.system.name,
              'content': selectedChatRoom.commandPrefix
            },
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
            },
        ],
        maxToken: maxLenght,
        model: selectedModel,
        temperature: temp,
        topP: topP,
        frequencyPenalty: repeatPenalty,
        presencePenalty: repeatPenalty,
      );
    }

    final stream = openAI.onChatCompletionSSE(
      request: request,
      onCancel: (cancelData) {
        cancelToken = cancelData.cancelToken;
      },
    );
    // we need to add a delay because iso will not be unique
    await Future.delayed(const Duration(milliseconds: 100));
    lastTimeAnswer = DateTime.now().toIso8601String();

    try {
      await for (final response in stream) {
        if (response.choices?.isNotEmpty == true) {
          if (response.choices!.last.finishReason == 'stop') {
            isAnswering = false;
            lastTimeAnswer = DateTime.now().toIso8601String();
          } else {
            final lastBotMessage = messages[lastTimeAnswer];
            final appendedText = lastBotMessage != null
                ? '${lastBotMessage['content']}${response.choices!.last.message?.content ?? ' '}'
                : response.choices!.last.message?.content ?? ' ';
            messages[lastTimeAnswer] = {
              'role': Role.assistant.name,
              'content': appendedText,
            };
          }
        } else {
          log('Retrieved response but no choices');
        }

        /// 0 when at the top
        final pixelsNow = listItemsScrollController.position.pixels;

        /// pixels at the very end of the list
        final maxScrollExtent =
            listItemsScrollController.position.maxScrollExtent;

        /// if we nearly at the bottom (+-100 px), scroll to the bottom always
        if (pixelsNow >= maxScrollExtent - 100) {
          listItemsScrollController.animateTo(
            listItemsScrollController.position.maxScrollExtent + 200,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOut,
          );
        }

        notifyListeners();
      }
    } catch (e) {
      isAnswering = false;
      if (e is OpenAIServerError) {
        lastTimeAnswer = DateTime.now().toIso8601String();
        messages[lastTimeAnswer] = {
          'role': Role.assistant.name,
          'content':
              'Error response: Code: ${e.code}. Message: ${e.data?.message}',
        };
      } else {
        lastTimeAnswer = DateTime.now().toIso8601String();
        messages[lastTimeAnswer] = {
          'role': Role.assistant.name,
          'content': 'Error response: $e',
        };
      }
    }
    fileInput = null;
    calcWordsInAllMessages();
    notifyListeners();
    saveToDisk();
  }

  Future sendMessageDontStream(
    String messageContent, [
    bool includeConversation = true,
  ]) async {
    bool includeConversation0 = includeConversation;
    if (includeConversationGlobal == false) {
      includeConversation0 = false;
    }
    messages[lastTimeAnswer] = ({
      'role': 'user',
      'content': messageContent,
    });
    isAnswering = true;
    notifyListeners();
    saveToDisk();
    final request = ChatCompleteText(
      messages: [
        if (selectedChatRoom.commandPrefix != null)
          {'role': Role.system.name, 'content': selectedChatRoom.commandPrefix},
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
          },
      ],
      maxToken: maxLenght,
      model: selectedModel,
      temperature: temp,
      topP: topP,
      frequencyPenalty: repeatPenalty,
      presencePenalty: repeatPenalty,
      stream: true,
    );

    try {
      final response = await openAI.onChatCompletion(
        request: request,
        onCancel: (cancelData) {
          cancelToken = cancelData.cancelToken;
        },
      );
      lastTimeAnswer = DateTime.now().toIso8601String();
      if (response != null) {
        if (response.choices.isNotEmpty) {
          messages[lastTimeAnswer] = {
            'role': Role.assistant.name,
            'content': response.choices.last.message?.content ?? '...',
          };
        } else {
          log('Retrieved response but no choices');
        }
      } else {
        messages[lastTimeAnswer] = {
          'role': Role.assistant.name,
          'content': 'Error: ${response ?? 'No response'}',
        };
      }
    } catch (e) {
      lastTimeAnswer = DateTime.now().toIso8601String();
      messages[lastTimeAnswer] = {
        'role': Role.assistant.name,
        'content': 'Error: $e',
      };
    }
    isAnswering = false;
    calcWordsInAllMessages();
    notifyListeners();
    saveToDisk();
  }

  void deleteChat() {
    messages.clear();
    saveToDisk();
    notifyListeners();
  }

  void selectNewModel(ChatModel model) {
    chatRooms[selectedChatRoomName]!.model = model;
    notifyListeners();
    saveToDisk();
  }

  void selectModelForChat(String chatRoomName, ChatModel model) {
    chatRooms[chatRoomName]!.model = model;
    notifyListeners();
    saveToDisk();
  }

  void createNewChatRoom() {
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
      maxLength: maxLenght,
      repeatPenalty: repeatPenalty,
    );
    selectedChatRoomName = chatRoomName;
    calcWordsInAllMessages();
    notifyListeners();
    saveToDisk();
  }

  void setOpenAIKeyForCurrentChatRoom(String v) {
    final trimmed = v.trim();
    chatRooms[selectedChatRoomName]!.token = trimmed;
    openAI.setToken(trimmed);
    prefs?.setString('token', trimmed);
    log('setOpenAIKeyForCurrentChatRoom: $trimmed');
    notifyListeners();
    saveToDisk();
  }

  void setOpenAIGroupIDForCurrentChatRoom(String v) {
    chatRooms[selectedChatRoomName]!.orgID = v;
    openAI.setOrgId(v);
    prefs?.setString('orgID', v);
    notifyListeners();
    saveToDisk();
  }

  void deleteAllChatRooms() {
    chatRooms.clear();
    notifyListeners();
    saveToDisk();
  }

  void selectChatRoom(ChatRoom room) {
    selectedChatRoomName = room.chatRoomName;
    notifyListeners();
    saveToDisk();
  }

  void deleteChatRoom(String chatRoomName) {
    chatRooms.remove(chatRoomName);
    notifyListeners();
    saveToDisk();
  }

  void editChatRoom(String oldChatRoomName, ChatRoom chatRoom,
      {switchToForeground = false}) {
    // if token is changed, update openAI
    if (chatRoom.token != chatRooms[oldChatRoomName]?.token) {
      openAI.setToken(chatRoom.token);
      log('setOpenAIKeyForCurrentChatRoom: ${chatRoom.token}');
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
    calcWordsInAllMessages();
    notifyListeners();
    saveToDisk();
  }

  void clearConversation() {
    messages.clear();
    calcWordsInAllMessages();
    notifyListeners();
    saveToDisk();
  }

  void sendResultOfRunningShellCode(String result) {
    lastTimeAnswer = DateTime.now().toIso8601String();
    messages[lastTimeAnswer] = ({
      'role': 'system',
      'content': 'Result: \n\n$result',
    });
    calcWordsInAllMessages();
    notifyListeners();
    saveToDisk();
    // scroll to bottom
    listItemsScrollController.animateTo(
      listItemsScrollController.position.maxScrollExtent + 200,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
    );
  }

  void deleteMessage(DateTime dateTime) {
    messages.remove(dateTime.toIso8601String());
    calcWordsInAllMessages();
    notifyListeners();
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
    calcWordsInAllMessages();
    disableSelectionMode();
    saveToDisk();
  }

  void toggleSelectMessage(DateTime dateTime) {
    if (messages[dateTime.toIso8601String()]!['selected'] == 'true') {
      messages[dateTime.toIso8601String()]!['selected'] = 'false';
      selectedMessages.remove(dateTime.toIso8601String());
      notifyListeners();
      return;
    }
    selectionModeEnabled = true;
    messages[dateTime.toIso8601String()]!['selected'] = 'true';
    selectedMessages.add(dateTime.toIso8601String());
    notifyListeners();
  }

  void enableSelectMessage(DateTime dateTime) {
    selectionModeEnabled = true;
    messages[dateTime.toIso8601String()]!['selected'] = 'true';
    selectedMessages.add(dateTime.toIso8601String());
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
    calcWordsInAllMessages();
    notifyListeners();
    saveToDisk();
    scrollToEnd();
  }

  void addMessageAssistant(String message) {
    lastTimeAnswer = DateTime.now().toIso8601String();
    messages[lastTimeAnswer] = ({
      'role': Role.assistant.name,
      'content': message,
    });
    calcWordsInAllMessages();
    notifyListeners();
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
      final result = await OpenAI.instance.file.delete(file.id);
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

  Future<String?> _uploadFileOneDrive(XFile xFile) async {
    final res = await oneDriveUtils.uploadFile(xFile, context!);
  }

  Future<void> sendImageMessage(XFile file,
      [String prompt = "What's in this image?"]) async {
    isSendingFile = true;
    var base64Image = await encodeImage(file);
    messages[lastTimeAnswer] = ({
      'role': 'user',
      'content': prompt,
      'image': base64Image,
    });
    notifyListeners();
    Map<String, String> headers = {
      "Content-Type": "application/json",
      "Authorization": "Bearer ${selectedChatRoom.token}"
    };

    Map<String, dynamic> payload = {
      "model": "gpt-4-vision-preview",
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
        if (message != null) {
          final content = message['content'];
          if (content != null) {
            addMessageAssistant(content);
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
}
