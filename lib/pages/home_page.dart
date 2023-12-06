import 'dart:convert';
import 'dart:developer';

// import 'package:chat_gpt_flutter/chat_gpt_flutter.dart';
import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:chatgpt_windows_flutter_app/chat_room.dart';
import 'package:chatgpt_windows_flutter_app/main.dart';
import 'package:chatgpt_windows_flutter_app/theme.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

final promptTextFocusNode = FocusNode();

class ChatRoomPage extends StatelessWidget {
  const ChatRoomPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: const PageHeaderText(),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              onPressed: () {
                var chatProvider = context.read<ChatGPTProvider>();
                chatProvider.sendMessageDontStream('Hello');
              },
              icon: const Icon(FluentIcons.device_bug),
              label: const Text('Send Hello message'),
            ),
          ],
          secondaryItems: [
            CommandBarButton(
              onPressed: () {
                var chatProvider = context.read<ChatGPTProvider>();
                chatProvider.clearConversation();
                Navigator.of(context).maybePop();
              },
              icon: const Icon(FluentIcons.clear),
              label: const Text('Clear conversation'),
            ),
            CommandBarButton(
              onPressed: () {
                var chatProvider = context.read<ChatGPTProvider>();
                chatProvider.deleteChat();
                Navigator.of(context).maybePop();
              },
              icon: const Icon(FluentIcons.delete),
              label: const Text('Delete chat'),
            ),
          ],
        ),
      ),
      content: const ChatGPTContent(),
    );
  }
}

class PageHeaderText extends StatelessWidget {
  const PageHeaderText({super.key});

  @override
  Widget build(BuildContext context) {
    var chatProvider = context.watch<ChatGPTProvider>();
    final model = chatProvider.selectedModel.model;
    final selectedRoom = chatProvider.selectedChatRoomName;
    return Text('Chat GPT ($model) ($selectedRoom)');
  }
}

class ChatGPTContent extends StatefulWidget {
  const ChatGPTContent({super.key});

  @override
  State<ChatGPTContent> createState() => _ChatGPTContentState();
}

class _ChatGPTContentState extends State<ChatGPTContent> {
  final TextEditingController _messageController = TextEditingController();

  @override
  void initState() {
    super.initState();
    promptTextFocusNode.requestFocus();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      var chatProvider = context.read<ChatGPTProvider>();
      chatProvider.listItemsScrollController.animateTo(
        chatProvider.listItemsScrollController.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    var chatProvider = context.watch<ChatGPTProvider>();
    final appTheme = context.read<AppTheme>();

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView.builder(
            controller: chatProvider.listItemsScrollController,
            itemCount: chatProvider.messages.entries.length,
            itemBuilder: (context, index) {
              final message =
                  chatProvider.messages.entries.elementAt(index).value;
              final dateTimeRaw =
                  chatProvider.messages.entries.elementAt(index).key;
              final DateTime dateTime = DateTime.parse(dateTimeRaw);
              final formatDateTime = DateFormat('HH:mm:ss').format(dateTime);
              if (message['role'] == 'user') {
                return Card(
                  margin: const EdgeInsets.all(4),
                  padding: const EdgeInsets.all(0.0),
                  borderRadius: BorderRadius.circular(8.0),
                  child: ListTile(
                    trailing: Text(formatDateTime,
                        style: FluentTheme.of(context).typography.caption!),
                    title: Text(
                      'You:',
                      style: TextStyle(color: appTheme.color, fontSize: 14),
                    ),
                    subtitle: SelectableText('${message['content']}',
                        style: FluentTheme.of(context).typography.body),
                  ),
                );
              }
              return Card(
                margin: const EdgeInsets.all(4),
                padding: EdgeInsets.zero,
                borderRadius: BorderRadius.circular(8.0),
                child: ListTile(
                  trailing: Text(formatDateTime,
                      style: FluentTheme.of(context).typography.caption!),
                  title: Text(
                    '${message['role']}:',
                    style: TextStyle(color: Colors.green, fontSize: 14),
                  ),
                  subtitle: SelectableText('${message['content']}',
                      style: FluentTheme.of(context).typography.body),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextBox(
                  focusNode: promptTextFocusNode,
                  prefix: (chatProvider.selectedChatRoom.commandPrefix ==
                              null ||
                          chatProvider.selectedChatRoom.commandPrefix == '')
                      ? null
                      : Tooltip(
                          message: chatProvider.selectedChatRoom.commandPrefix,
                          child: const Card(
                              margin: EdgeInsets.all(4),
                              padding: EdgeInsets.all(4),
                              child: Text('SMART')),
                        ),
                  prefixMode: OverlayVisibilityMode.always,
                  controller: _messageController,
                  placeholder: 'Type your message here',
                  onSubmitted: (text) {
                    chatProvider.sendMessage(text);
                    _messageController.clear();
                    promptTextFocusNode.requestFocus();
                  },
                ),
              ),
              const SizedBox(width: 8.0),
              Button(
                onPressed: () {
                  chatProvider.sendMessage(_messageController.text);
                  _messageController.clear();
                  promptTextFocusNode.requestFocus();
                },
                child: const Text('Send'),
              ),
            ],
          ),
        )
      ],
    );
  }
}

class ChatGPTProvider with ChangeNotifier {
  final listItemsScrollController = ScrollController();

  // var token = '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';
  // var orgID = 'org-OUCND1IFsUA8u2kkqgk6kJqG';

  Map<String, ChatRoom> chatRooms = {};
  String selectedChatRoomName = 'Default';
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
              : response.choices!.last.message?.content ?? '';
          messages[lastTimeAnswer] = {
            'role': 'bot',
            'content': appendedText.trim(),
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
}
