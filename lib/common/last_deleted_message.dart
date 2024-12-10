import 'custom_messages/fluent_chat_message.dart';

class LastDeletedMessage {
  final FluentChatMessage message;
  final String messageChatRoomId;

  const LastDeletedMessage({
    required this.message,
    required this.messageChatRoomId,
  });

  LastDeletedMessage copyWith({
    FluentChatMessage? message,
    String? messageChatRoomId,
  }) {
    return LastDeletedMessage(
      message: message ?? this.message,
      messageChatRoomId: messageChatRoomId ?? this.messageChatRoomId,
    );
  }
}
