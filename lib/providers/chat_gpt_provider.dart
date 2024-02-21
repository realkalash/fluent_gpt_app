import 'dart:convert';
import 'dart:developer';

import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:chatgpt_windows_flutter_app/chat_room.dart';
import 'package:chatgpt_windows_flutter_app/file_utils.dart';
import 'package:chatgpt_windows_flutter_app/main.dart';
import 'package:chatgpt_windows_flutter_app/tray.dart';
import 'package:chatgpt_windows_flutter_app/widgets/input_field.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

class ChatGPTProvider with ChangeNotifier {
  final listItemsScrollController = ScrollController();
  final TextEditingController messageController = TextEditingController();

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
    String path, {
    String textPrompt = "Whats in this image?",
  }) async {
    final fileExt = path.split('.').last;
    if (!listSupportedImageFormats.contains(fileExt)) {
      addMessageSystem('Unsupported file format: $fileExt');
      return;
    }
    final encodedImage = await encodeImage(path);
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

  String? pathFileInput;
  void addFileToInput(String path) {
    pathFileInput = path;
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
    messages[dateTime] = {
      'role': 'user',
      'content': messageContent,
    };
    isAnswering = true;
    notifyListeners();

    late ChatCompleteText request;
    if (pathFileInput != null) {
      final fileExt = pathFileInput!.split('.').last;
      if (listSupportedImageFormats.contains(fileExt)) {
        final encodedImage = await encodeImage(pathFileInput!);
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
            {
              "type": "image_url",
              "image_url": {"url": "data:image/$fileExt;base64,$encodedImage"}
            }
          ],
          maxToken: 300,
          model: Gpt4VisionPreviewChatModel(),
          temperature: temp,
          topP: topP,
          frequencyPenalty: repeatPenalty,
          presencePenalty: repeatPenalty,
        );
      } else if (!listSupportedImageFormats.contains(fileExt)) {
        await sendFile(pathFileInput!);
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
    pathFileInput = null;
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
  }

  void setIncludeWholeConversation(bool v) {
    includeConversationGlobal = v;
    notifyListeners();
  }

  bool isSendingFile = false;

  Future<bool> sendFile(String path) async {
    bool isSuccess = false;
    isSendingFile = true;
    notifyListeners();
    try {
      final fileName =
          path.contains('\\') ? path.split('\\').last : path.split('/').last;
      final uploadFile =
          UploadFile(file: FileInfo(path, fileName), purpose: 'assistants');
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
    final PlatformFile platformFile = PlatformFile(
      name: file.filename,
      size: info.length,
      bytes: info,
    );

    /// TODO: add save
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
    pathFileInput = null;
    notifyListeners();
  }
}
