import 'package:fluent_gpt/common/chat_room.dart';
import 'package:fluent_gpt/fluent_icons_list.dart';
import 'package:fluent_gpt/pages/settings_page.dart';
import 'package:fluent_gpt/providers/chat_gpt_provider.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

class EditChatRoomDialog extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final provider = context.read<ChatGPTProvider>();
    var roomName = room.chatRoomName;
    var systemMessage = room.systemMessage;
    var maxLength = room.maxTokenLength;
    var token = room.apiToken;
    var orgID = room.orgID;
    var index = room.indexSort;
    var ico = room.iconCodePoint;
    return ContentDialog(
      title: const Text('Edit chat room'),
      constraints: const BoxConstraints(maxWidth: 800),
      actions: [
        Button(
          onPressed: () {
            provider.editChatRoom(
                room.id,
                room.copyWith(
                  chatRoomName: roomName,
                  commandPrefix: systemMessage,
                  maxLength: maxLength,
                  token: token,
                  orgID: orgID,
                  indexSort: index,
                ));
            Navigator.of(context).pop();
            onOkPressed();
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
              TextBox(
                controller: TextEditingController(text: room.chatRoomName),
                onChanged: (value) {
                  roomName = value;
                },
              ),
              DropDownButton(
                title: Icon(IconData(ico, fontFamily: 'FluentIcons')),
                items: fluentIconsList.map((e) {
                  return MenuFlyoutItem(
                    text:
                        Icon(IconData(e.codePoint, fontFamily: 'FluentIcons')),
                    onPressed: () {
                      ico = e.codePoint;
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          const Text('System message'),
          TextBox(
            controller: TextEditingController(text: room.systemMessage),
            maxLines: 30,
            minLines: 3,
            onChanged: (value) {
              systemMessage = value;
            },
          ),
          const Text('Model'),
          GptModelChooser(
            onChanged: (model) {
              provider.selectModelForChat(room.chatRoomName, model);
            },
          ),
          const Text('Number in list'),
          NumberBox(
              value: room.indexSort,
              min: 1,
              onChanged: (value) {
                index = value ?? 1;
              }),
          const Text('Max length'),
          TextBox(
            controller:
                TextEditingController(text: room.maxTokenLength.toString()),
            onChanged: (value) {
              maxLength = int.parse(value);
            },
          ),
          const Text('Token'),
          TextBox(
            controller: TextEditingController(text: room.apiToken),
            obscureText: true,
            onChanged: (value) {
              token = value;
            },
          ),
          const Text('Org ID'),
          TextBox(
            controller: TextEditingController(text: room.orgID),
            onChanged: (value) {
              orgID = value;
            },
          ),
        ],
      ),
    );
  }
}
