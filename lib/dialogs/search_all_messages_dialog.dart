import 'dart:convert';
import 'dart:io';

import 'package:fluent_gpt/common/chat_room.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/custom_list_tile.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

class SearchAllMessagesDialog extends StatefulWidget {
  const SearchAllMessagesDialog({super.key});

  static show(BuildContext context) {
    showDialog(
      barrierDismissible: true,
      context: context,
      builder: (context) => const SearchAllMessagesDialog(),
    );
  }

  @override
  State<SearchAllMessagesDialog> createState() =>
      _SearchAllMessagesDialogState();
}

class _SearchResult {
  final String chatRoomName;
  final String chatRoomId;
  final String message;

  _SearchResult(this.chatRoomName, this.chatRoomId, this.message);
}

class _SearchAllMessagesDialogState extends State<SearchAllMessagesDialog> {
  final controller = TextEditingController();
  bool isSearching = false;
  // chat_room_name, message
  List<_SearchResult> results = [];
  Future _search(BuildContext context) async {
    isSearching = true;
    results.clear();
    setState(() {});
    final path = await FileUtils.getChatRoomsPath();
    final chatRoomsFiles = FileUtils.getFilesRecursive(path);
    final chatRooms = <String, ChatRoom>{};
    for (final file in chatRoomsFiles) {
      try {
        await file.readAsString().then((text) {
          final chatRoom = ChatRoom.fromJson(text);
          chatRooms[chatRoom.id] = chatRoom;
        });
      } catch (e) {
        logError(e.toString());
      }
    }
    final allChatMessagesFiles = await FileUtils.getAllChatMessagesFiles();
    for (final file in allChatMessagesFiles) {
      try {
        await file.readAsString().then((text) {
          // ...\fluent_gpt\chat_rooms\xxuuRQT5p7YWbm1u-messages.json
          final fileName = file.path.split(Platform.pathSeparator).last;
          final id = fileName.split('-messages.json').first;
          final chatRoom = chatRooms[id];
          final messagesRaw = jsonDecode(text) as List<dynamic>;
          // id is the key
          for (var messageJson in messagesRaw) {
            try {
              // final content = messageJson as Map<String, dynamic>;//['content'] as Map<String, dynamic>;
              // final message = ChatRoom.chatMessageFromJson(content);
              final contentAsString = messageJson['content'] as String? ?? '';
              if (contentAsString
                  .toLowerCase()
                  .contains(controller.text.toLowerCase())) {
                results.add(_SearchResult(chatRoom?.chatRoomName ?? '-',
                    chatRoom?.id ?? '-', contentAsString));
              }
            } catch (e) {
              logError(
                  'Error while loading message from disk: $e. file: ${file.path}');
            }
          }
        });
      } catch (e) {
        logError(e.toString());
      }
    }
    isSearching = false;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Global search'),
      constraints: BoxConstraints(maxWidth: 800),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextBox(
            autofocus: true,
            placeholder: 'Search',
            autocorrect: true,
            controller: controller,
            onSubmitted: (_) => _search(context),
          ),
          if (isSearching)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ProgressBar(),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final result = results[index];
                return BasicListTile(
                  title: Text(result.chatRoomName,
                      style: context.theme.typography.subtitle),
                  subtitle: Text(result.message),
                  margin: EdgeInsets.all(2),
                  onTap: () {
                    final provider = context.read<ChatProvider>();
                    Navigator.of(context).pop();
                    final chatRoom = chatRooms[result.chatRoomId];
                    provider.selectChatRoom(chatRoom!);
                  },
                );
              },
            ),
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => _search(context),
          child: const Text('Search'),
        ),
        Button(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Close'.tr),
        ),
      ],
    );
  }
}
