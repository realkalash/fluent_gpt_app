import 'package:collection/collection.dart';
import 'package:fluent_gpt/common/chat_model.dart';
import 'package:fluent_gpt/common/chat_room.dart';
import 'package:fluent_gpt/common/conversaton_style_enum.dart';
import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/common/on_message_actions/on_message_action.dart';
import 'package:fluent_gpt/providers/chat_utils.dart';
import 'package:langchain_openai/langchain_openai.dart';
import 'package:rxdart/subjects.dart';

ChatOpenAI? openAI;
ChatOpenAI? localModel;

/// First is ID, second is ChatRoom
BehaviorSubject<Map<String, ChatRoom>> chatRoomsStream =
    BehaviorSubject.seeded({});
BehaviorSubject<List<OnMessageAction>> onMessageActions =
    BehaviorSubject.seeded([]);

/// Indexes from original [messages] list where 0 is the oldest one and 999 is the newest
List<int> pinnedMessagesIndexes = [];

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
    return generateDefaultChatroom();
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

final allModels = BehaviorSubject<List<ChatModelAi>>.seeded([]);
