import 'dart:convert';
import 'dart:io';

import 'package:fluent_gpt/common/chat_room.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/navigation_provider.dart';
import 'package:fluent_gpt/providers/chat_gpt_provider.dart';
import 'package:fluent_gpt/widgets/custom_buttons.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

class DeletedChatsDialog extends StatefulWidget {
  const DeletedChatsDialog({super.key});

  @override
  State<DeletedChatsDialog> createState() => _CostDialogState();

  static Future<Object?> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const DeletedChatsDialog(),
    );
  }
}

class _CostDialogState extends State<DeletedChatsDialog> {
  double bytesArchivedChats = 0.0;
  Map<File, ChatRoom> chatRooms = {};
  @override
  void initState() {
    super.initState();

    // get the size of the archived chats
    FileUtils.getArchivedChatRoomPath().then((archivedChatsPath) async {
      final size = await FileUtils.calculateSizeRecursive(archivedChatsPath);
      if (mounted) {
        setState(() {
          bytesArchivedChats = size;
        });
      }
      final files = FileUtils.getFilesRecursive(archivedChatsPath);
      for (final file in files) {
        // skip DS_Store
        if (file.path.contains('.DS_Store')) {
          continue;
        }
        try {
          final String json = await file.readAsString();
          final room = await ChatRoom.fromJson(json);
          chatRooms[file] = room;
          if (mounted) {
            setState(() {});
          }
        } catch (e) {
          logError('Error reading chat room from file: $e');
        }
      }
    });
  }

  String getBytesChatsString(double value) {
    // to kilobytes if needed
    if (value > 1024) {
      return '${(value / 1024).toStringAsFixed(2)} KB';
    }
    // to megabytes if needed
    if (value > 1024 * 1024) {
      return '${(value / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${value.toStringAsFixed(2)} bytes';
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Storage usage'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
              'Archived chats size: ${getBytesChatsString(bytesArchivedChats)}'),
          Expanded(
            child: ListView.builder(
              itemCount: chatRooms.length,
              itemBuilder: (context, index) {
                final file = chatRooms.keys.elementAt(index);
                final room = chatRooms[file]!;
                final fileSize = file.lengthSync().toDouble();
                return ListTile(
                  title: Text(room.chatRoomName),
                  subtitle: Text('Size: ${getBytesChatsString(fileSize)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Button(
                        onPressed: () async {
                          final path = await FileUtils.getChatRoomPath();
                          await FileUtils.moveFile(
                              file.path, '$path/${file.path.split('/').last}');
                          final size =
                              await FileUtils.calculateSizeRecursive(path);
                          if (mounted) {
                            setState(() {
                              chatRooms.remove(file);
                              bytesArchivedChats -= fileSize;
                              bytesArchivedChats = size;
                            });
                            // ignore: use_build_context_synchronously
                            context.read<ChatGPTProvider>().initChatsFromDisk();
                          }
                        },
                        child: const Text('Restore'),
                      ),
                      FilledRedButton(
                        onPressed: () async {
                          await file.delete();
                          if (mounted) {
                            setState(() {
                              chatRooms.remove(file);
                              bytesArchivedChats -= fileSize;
                            });
                          }
                        },
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
