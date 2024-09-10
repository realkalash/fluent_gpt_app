import 'package:fluent_gpt/common/chat_room.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/dialogs/icon_chooser_dialog.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:langchain_openai/langchain_openai.dart';
import 'package:provider/provider.dart';

class EditChatRoomDialog extends StatefulWidget {
  const EditChatRoomDialog(
      {super.key, required this.room, required this.onOkPressed});
  final ChatRoom room;
  final VoidCallback onOkPressed;

  static Future<T?> show<T>({
    required BuildContext context,
    required ChatRoom room,
    required VoidCallback onOkPressed,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) =>
          EditChatRoomDialog(room: room, onOkPressed: onOkPressed),
    );
  }

  @override
  State<EditChatRoomDialog> createState() => _EditChatRoomDialogState();
}

class _EditChatRoomDialogState extends State<EditChatRoomDialog> {
  late int ico;
  @override
  void initState() {
    ico = widget.room.iconCodePoint;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ChatProvider>();
    var roomName = widget.room.chatRoomName;
    var systemMessage = widget.room.systemMessage;
    var maxLength = widget.room.maxTokenLength;
    var token = AppCache.openAiApiKey.value;
    var index = widget.room.indexSort;
    return ContentDialog(
      title: const Text('Edit chat room'),
      constraints: const BoxConstraints(maxWidth: 800),
      actions: [
        Button(
          onPressed: () {
            provider.editChatRoom(
                widget.room.id,
                widget.room.copyWith(
                  chatRoomName: roomName,
                  systemMessage: systemMessage,
                  maxLength: maxLength,
                  token: token,
                  indexSort: index,
                  iconCodePoint: ico,
                ));
            AppCache.openAiApiKey.value = token;
            openAI = ChatOpenAI(apiKey: token);
            Navigator.of(context).pop();
            widget.onOkPressed();
          },
          child: const Text('Save'),
        ),
        Button(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
      ],
      content: ListView(
        children: [
          const Text('Chat room name'),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: TextBox(
                  controller:
                      TextEditingController(text: widget.room.chatRoomName),
                  onChanged: (value) {
                    roomName = value;
                  },
                ),
              ),
              Button(
                onPressed: () async {
                  final icon = await IconChooserDialog.show(context);
                  if (icon != null) {
                    setState(() {
                      ico = icon.codePoint;
                    });
                  }
                },
                child: Icon(
                  IconData(
                    ico,
                    fontPackage: 'fluentui_system_icons',
                    fontFamily: 'FluentSystemIcons-Filled',
                  ),
                  size: 24,
                ),
              ),
            ],
          ),
          const Text('System message'),
          TextBox(
            controller: TextEditingController(text: widget.room.systemMessage),
            maxLines: 30,
            minLines: 3,
            onChanged: (value) {
              systemMessage = value;
            },
          ),
          const Text('Number in list'),
          NumberBox(
              value: widget.room.indexSort,
              min: 1,
              onChanged: (value) {
                index = value ?? 1;
              }),
          const Text('Max length'),
          TextBox(
            controller: TextEditingController(
                text: widget.room.maxTokenLength.toString()),
            onChanged: (value) {
              maxLength = int.parse(value);
            },
          ),
          const Text('Token'),
          TextBox(
            controller:
                TextEditingController(text: AppCache.openAiApiKey.value),
            obscureText: true,
            onChanged: (value) {
              token = value;
            },
          ),
        ],
      ),
    );
  }
}
