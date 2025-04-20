import 'dart:io';

import 'package:fluent_gpt/common/chat_room.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/pages/settings_page.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/shell_driver.dart';
import 'package:fluent_gpt/widgets/confirmation_dialog.dart';
import 'package:fluent_gpt/widgets/custom_buttons.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';

class DeletedChatsDialog extends StatefulWidget {
  const DeletedChatsDialog({super.key});

  @override
  State<DeletedChatsDialog> createState() => _DeletedChatsDialogState();

  static Future<Object?> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const DeletedChatsDialog(),
    );
  }
}

class _DeletedChatsDialogState extends State<DeletedChatsDialog> {
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
          final room = ChatRoom.fromJson(json);
          chatRooms[file] = room;
        } catch (e) {
          logError('Error reading chat room from file: $e');
        }
      }
      // sort chatRooms by last message date
      chatRooms = Map.fromEntries(chatRooms.entries.toList()
        ..sort((e1, e2) {
          final date1 = e1.value.dateModifiedMilliseconds;
          final date2 = e2.value.dateModifiedMilliseconds;
          return date2.compareTo(date1);
        }));
      if (mounted) {
        setState(() {});
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
      title: Text('Storage usage'.tr),
      constraints: BoxConstraints(
        maxWidth: 600,
        maxHeight: 1200,
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
              'Archived chats size: ${getBytesChatsString(bytesArchivedChats)}'),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CaptionText('Archive chats after (days)'.tr),
                    NumberBox(
                      value: AppCache.archiveOldChatsAfter.value,
                      onChanged: (int? value) {
                        AppCache.archiveOldChatsAfter.value = value;
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CaptionText('Delete chats after (days)'.tr),
                    NumberBox(
                      value: AppCache.deleteOldArchivedChatsAfter.value,
                      clearButton: true,
                      onChanged: (int? value) {
                        AppCache.deleteOldArchivedChatsAfter.value = value;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          Expanded(
            child: ListView.builder(
              itemCount: chatRooms.length,
              itemBuilder: (context, index) {
                final file = chatRooms.keys.elementAt(index);
                final room = chatRooms[file]!;
                final fileSize = file.lengthSync().toDouble();
                return ListTile(
                  title: Text(room.chatRoomName),
                  subtitle: Text(
                      '${DateTime.fromMillisecondsSinceEpoch(room.dateModifiedMilliseconds).toIso8601String()} - ${getBytesChatsString(fileSize)}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Button(
                        onPressed: () async {
                          final path = await FileUtils.getChatRoomsPath();
                          final fileName =
                              file.path.split(FileUtils.separatior!).last;
                          final newFilePath =
                              '$path${FileUtils.separatior!}$fileName';
                          await FileUtils.moveFile(file.path, newFilePath);

                          final size =
                              await FileUtils.calculateSizeRecursive(path);
                          if (mounted) {
                            setState(() {
                              chatRooms.remove(file);
                              bytesArchivedChats -= fileSize;
                              bytesArchivedChats = size;
                            });
                            // ignore: use_build_context_synchronously
                            context.read<ChatProvider>().initChatsFromDisk();
                          }
                        },
                        child: Text('Restore'.tr),
                      ),
                      FilledRedButton(
                        onPressed: () async {
                          await file.delete();
                          // delete copilot file with suffix '-messages.json'
                          final copilotFile = File(
                            file.path.replaceAll('.json', '-messages.json'),
                          );
                          if (copilotFile.existsSync()) {
                            await copilotFile.delete();
                          }
                          final path =
                              await FileUtils.getArchivedChatRoomPath();
                          final size =
                              await FileUtils.calculateSizeRecursive(path);

                          if (mounted) {
                            setState(() {
                              chatRooms.remove(file);
                              bytesArchivedChats = size;
                            });
                          }
                          if (mounted) {
                            setState(() {
                              chatRooms.remove(file);
                              bytesArchivedChats = size;
                            });
                          }
                        },
                        child:  Text('Delete'.tr),
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
        FilledRedButton(
          onPressed: () async {
            final acceted =
                await ConfirmationDialog.show(context: context, isDelete: true);
            if (acceted) {
              final path = await FileUtils.getArchivedChatRoomPath();
              final files = FileUtils.getFilesRecursiveWithChatMessages(path);
              for (final file in files) {
                try {
                  await file.delete();
                } catch (e) {
                  logError('Error deleting file: $e');
                }
              }
              if (mounted) {
                setState(() {
                  chatRooms.clear();
                  bytesArchivedChats = 0.0;
                });
              }
            }
          },
          child: Text('Delete all chat rooms'.tr),
        ),
        if (kDebugMode)
          Button(
            onPressed: () async {
              final path = await FileUtils.getArchivedChatRoomPath();
              ShellDriver.openExplorer(path);
            },
            child: const Text('Open folder'),
          ),
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'.tr),
        ),
      ],
    );
  }
}
