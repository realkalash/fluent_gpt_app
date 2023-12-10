import 'dart:convert';
import 'dart:developer';

import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:chatgpt_windows_flutter_app/chat_room.dart';
import 'package:chatgpt_windows_flutter_app/main.dart';
import 'package:fluent_ui/fluent_ui.dart';

class ChatGPTProvider with ChangeNotifier {
  final listItemsScrollController = ScrollController();

  Map<String, ChatRoom> chatRooms = {};
  String selectedChatRoomName = 'Default';

  bool selectionModeEnabled = false;

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

  Map<String, Map<String, String>> get messages =>
      chatRooms[selectedChatRoomName]?.messages ?? {};

  final dialogApiKeyController = TextEditingController();
  final selectedMessages = <String>{};

  void saveToDisk() {
    var rooms = {};
    for (var chatRoom in chatRooms.entries) {
      var timeRaw = chatRoom.key;
      var chatRoomRaw = chatRoom.value.toJson();
      rooms[timeRaw] = chatRoomRaw;
    }
    final chatRoomsRaw = jsonEncode(rooms);
    prefs?.setString('chatRooms', chatRoomsRaw);
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
    }
    if (selectedChatRoom.token != 'empty') {
      openAI.setToken(selectedChatRoom.token);
      log('setOpenAIKeyForCurrentChatRoom: ${selectedChatRoom.token}');
    }
    if (selectedChatRoom.orgID != '') {
      openAI.setOrgId(selectedChatRoom.orgID ?? '');
      log('setOpenAIGroupIDForCurrentChatRoom: ${selectedChatRoom.orgID}');
    }
  }

  Future<void> sendMessage(String messageContent) async {
    final dateTime = DateTime.now().toIso8601String();
    messages[dateTime] = {
      'role': 'user',
      'content': messageContent,
    };
    notifyListeners();

    final request = ChatCompleteText(
      messages: [
        if (selectedChatRoom.commandPrefix != null)
          Messages(role: Role.system, content: selectedChatRoom.commandPrefix),

        /// We already added the user message in the previous iteration
        for (var message in messages.entries)
          Messages(
            role: message.value['role'] == 'user' ? Role.user : Role.assistant,
            content: message.value['content'],
          ),
      ],
      maxToken: maxLenght,
      model: selectedModel,
      temperature: temp,
      topP: topP,
      frequencyPenalty: repeatPenalty,
      presencePenalty: repeatPenalty,
    );

    final stream = openAI.onChatCompletionSSE(request: request);
    // we need to add a delay because iso will not be unique
    await Future.delayed(const Duration(milliseconds: 100));
    lastTimeAnswer = DateTime.now().toIso8601String();

    await for (final response in stream) {
      if (response.choices?.isNotEmpty == true) {
        if (response.choices!.last.finishReason == 'stop') {
          lastTimeAnswer = DateTime.now().toIso8601String();
        } else {
          final lastBotMessage = messages[lastTimeAnswer];
          final appendedText = lastBotMessage != null
              ? '${lastBotMessage['content']}${response.choices!.last.message?.content ?? ' '}'
              : response.choices!.last.message?.content ?? ' ';
          messages[lastTimeAnswer] = {
            'role': 'bot',
            'content': appendedText,
          };
        }
      } else {
        log('Retrieved response but no choices');
      }
      listItemsScrollController.animateTo(
        listItemsScrollController.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );

      notifyListeners();
    }

    notifyListeners();
    saveToDisk();
  }

  Future sendMessageDontStream(String messageContent) async {
    messages[lastTimeAnswer] = ({
      'role': 'user',
      'content': messageContent,
    });
    notifyListeners();
    saveToDisk();
    final request = ChatCompleteText(
      messages: [
        // if (selectedChatRoom.commandPrefix != null)
        //   Messages(role: Role.system, content: selectedChatRoom.commandPrefix),
        // Messages(role: Role.user, content: messageContent),
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
      final response = await openAI.onChatCompletion(request: request);
      lastTimeAnswer = DateTime.now().toIso8601String();
      if (response != null) {
        if (response.choices.isNotEmpty) {
          messages[lastTimeAnswer] = {
            'role': 'bot',
            'content': response.choices.last.message?.content ?? '...',
          };
        } else {
          log('Retrieved response but no choices');
        }
      } else {
        messages[lastTimeAnswer] = {
          'role': 'bot',
          'content': 'Error: ${response ?? 'No response'}',
        };
      }
    } catch (e) {
      lastTimeAnswer = DateTime.now().toIso8601String();
      messages[lastTimeAnswer] = {
        'role': 'bot',
        'content': 'Error: $e',
      };
    }

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

  void editChatRoom(String oldChatRoomName, ChatRoom chatRoom) {
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
    notifyListeners();
    saveToDisk();
  }

  void clearConversation() {
    messages.clear();
    notifyListeners();
    saveToDisk();
  }

  void sendResultOfRunningShellCode(String result) {
    lastTimeAnswer = DateTime.now().toIso8601String();
    messages[lastTimeAnswer] = ({
      'role': 'system',
      'content': 'Result: \n\n$result',
    });
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
}
