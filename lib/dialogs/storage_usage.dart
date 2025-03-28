import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/pages/settings_page.dart';
import 'package:fluent_ui/fluent_ui.dart';

class StorageUsage extends StatefulWidget {
  const StorageUsage({super.key});

  @override
  State<StorageUsage> createState() => _CostDialogState();

  static Future<Object?> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const StorageUsage(),
    );
  }
}

class _CostDialogState extends State<StorageUsage> {
  double bytesChats = 0.0;
  double bytesArchivedChats = 0.0;

  @override
  void initState() {
    super.initState();
    // get the size of the chats
    FileUtils.getChatRoomsPath().then((chatsPath) {
      FileUtils.calculateSizeRecursive(chatsPath).then((value) {
        if (mounted) {
          setState(() {
            bytesChats = value;
          });
        }
      });
    });
    // get the size of the archived chats
    FileUtils.getArchivedChatRoomPath().then((archivedChatsPath) {
      FileUtils.calculateSizeRecursive(archivedChatsPath).then((value) {
        if (mounted) {
          setState(() {
            bytesArchivedChats = value;
          });
        }
      });
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
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${'Chats'.tr} ${getBytesChatsString(bytesChats)}'),
          Text(
              '${'Archived chats'.tr} ${getBytesChatsString(bytesArchivedChats)}'),
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
                      onChanged: (int? value) {
                        AppCache.deleteOldArchivedChatsAfter.value = value;
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'.tr),
        ),
      ],
    );
  }
}
