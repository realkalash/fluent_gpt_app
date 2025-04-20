import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:fluent_gpt/common/chat_room.dart';
import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/providers/chat_utils.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_ui/fluent_ui.dart';

mixin ChatProviderFoldersMixin on ChangeNotifier {
  Future<void> createNewBranchFromLastMessage(String id) async {
    final listNewMessages = <String, FluentChatMessage>{};
    for (var message in messages.value.entries) {
      // All messages are sorted. So if we face the message with the same id, we add it and stop
      if (message.key == id) {
        listNewMessages[message.key] = message.value;
        break;
      }
      listNewMessages[message.key] = message.value;
    }
    // create new chat room with new messages
    final chatRoomName = '${selectedChatRoom.chatRoomName}*';
    final newChatId = generateChatID();
    final newChatRoom = selectedChatRoom.copyWith(
      id: newChatId,
      chatRoomName: chatRoomName,
      dateCreatedMilliseconds: DateTime.now().millisecondsSinceEpoch,
    );
    final chatRooms = chatRoomsStream.value;
    chatRooms[newChatId] = newChatRoom;
    chatRoomsStream.add(chatRooms);
    selectedChatRoomId = newChatId;
    messages.add(listNewMessages);
    notifyRoomsStream();
    saveToDisk([newChatRoom]);
  }

  Future loadMessagesFromDisk(String id) async {
    final roomId = id;
    final fileContent = await FileUtils.getChatRoomMessagesFileById(roomId);
    final fileContentString = await fileContent.readAsString();

    final chatRoomRaw = jsonDecode(fileContentString) as List<dynamic>;
    // id is the key
    final roomMessages = <String, FluentChatMessage>{};
    for (var messageJson in chatRoomRaw) {
      try {
        final id = messageJson['id'] as String;
        final timestamp = messageJson['timestamp'] as int?;
        // if is not containing 'timestamp' break the loop and ask to upgrade
        if (timestamp == null) {
          onTrayButtonTapCommand(
              'You use deprecated chat format. Please go to the settings page->Application storage location->Import old chats in deprecated format',
              TrayCommand.show_dialog.name);
          break;
        }
        roomMessages[id] = FluentChatMessage.fromJson(messageJson);
      } catch (e) {
        logError('Error while loading message from disk: $e');
      }
    }

    messages.add(roomMessages);
    notifyListeners();
  }

  void moveChatRoomToParentFolder(ChatRoom chatRoom) {
    final chatRooms =
        getChatRoomsFoldersRecursive(chatRoomsStream.value.values.toList());
    final chRooms = chatRoomsStream.value;
    final parent = chatRooms.firstWhereOrNull(
        (element) => element.children!.any((e) => e.id == chatRoom.id));
    if (parent != null) {
      parent.children!.removeWhere((element) => element.id == chatRoom.id);
      chRooms[parent.id] = parent;
      chRooms[chatRoom.id] = chatRoom;
      chatRoomsStream.add(chRooms);
      // delete files because we already have them in the other folder
      FileUtils.getChatRoomFilePath(chatRoom.id).then((path) {
        FileUtils.deleteFile(path);
      });
      notifyRoomsStream();
      saveToDisk(chatRoomsStream.value.values.toList());
    }
  }

  void ungroupByFolder(ChatRoom chatFolder) {
    // get all children from folder
    // remove folder
    // paste children to the main list
    final chatRooms = chatRoomsStream.value;
    final folder = chatFolder;
    final children = folder.children!;
    chatRooms.removeWhere((key, value) => value.id == folder.id);
    // delete file
    FileUtils.getChatRoomFilePath(folder.id)
        .then((path) => FileUtils.deleteFile(path));
    for (var child in children) {
      chatRooms[child.id] = child;
    }
    chatRoomsStream.add(chatRooms);
    notifyRoomsStream();
    notifyListeners();
    saveToDisk(chatRoomsStream.value.values.toList());
  }

  /// if [rooms] list is 1 element and it's current chat room, it will save messages to disk
  Future<void> saveToDisk(List<ChatRoom> rooms) async {
    if (rooms.length == 1) {
      if (rooms.first.id == selectedChatRoomId) {
        // if it's current chat room, save messages
        final messagesRaw = <Map<String, dynamic>>[];
        for (var message in messages.value.entries) {
          /// add key and message.toJson
          messagesRaw.add(message.value.toJson());
        }
        await FileUtils.saveChatMessages(
            rooms.first.id, jsonEncode(messagesRaw));
      }
    }
    for (var chatRoom in rooms) {
      var chatRoomRaw = chatRoom.toJson();
      final path = await FileUtils.getChatRoomsPath();
      await FileUtils.saveFile(
          '$path/${chatRoom.id}.json', jsonEncode(chatRoomRaw));
    }
  }
}
List<ChatRoom> getChatRoomsFoldersRecursive(List<ChatRoom> chatRooms) {
  final folders = <ChatRoom>[];
  for (var chatRoom in chatRooms) {
    if (chatRoom.isFolder) {
      folders.add(chatRoom);
      if (chatRoom.children != null) {
        folders.addAll(getChatRoomsFoldersRecursive(chatRoom.children!));
      }
    }
  }
  return folders;
}
