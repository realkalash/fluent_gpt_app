
import 'package:fluent_gpt/common/chat_room.dart';
import 'package:fluent_gpt/pages/settings_page.dart';
import 'package:fluent_gpt/providers/chat_gpt_provider.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

class EditChatRoomDialog extends StatelessWidget {
  const EditChatRoomDialog(
      {super.key, required this.room, required this.onOkPressed});
  final ChatRoom room;
  final VoidCallback onOkPressed;

  @override
  Widget build(BuildContext ctx) {
    final provider = ctx.read<ChatGPTProvider>();
    var roomName = room.chatRoomName;
    var systemMessage = room.systemMessage;
    var maxLength = room.maxTokenLength;
    var token = room.token;
    var orgID = room.orgID;
    return ContentDialog(
      title: const Text('Edit chat room'),
      constraints: const BoxConstraints(maxWidth: 800),
      actions: [
        Button(
          onPressed: () {
            provider.editChatRoom(
                room.chatRoomName,
                room.copyWith(
                  chatRoomName: roomName,
                  commandPrefix: systemMessage,
                  maxLength: maxLength,
                  token: token,
                  orgID: orgID,
                ));
            Navigator.of(ctx).pop();
            onOkPressed();
          },
          child: const Text('Save'),
        ),
        Button(
          onPressed: () {
            Navigator.of(ctx).pop();
          },
          child: const Text('Cancel'),
        ),
      ],
      content: ListView(
        children: [
          const Text('Chat room name'),
          TextBox(
            controller: TextEditingController(text: room.chatRoomName),
            onChanged: (value) {
              roomName = value;
            },
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
            controller: TextEditingController(text: room.token),
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
