import 'package:fluent_gpt/common/chat_room.dart';
import 'package:fluent_gpt/common/conversaton_style_enum.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/utils.dart';

String modifyMessageStyle(String prompt) {
  if (conversationLenghtStyleStream.value !=
      ConversationLengthStyleEnum.normal) {
    prompt += ' ${conversationLenghtStyleStream.value.prompt}';
  }

  if (conversationStyleStream.value != ConversationStyleEnum.normal) {
    prompt += ' ${conversationStyleStream.value.prompt}';
  }
  return prompt;
}

ChatRoom generateDefaultChatroom({String? systemMessage}) {
  return ChatRoom(
    id: generateChatID(),
    chatRoomName: 'Default',
    model: selectedModel,
    temp: temp,
    topk: topk,
    promptBatchSize: promptBatchSize,
    topP: topP,
    systemMessageTokensCount: 0,
    totalReceivedTokens: 0,
    totalSentTokens: 0,
    maxTokenLength: maxTokenLenght,
    repeatPenalty: repeatPenalty,
    systemMessage: '',
    dateCreatedMilliseconds: DateTime.now().millisecondsSinceEpoch,
  );
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

List<ChatRoom> getChatRoomsRecursive(List<ChatRoom> chatRooms) {
  final folders = <ChatRoom>[];
  for (var chatRoom in chatRooms) {
    folders.add(chatRoom);
    if (chatRoom.children != null) {
      folders.addAll(getChatRoomsRecursive(chatRoom.children!));
    }
  }
  return folders;
}

void notifyRoomsStream() {
  final sortedChatRooms = chatRoomsStream.value.values.toList()
    ..sort((a, b) {
      if (a.indexSort == b.indexSort) {
        return b.dateModifiedMilliseconds.compareTo(a.dateModifiedMilliseconds);
      }
      return a.indexSort.compareTo(b.indexSort);
    });

  _sortChatRoomChildren(sortedChatRooms);

  chatRoomsStream.add(
    {
      for (var e in sortedChatRooms) (e).id: e,
    },
  );
}

void _sortChatRoomChildren(List<ChatRoom> chatRooms) {
  for (var chatRoom in chatRooms) {
    if (chatRoom.isFolder && chatRoom.children != null) {
      chatRoom.children!.sort((a, b) {
        if (a.indexSort == b.indexSort) {
          return b.dateModifiedMilliseconds
              .compareTo(a.dateModifiedMilliseconds);
        }
        return a.indexSort.compareTo(b.indexSort);
      });
      _sortChatRoomChildren(chatRoom.children!);
    }
  }
}
