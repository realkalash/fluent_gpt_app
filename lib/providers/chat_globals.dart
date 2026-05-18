import 'package:collection/collection.dart';
import 'package:fluent_gpt/common/chat_model.dart';
import 'package:fluent_gpt/common/chat_room.dart';
import 'package:fluent_gpt/common/conversaton_style_enum.dart';
import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/common/on_message_actions/on_message_action.dart';
import 'package:fluent_gpt/providers/chat_utils.dart';
import 'package:flutter/foundation.dart';
import 'package:langchain_openai/langchain_openai.dart';
import 'package:rxdart/subjects.dart';

ChatOpenAI? openAI;

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

double? get temp => chatRooms[selectedChatRoomId]?.temp;
int? get topk => chatRooms[selectedChatRoomId]?.topk;
int? get promptBatchSize =>
    chatRooms[selectedChatRoomId]?.promptBatchSize;
double? get topP => chatRooms[selectedChatRoomId]?.topP;
int get maxTokenLenght => chatRooms[selectedChatRoomId]?.maxTokenLength ?? 4096;
double? get repeatPenalty =>
    chatRooms[selectedChatRoomId]?.repeatPenalty;

/// the key is id or DateTime.now() (chatcmpl-9QZ8C6NhBc5MBrFCVQRZ2uNhAMAW2)  the answer is message
BehaviorSubject<Map<String, FluentChatMessage>> messages =
    BehaviorSubject.seeded({});

/// Per-message notifiers. Each [MessageCard] subscribes to its own notifier so
/// that token-streaming updates only rebuild the actively-streaming tile
/// (instead of triggering a full ListView rebuild via `messages.add`).
///
/// Lifecycle is managed exclusively by the helpers below
/// (`ensureMessageNotifier` / `notifyMessageContent` / `disposeMessageNotifier` /
/// `disposeAllMessageNotifiers`). The map is kept structurally in sync with
/// `messages.value`: every id present in `messages.value` has a notifier here.
final Map<String, MessageNotifier> messageNotifiers = {};

/// A ValueListenable for a single [FluentChatMessage] that dedupes via
/// `identical` rather than `==`. `FluentChatMessage.==` compares only by id,
/// so plain `ValueNotifier` would drop every content-update fired with the
/// same id — silently breaking token-streaming UI.
class MessageNotifier extends ChangeNotifier
    implements ValueListenable<FluentChatMessage> {
  MessageNotifier(this._value);
  FluentChatMessage _value;

  @override
  FluentChatMessage get value => _value;

  set value(FluentChatMessage newValue) {
    if (identical(_value, newValue)) return;
    _value = newValue;
    notifyListeners();
  }
}

/// Get-or-create the notifier for a message id, seeded with [message].
/// Returns the existing notifier if present (does NOT update its value —
/// the caller is responsible for `notifier.value = newMsg` when needed).
MessageNotifier ensureMessageNotifier(
  String id,
  FluentChatMessage message,
) {
  final existing = messageNotifiers[id];
  if (existing != null) return existing;
  final notifier = MessageNotifier(message);
  messageNotifiers[id] = notifier;
  return notifier;
}

/// Pushes the updated message to its per-message notifier. Only the subscribed
/// tile rebuilds — does NOT touch the `messages` BehaviorSubject.
/// Also syncs the corresponding entry in [messagesReversedList] so content
/// readers don't drift while the stream is in flight.
void notifyMessageContent(String id, FluentChatMessage updated) {
  final notifier = messageNotifiers[id];
  if (notifier != null) notifier.value = updated;
  final idx = messagesReversedList.indexWhere((m) => m.id == id);
  if (idx != -1) messagesReversedList[idx] = updated;
}

/// Disposes the notifier for [id]. Safe to call if the id is unknown.
void disposeMessageNotifier(String id) {
  messageNotifiers.remove(id)?.dispose();
}

/// Disposes every notifier — for chat switch / new chat / clear paths.
void disposeAllMessageNotifiers() {
  for (final n in messageNotifiers.values) {
    n.dispose();
  }
  messageNotifiers.clear();
}

/// This list is only for the UI part. It's reversed to show the messages from the bottom and we have separate list for keys to optimize memory usage
List<FluentChatMessage> messagesReversedList = [];

/// conversation lenght style. Will be appended to the prompt
BehaviorSubject<ConversationLengthStyleEnum> conversationLenghtStyleStream =
    BehaviorSubject.seeded(ConversationLengthStyleEnum.normal);

/// conversation style. Will be appended to the prompt
BehaviorSubject<ConversationStyleEnum> conversationStyleStream =
    BehaviorSubject.seeded(ConversationStyleEnum.normal);

final allModels = BehaviorSubject<List<ChatModelAi>>.seeded([]);
