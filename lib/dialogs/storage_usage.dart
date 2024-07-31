import 'package:fluent_gpt/file_utils.dart';
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
    FileUtils.getChatRoomPath().then((chatsPath) {
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
      title: const Text('Storage usage'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Chats ${getBytesChatsString(bytesChats)}'),
          Text('Archived chats ${getBytesChatsString(bytesArchivedChats)}'),
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
