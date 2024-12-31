import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_gpt/common/chat_room.dart';
import 'package:fluent_gpt/common/custom_prompt.dart';
import 'package:fluent_gpt/common/debouncer.dart';
import 'package:fluent_gpt/dialogs/ai_prompts_library_dialog.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/system_messages.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/custom_buttons.dart';
import 'package:fluent_gpt/widgets/markdown_builders/code_wrapper.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
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

    roomName = widget.room.chatRoomName;

    systemMessageContr.text = widget.room.systemMessage ?? '';
    maxTokens = widget.room.maxTokenLength;
    token = widget.room.model.apiKey;
    index = widget.room.indexSort;
    characterName = widget.room.characterName;
    characterAvatarPath = widget.room.characterAvatarPath;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      countTokens();
    });
  }

  Future countTokens() async {
    if (widget.room.isFolder) return;
    final tokens = await context
        .read<ChatProvider>()
        .countTokensString(systemMessageContr.text);
    setState(() {
      tokensInMessage = tokens;
    });
  }

  var roomName = '';
  final systemMessageContr = TextEditingController();
  int tokensInMessage = 0;
  String characterName = 'ai';
  String? characterAvatarPath;
  int maxTokens = 2048;
  var token = '';
  var index = 1;

  Debouncer debouncer = Debouncer(milliseconds: 500);

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ChatProvider>();

    return ContentDialog(
      title: widget.room.isFolder
          ? const Text('Edit folder')
          : const Text('Edit chat room'),
      constraints: const BoxConstraints(maxWidth: 800),
      actions: [
        FilledButton(
          onPressed: () {
            
            provider.editChatRoom(
              widget.room.id,
              widget.room.copyWith(
                chatRoomName: roomName,
                systemMessage: systemMessageContr.text,
                maxLength: maxTokens,
                token: token,
                indexSort: index,
                iconCodePoint: ico,
                systemMessageTokensCount: tokensInMessage,
                characterName: characterName,
                avatarPath: characterAvatarPath,
              ),
            );
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
        shrinkWrap: true,
        children: [
          if (!widget.room.isFolder)
            Align(
              alignment: Alignment.centerLeft,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () async {
                    final result = await FilePicker.platform
                        .pickFiles(type: FileType.image, allowMultiple: false);
                    if (result == null) return;
                    final path = result.files.single.path;
                    setState(() {
                      characterAvatarPath = path;
                    });
                  },
                  child: SizedBox.square(
                    dimension: 100,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Container(
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: context.theme.scaffoldBackgroundColor,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: characterAvatarPath == null
                              ? const SizedBox.shrink()
                              : Image.file(
                                  File(characterAvatarPath!),
                                  fit: BoxFit.cover,
                                  alignment: Alignment.center,
                                  isAntiAlias: true,
                                ),
                        ),
                        if (characterAvatarPath == null)
                          Icon(FluentIcons.camera_20_regular)
                        else ...[
                          Center(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.all(4.0),
                              child: Icon(FluentIcons.camera_20_regular),
                            ),
                          ),
                          Positioned(
                            right: 4,
                            bottom: 4,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  characterAvatarPath = null;
                                });
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.red,
                                  shape: BoxShape.circle,
                                ),
                                padding: const EdgeInsets.all(2.0),
                                child: Icon(FluentIcons.delete_20_regular,
                                    size: 16),
                              ),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
            ],
          ),
          if (!widget.room.isFolder) ...[
            const Text('Character name'),
            TextBox(
              controller:
                  TextEditingController(text: widget.room.characterName),
              maxLines: 1,
              onChanged: (value) {
                characterName = value;
              },
            ),
            Row(
              children: [
                const Text('System message'),
                Spacer(),
                SqueareIconButton(
                  onTap: () async {
                    final currentStrippedPrompt =
                        (systemMessageContr.text).isEmpty
                            ? defaultGlobalSystemMessage
                            : systemMessageContr.text
                                .split(contextualInfoDelimeter)
                                .first;
                    final newPrompt = await getFormattedSystemPrompt(
                      basicPrompt: currentStrippedPrompt,
                    );
                    systemMessageContr.text = newPrompt;
                  },
                  icon: Icon(FluentIcons.arrow_counterclockwise_16_regular),
                  tooltip: 'Update variables',
                ),
                AiLibraryButton(onPressed: () async {
                  final prompt = await showDialog<CustomPrompt?>(
                    context: context,
                    builder: (ctx) => const AiPromptsLibraryDialog(),
                    barrierDismissible: true,
                  );
                  if (prompt != null) {
                    setState(() {
                      systemMessageContr.text = prompt.getPromptText();
                    });
                  }
                }),
              ],
            ),
            TextBox(
              controller: systemMessageContr,
              maxLines: 30,
              minLines: 3,
              onChanged: (value) {
                debouncer.run(() {
                  countTokens();
                });
              },
            ),
            Text('T: $tokensInMessage'),
            const Text('Number in list'),
            NumberBox(
                value: widget.room.indexSort,
                min: 1,
                onChanged: (value) {
                  index = value ?? 1;
                }),
            const Text('Max token length'),
            TextBox(
              controller: TextEditingController(
                  text: widget.room.maxTokenLength.toString()),
              onChanged: (value) {
                maxTokens = int.parse(value);
              },
            ),
            const Text('Token'),
            TextBox(
              controller: TextEditingController(text: widget.room.model.apiKey),
              obscureText: true,
              onChanged: (value) {
                token = value;
              },
            ),
          ],
        ],
      ),
    );
  }
}
