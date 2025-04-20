import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_gpt/common/custom_prompt.dart';
import 'package:fluent_gpt/common/debouncer.dart';
import 'package:fluent_gpt/dialogs/ai_prompts_library_dialog.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/pages/home_page.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/system_messages.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/custom_buttons.dart';
import 'package:fluent_gpt/widgets/markdown_builders/code_wrapper.dart';
import 'package:fluent_gpt/widgets/wiget_constants.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:provider/provider.dart';

class EditChatDrawerContainer extends StatefulWidget {
  const EditChatDrawerContainer({super.key});

  @override
  State<EditChatDrawerContainer> createState() => _EditDrawerState();
}

class _EditDrawerState extends State<EditChatDrawerContainer> {
  late int ico;
  @override
  void initState() {
    ico = selectedChatRoom.iconCodePoint;
    super.initState();

    systemMessageContr.text = selectedChatRoom.systemMessage ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      countTokens();
    });
  }

  Future countTokens() async {
    if (selectedChatRoom.isFolder) return;
    if (systemMessageContr.text.trim().isEmpty) {
      tokensInMessage = 0;
      return;
    }
    final tokens = await context
        .read<ChatProvider>()
        .countTokensString(systemMessageContr.text);
    setState(() {
      tokensInMessage = tokens;
    });
  }

  final systemMessageContr = TextEditingController();
  int tokensInMessage = 0;

  Debouncer debouncer = Debouncer(milliseconds: 500);
  bool _expandSystemMessage = false;

  @override
  Widget build(BuildContext context) {
    // final provider = context.read<ChatProvider>();

    return StreamBuilder<Object>(
        stream: selectedChatRoomIdStream,
        builder: (context, snapshot) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: () async {
                          final result = await FilePicker.platform.pickFiles(
                              type: FileType.image, allowMultiple: false);
                          if (result == null) return;
                          final path = result.files.single.path;
                          setState(() {
                            selectedChatRoom.characterAvatarPath = path;
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
                                    color:
                                        context.theme.scaffoldBackgroundColor,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child:
                                    selectedChatRoom.characterAvatarPath == null
                                        ? const SizedBox.shrink()
                                        : Image.file(
                                            File(selectedChatRoom
                                                .characterAvatarPath!),
                                            fit: BoxFit.cover,
                                            alignment: Alignment.center,
                                            isAntiAlias: true,
                                          ),
                              ),
                              if (selectedChatRoom.characterAvatarPath == null)
                                Icon(FluentIcons.camera_20_regular)
                              else ...[
                                Center(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black.withAlpha(127),
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
                                        selectedChatRoom.characterAvatarPath =
                                            null;
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
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.start,
                          children: [
                            const Text('Chat room name'),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: TextBox(
                                    controller: TextEditingController(
                                        text: selectedChatRoom.chatRoomName),
                                    onChanged: (value) {
                                      selectedChatRoom.chatRoomName = value;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const Text('Character name'),
                            TextBox(
                              controller: TextEditingController(
                                  text: selectedChatRoom.characterName),
                              maxLines: 1,
                              onChanged: (value) {
                                selectedChatRoom.characterName = value;
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                    SqueareIconButton(
                      onTap: () => showEditChatDrawer.add(false),
                      icon: Text('X', style: TextStyle(color: Colors.red)),
                      tooltip: 'Close drawer',
                    ),
                  ],
                ),
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
                      selectedChatRoom.systemMessage = newPrompt;
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
                maxLines: _expandSystemMessage ? 40 : 15,
                minLines: 3,
                onChanged: (value) {
                  debouncer.run(() {
                    countTokens();
                    selectedChatRoom.systemMessage = value;
                  });
                },
              ),
              Row(children: [
                Text('T: $tokensInMessage'),
                Spacer(),
                ToggleButton(
                  checked: _expandSystemMessage,
                  child: _expandSystemMessage
                      ? const Icon(FluentIcons.chevron_up_20_regular)
                      : const Icon(FluentIcons.chevron_down_20_regular),
                  onChanged: (v) {
                    setState(() {
                      _expandSystemMessage = v;
                    });
                  },
                ),
                ToggleButton(
                  checked: true,
                  child: _expandSystemMessage
                      ? const Icon(FluentIcons.chevron_up_20_regular)
                      : const Icon(FluentIcons.chevron_down_20_regular),
                  onChanged: (v) {
                    final output = formatArgsInSystemPrompt(selectedChatRoom.systemMessage ?? '');
                    print(output);
                  },
                ),
              ]),
              spacer,
              _GridChildRow(
                first: Column(
                  children: [
                    Text('Max tokens to include'.tr),
                    Tooltip(
                      message:
                          "The maximum length of tokens to be sent to the model",
                      child: TextBox(
                        controller: TextEditingController(
                            text: '${selectedChatRoom.maxTokenLength}'),
                        onChanged: (value) {
                          selectedChatRoom.maxTokenLength =
                              int.tryParse(value) ??
                                  selectedChatRoom.maxTokenLength;
                        },
                        onEditingComplete: () => setState(() {}),
                        onTapOutside: (event) => setState(() {}),
                      ),
                    ),
                    Slider(
                      value: selectedChatRoom.maxTokenLength < 0.0
                          ? 0.0
                          : selectedChatRoom.maxTokenLength.toDouble(),
                      onChanged: (value) {
                        setState(() {
                          selectedChatRoom.maxTokenLength =
                              int.parse(value.toStringAsFixed(0));
                        });
                      },
                      min: 0.0,
                      max: 16384,
                      divisions: 32,
                    ),
                  ],
                ),
                second: Tooltip(
                  message:
                      "Try to limit model response length. Set to 0 or remove for no limit",
                  child: Column(
                    children: [
                      const Text('Response length in tokens'),
                      TextBox(
                        controller: TextEditingController(
                            text:
                                '${selectedChatRoom.maxTokensResponseLenght ?? ''}'),
                        onChanged: (value) {
                          if (value.trim().isEmpty || value == '0') {
                            selectedChatRoom.maxTokensResponseLenght = null;
                          } else {
                            selectedChatRoom.maxTokensResponseLenght =
                                int.tryParse(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              _GridChildRow(
                first: Tooltip(
                  message:
                      "How much to discourage repeating the same token. Number between -2.0 and 2.0",
                  child: Column(
                    children: [
                      const Text('Repeat penalty'),
                      TextBox(
                        controller: TextEditingController(
                            text: '${selectedChatRoom.repeatPenalty ?? ''}'),
                        onChanged: (value) {
                          selectedChatRoom.repeatPenalty =
                              double.tryParse(value);
                        },
                      ),
                    ],
                  ),
                ),
                second: Tooltip(
                  message:
                      "Minimum cumulative probability for the possible next tokens. Acts similarly to temperature",
                  child: Column(
                    children: [
                      const Text('Top P sampling'),
                      TextBox(
                        controller: TextEditingController(
                            text: '${selectedChatRoom.topP ?? ''}'),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          selectedChatRoom.topP = double.tryParse(value);
                        },
                      ),
                    ],
                  ),
                ),
              ),
              _GridChildRow(
                first: Column(
                  children: [
                    const Text('Temperature'),
                    Tooltip(
                      message:
                          "How much randomness to introduce. 0 will yield the same result every time, while higher values will increase creativity and variance. Recommended 0.7",
                      child: TextBox(
                        controller: TextEditingController(
                            text: '${selectedChatRoom.temp ?? ''}'),
                        keyboardType: TextInputType.number,
                        onChanged: (value) {
                          selectedChatRoom.temp = double.tryParse(value);
                        },
                        onEditingComplete: () {
                          setState(() {});
                        },
                        onTapOutside: (event) {
                          setState(() {});
                        },
                      ),
                    ),
                    if (selectedChatRoom.temp != null)
                      Slider(
                        value: selectedChatRoom.temp! < 0.0
                            ? 0.0
                            : selectedChatRoom.temp!,
                        onChanged: (value) {
                          setState(() {
                            selectedChatRoom.temp =
                                double.parse(value.toStringAsFixed(2));
                          });
                        },
                        min: 0.0,
                        max: 2.0,
                        divisions: 20,
                      ),
                  ],
                ),
                second: Tooltip(
                  message:
                      "The seed for the random number generator used in text generation. Use -1 or empty for random",
                  child: Column(
                    children: [
                      const Text('Seed'),
                      TextBox(
                        controller: TextEditingController(
                            text: '${selectedChatRoom.seed ?? ''}'),
                        onChanged: (value) {
                          if (value.trim().isEmpty || value == '-1') {
                            selectedChatRoom.seed = null;
                          } else {
                            selectedChatRoom.seed = int.tryParse(value);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        });
  }
}

class _GridChildRow extends StatelessWidget {
  const _GridChildRow({required this.first, required this.second});
  final Widget first;
  final Widget second;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: first),
        SizedBox(width: 10),
        Expanded(child: second),
      ],
    );
  }
}
