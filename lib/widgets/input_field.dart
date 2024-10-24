import 'dart:async';
import 'dart:io';

import 'package:fluent_gpt/common/custom_prompt.dart';
import 'package:fluent_gpt/common/debouncer.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/dialogs/ai_prompts_library_dialog.dart';
import 'package:fluent_gpt/dialogs/answer_with_tags_dialog.dart';
import 'package:fluent_gpt/dialogs/models_list_dialog.dart';
import 'package:fluent_gpt/dialogs/search_chat_dialog.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/pages/home_page.dart';
import 'package:fluent_gpt/pages/prompts_settings_page.dart';
import 'package:fluent_gpt/pages/settings_page.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/custom_buttons.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as ic;
import 'package:flutter/services.dart';
import 'package:glowy_borders/glowy_borders.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:langchain/langchain.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/chat_provider.dart';

class InputField extends StatefulWidget {
  const InputField({super.key, this.isMini = false});
  final bool isMini;

  @override
  State<InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<InputField> {
  void onSubmit(String text, ChatProvider chatProvider) {
    if (text.trim().isEmpty && chatProvider.fileInput == null) {
      return;
    }
    chatProvider.sendMessage(text.trim());
    clearFieldAndFocus();
  }

  void clearFieldAndFocus() {
    final chatProvider = context.read<ChatProvider>();
    Future.delayed(const Duration(milliseconds: 50)).then(
      (value) {
        chatProvider.messageController.clear();
        promptTextFocusNode.requestFocus();
      },
    );
  }

  @override
  void initState() {
    super.initState();
    shiftPressedStream.stream.listen((isShiftPressed) {
      _isShiftPressed = isShiftPressed;
      if (mounted) setState(() {});
    });
  }

  void onShortcutPasteText(String text) {
    final chatProvider = context.read<ChatProvider>();
    final currentCursorPosition =
        chatProvider.messageController.selection.base.offset;
    final currentText = chatProvider.messageController.text;
    final newText = currentText.substring(0, currentCursorPosition) +
        text +
        currentText.substring(currentCursorPosition);
    chatProvider.messageController.text = newText;
    windowManager.focus();
    promptTextFocusNode.requestFocus();
    // place the cursor at the end of the pasted text
    chatProvider.messageController.selection =
        TextSelection.collapsed(offset: currentCursorPosition + text.length);
  }

  void onShortcutPasteImage(Uint8List? image) async {
    if (image == null) return;

    final chatProvider = context.read<ChatProvider>();
    final imageFilePng = await image.toPNG();
    final base64 = await imageFilePng.imageToBase64();
    chatProvider.addAttachemntAiLens(base64);
  }

  Future<void> onShortcutPasteToField() async {
    final text = await Pasteboard.text;
    if (text != null) {
      onShortcutPasteText(text);
    }
    final image = await Pasteboard.image;
    if (image != null) {
      onShortcutPasteImage(image);
    }
  }

  Future<void> onShortcutCopyToThirdParty() async {
    final lastMessage = messages.value.values.last;
    // final previousClipboard = await Pasteboard.text;
    Pasteboard.writeText(lastMessage.contentAsString);
    displayCopiedToClipboard();
  }

  Future<void> onShortcutSearchPressed() async {
    final provider = context.read<ChatProvider>();
    final String? elementkey = await showDialog(
      context: context,
      builder: (context) => const SearchChatDialog(query: ''),
    );
    if (elementkey == null) return;
    provider.scrollToMessage(elementkey);
  }

  bool _isShiftPressed = false;
  bool _useShimmer = false;

  final debouncer = Debouncer(milliseconds: 500);

  @override
  Widget build(BuildContext context) {
    final ChatProvider chatProvider = context.watch<ChatProvider>();

    return CallbackShortcuts(
      bindings: {
        if (Platform.isMacOS)
          const SingleActivator(LogicalKeyboardKey.keyV, meta: true):
              onShortcutPasteToField
        else
          const SingleActivator(LogicalKeyboardKey.keyV, control: true):
              onShortcutPasteToField,
        if (Platform.isMacOS)
          const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
              onShortcutSearchPressed
        else
          const SingleActivator(LogicalKeyboardKey.keyF, control: true):
              onShortcutSearchPressed,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true):
            onShortcutCopyToThirdParty,
        const SingleActivator(LogicalKeyboardKey.arrowUp, meta: true): () {
          FocusScope.of(context).previousFocus();
        },
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.isMini) ...[
              Row(
                children: [
                  if (chatProvider.fileInput == null)
                    _AddFileButton(
                        chatProvider: chatProvider, isMini: widget.isMini),
                  if (chatProvider.fileInput != null)
                    _FileThumbnail(chatProvider: chatProvider),
                  const _ChooseModelButton(),
                ],
              ),
              Expanded(
                child: TextBox(
                  autofocus: true,
                  autocorrect: true,
                  focusNode: promptTextFocusNode,
                  prefixMode: OverlayVisibilityMode.always,
                  controller: chatProvider.messageController,
                  minLines: 2,
                  maxLines: 30,
                  suffix: const _MicrophoneButton(),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (value) {
                    if (_isShiftPressed == false) {
                      onSubmit(value, chatProvider);
                    }
                    if (_isShiftPressed) {
                      chatProvider.messageController.text =
                          '${chatProvider.messageController.text}\n';
                      promptTextFocusNode.requestFocus();
                    }
                  },
                  placeholder: 'Type your message here',
                ),
              )
            ],
            if (!widget.isMini)
              Row(
                children: [
                  if (chatProvider.fileInput == null)
                    _AddFileButton(chatProvider: chatProvider),
                  if (chatProvider.fileInput != null)
                    _FileThumbnail(chatProvider: chatProvider),
                  if (!widget.isMini)
                    Expanded(
                      child: Shimmer(
                        enabled: _useShimmer,
                        duration: const Duration(milliseconds: 600),
                        color: context.theme.accentColor,
                        child: TextBox(
                          autofocus: true,
                          autocorrect: true,
                          focusNode: promptTextFocusNode,
                          prefixMode: OverlayVisibilityMode.always,
                          controller: chatProvider.messageController,
                          minLines: 2,
                          maxLines: 30,
                          onChanged: (value) {
                            debouncer.call(() {
                              setState(() {});
                            });
                          },
                          suffix: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const _MicrophoneButton(),
                              if (chatProvider
                                  .messageController.text.isNotEmpty)
                                ImproveTextSparkleButton(
                                  onStateChange: (state) {
                                    if (state ==
                                        ImproveTextSparkleButtonState
                                            .improving) {
                                      setState(() {
                                        _useShimmer = true;
                                      });
                                    }
                                    if (state ==
                                        ImproveTextSparkleButtonState
                                            .improved) {
                                      setState(() {
                                        _useShimmer = false;
                                      });
                                    }
                                  },
                                  onTextImproved: (text) {
                                    chatProvider.messageController.text = text;
                                  },
                                  input: () => chatProvider
                                      .messageController.text
                                      .trim(),
                                ),
                            ],
                          ),
                          prefix: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _ChooseModelButton(),
                              AiLibraryButton(
                                onPressed: () async {
                                  // ignore: use_build_context_synchronously
                                  final controller =
                                      context.read<ChatProvider>();
                                  final prompt =
                                      await showDialog<CustomPrompt?>(
                                    context: context,
                                    builder: (ctx) =>
                                        const AiPromptsLibraryDialog(),
                                    barrierDismissible: true,
                                  );
                                  if (prompt != null) {
                                    controller.messageController.text =
                                        prompt.getPromptText(
                                            controller.messageController.text);
                                    promptTextFocusNode.requestFocus();
                                  }
                                },
                                isSmall: true,
                              ),
                            ],
                          ),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (value) {
                            if (_isShiftPressed == false) {
                              onSubmit(value, chatProvider);
                            }
                            if (_isShiftPressed) {
                              chatProvider.messageController.text =
                                  '${chatProvider.messageController.text}\n';
                              promptTextFocusNode.requestFocus();
                            }
                          },
                          placeholder: 'Type your message here',
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  if (_isShiftPressed)
                    const Icon(ic.FluentIcons.arrow_down_12_filled),
                  const SizedBox(width: 4),
                  if (chatProvider.isAnswering)
                    SizedBox.square(
                      dimension: 52,
                      child: AnimatedGradientBorder(
                        borderRadius: BorderRadius.circular(5),
                        gradientColors: [
                          Colors.red,
                          Colors.orange,
                          Colors.yellow,
                          Colors.green,
                          Colors.blue,
                        ],
                        glowSize: 2,
                        animationTime: 5,
                        child: IconButton(
                          style: ButtonStyle(
                              backgroundColor: WidgetStatePropertyAll(
                            context.theme.scaffoldBackgroundColor,
                          )),
                          onPressed: () {
                            chatProvider.stopAnswering();
                          },
                          icon: Icon(
                            ic.FluentIcons.stop_24_filled,
                            size: 24,
                          ),
                        ),
                      ),
                    )
                  else
                    FlyoutTarget(
                      controller: menuController,
                      child: SizedBox.square(
                        dimension: 44,
                        child: GestureDetector(
                          onSecondaryTap: _onSecondaryTap,
                          child: Button(
                            onPressed: () => onSubmit(
                              chatProvider.messageController.text,
                              chatProvider,
                            ),
                            child: const Icon(
                              ic.FluentIcons.send_24_filled,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  const SizedBox(width: 10),
                ],
              ),
          ],
        ),
      ),
    );
  }

  final menuController = FlyoutController();

  void _onSecondaryTap() {
    final provider = context.read<ChatProvider>();
    final controller = provider.messageController;
    menuController.showFlyout(builder: (ctx) {
      return MenuFlyout(
        items: [
          MenuFlyoutItem(
              text: const Text('Send as assistant (silently)'),
              onPressed: () {
                provider.addMessageSystem(controller.text);
                clearFieldAndFocus();
              }),
          MenuFlyoutItem(
              text: const Text('Send as user (silently)'),
              onPressed: () {
                provider.addHumanMessageToList(HumanChatMessage(
                    content: ChatMessageContent.text(controller.text)));
                clearFieldAndFocus();
              }),
          MenuFlyoutItem(
              text: const Text('Send as AI answer (silently)'),
              onPressed: () {
                provider.addBotMessageToList(
                    AIChatMessage(content: controller.text),
                    DateTime.now().toIso8601String());
                clearFieldAndFocus();
              }),
          MenuFlyoutSeparator(),
          MenuFlyoutItem(
            text: const Text(
                'Send not in real-time (can help with some LLM providers)'),
            onPressed: () {
              provider.sendMessage(controller.text, false, false);
              clearFieldAndFocus();
            },
          )
        ],
      );
    });
  }
}

class _MicrophoneButton extends StatefulWidget {
  const _MicrophoneButton({super.key});

  @override
  State<_MicrophoneButton> createState() => __MicrophoneButtonState();
}

class __MicrophoneButtonState extends State<_MicrophoneButton> {
  bool isRecording = false;
  Future<bool> checkPermission() async {
    // final permission = await Permission.speech.request();
    // if (permission.isGranted) {
    //   return true;
    // } else {
    //   return false;
    // }
    final result = await AudioRecorder().hasPermission();
    if (!result) {
      // ignore: use_build_context_synchronously
      displayInfoBar(context, builder: (ctx, close) {
        return const InfoBar(
          title: Text('Permission required'),
          severity: InfoBarSeverity.warning,
        );
      });
    }
    return result;
  }

  Future startRecording() async {
    final permission = await checkPermission();
    if (!permission) {
      return;
    }
    setState(() {
      isRecording = true;
    });
    // ignore: use_build_context_synchronously
    final provider = context.read<ChatProvider>();
    final resultStart = await provider.startListeningForInput();
    if (!resultStart) {
      setState(() {
        isRecording = false;
      });
    }
  }

  void stopRecording() {
    setState(() {
      isRecording = false;
    });
    final provider = context.read<ChatProvider>();
    provider.stopListeningForInput();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: Container(
        width: 42,
        height: 30,
        margin: const EdgeInsets.only(right: 4),
        child: ToggleButtonAdvenced(
          onChanged: (v) {
            if (isRecording) {
              stopRecording();
            } else {
              startRecording();
            }
          },
          contextItems: [
            for (final locale in gptLocales)
              FlyoutListTile(
                text: Text(locale.languageCode),
                selected: AppCache.speechLanguage.value == locale.languageCode,
                onPressed: () {
                  AppCache.speechLanguage.value = locale.languageCode;
                  setState(() {});
                  Navigator.of(context).pop();
                },
              ),
          ],
          maxWidthContextMenu: 84,
          checked: isRecording,
          padding: EdgeInsets.zero,
          icon: ic.FluentIcons.mic_24_regular,
          tooltip: 'Use voice input',
        ),
      ),
    );
  }
}

class _ChooseModelButton extends StatefulWidget {
  const _ChooseModelButton({super.key});

  @override
  State<_ChooseModelButton> createState() => _ChooseModelButtonState();
}

class _ChooseModelButtonState extends State<_ChooseModelButton> {
  final FlyoutController flyoutController = FlyoutController();

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final provider = context.watch<ChatProvider>();
    return Focus(
      canRequestFocus: false,
      descendantsAreTraversable: false,
      child: FlyoutTarget(
        controller: flyoutController,
        child: Container(
          decoration: BoxDecoration(
            color: FluentTheme.of(context).cardColor,
            borderRadius: BorderRadius.circular(4),
          ),
          width: 30,
          height: 30,
          margin: const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.all(2),
          child: GestureDetector(
            onTap: () => openFlyout(context),
            child: SizedBox.square(
              dimension: 20,
              child: selectedModel.modelIcon,
            ),
          ),
        ),
      ),
    );
  }

  void openFlyout(BuildContext context) {
    final provider = context.read<ChatProvider>();
    final models = allModels.value;
    final selectedModel = selectedChatRoom.model;
    flyoutController.showFlyout(builder: (ctx) {
      return MenuFlyout(
        items: [
          ...models.map(
            (e) => MenuFlyoutItem(
              selected: e.modelName == selectedModel.modelName,
              trailing: e.modelName == selectedModel.modelName
                  ? const Icon(ic.FluentIcons.checkmark_16_filled)
                  : null,
              leading: SizedBox.square(dimension: 24, child: e.modelIcon),
              text: Text(e.customName),
              onPressed: () => provider.selectNewModel(e),
            ),
          ),
          const MenuFlyoutSeparator(),
          MenuFlyoutItem(
            leading: const Icon(ic.FluentIcons.add_24_filled),
            text: const Text('Add'),
            onPressed: () {
              Navigator.of(ctx).pop();
              showDialog(
                  context: context, builder: (ctx) => ModelsListDialog());
            },
          ),
        ],
      );
    });
  }
}

class _AddFileButton extends StatelessWidget {
  const _AddFileButton({
    super.key,
    required this.chatProvider,
    this.isMini = false,
  });

  final ChatProvider chatProvider;
  final bool isMini;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: isMini ? 30 : 48,
      child: IconButton(
        onPressed: () async {
          FilePickerResult? result = await FilePicker.platform.pickFiles();
          if (result != null && result.files.isNotEmpty) {
            chatProvider.addFileToInput(result.files.first.toXFile());
            windowManager.focus();
            promptTextFocusNode.requestFocus();
          }
        },
        icon: chatProvider.isSendingFile
            ? const ProgressRing()
            : Icon(ic.FluentIcons.attach_24_filled, size: isMini ? 16 : 24),
      ),
    );
  }
}

class _FileThumbnail extends StatelessWidget {
  const _FileThumbnail({
    super.key,
    required this.chatProvider,
  });

  final ChatProvider chatProvider;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 48,
      child: Stack(
        children: [
          IconButton(
            onPressed: () async {
              if (chatProvider.isSendingFile) {
                return;
              }
              FilePickerResult? result = await FilePicker.platform.pickFiles();
              if (result != null && result.files.isNotEmpty) {
                chatProvider.addFileToInput(result.files.first.toXFile());
                windowManager.focus();
                promptTextFocusNode.requestFocus();
              }
            },
            icon: const Icon(ic.FluentIcons.document_number_1_16_regular,
                size: 24),
          ),
          if (chatProvider.fileInput!.mimeType?.contains('image') == true)
            Positioned.fill(
              bottom: 0,
              right: 0,
              child: FutureBuilder<Uint8List>(
                  future: chatProvider.fileInput!.readAsBytes(),
                  builder: (context, snapshot) {
                    if (snapshot.data == null) {
                      return const SizedBox.shrink();
                    }
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Image.memory(
                        snapshot.data as Uint8List,
                        fit: BoxFit.cover,
                      ),
                    );
                  }),
            ),
          // if (chatProvider.isSendingFile)
          //   const Positioned.fill(
          //     child: Center(child: ProgressRing()),
          //   ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              style: ButtonStyle(
                backgroundColor:
                    WidgetStateProperty.all(Colors.black.withOpacity(0.5)),
              ),
              onPressed: () => chatProvider.removeFileFromInput(),
              icon: Icon(FluentIcons.chrome_close, size: 12, color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}

class HotShurtcutsWidget extends StatefulWidget {
  const HotShurtcutsWidget({super.key});

  static void showAnswerWithTagsDialog(BuildContext context, String text) {
    showDialog(
      context: context,
      builder: (ctx) => AnswerWithTagsDialog(text: text),
    );
  }

  @override
  State<HotShurtcutsWidget> createState() => _HotShurtcutsWidgetState();
}

class _HotShurtcutsWidgetState extends State<HotShurtcutsWidget> {
  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final txtController = chatProvider.messageController;

    return StreamBuilder(
        stream: customPrompts,
        builder: (context, snapshot) {
          if (snapshot.data == null) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.start,
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final prompt in customPrompts.value)
                    if (prompt.showInChatField)
                      PromptChipWidget(prompt: prompt),
                  Button(
                      child: const Text('Answer with tags'),
                      onPressed: () async {
                        final textFromClipboard =
                            (await Clipboard.getData('text/plain'))?.text ?? '';
                        final text = txtController.text.trim().isEmpty
                            ? textFromClipboard
                            : txtController.text;
                        HotShurtcutsWidget.showAnswerWithTagsDialog(
                          // ignore: use_build_context_synchronously
                          context,
                          text,
                        );
                        txtController.clear();
                      }),
                ],
              ),
            ),
          );
        });
  }
}

class PromptChipWidget extends StatefulWidget {
  const PromptChipWidget({
    super.key,
    required this.prompt,
  });

  final CustomPrompt prompt;

  @override
  State<PromptChipWidget> createState() => _PromptChipWidgetState();
}

class _PromptChipWidgetState extends State<PromptChipWidget> {
  Future<void> _onTap(BuildContext context, CustomPrompt child) async {
    final contr = context.read<ChatProvider>().messageController;

    if (contr.text.trim().isNotEmpty) {
      onTrayButtonTapCommand(child.getPromptText(contr.text));
      contr.clear();
    } else {
      final clipboard = await Clipboard.getData('text/plain');
      final selectedText = clipboard?.text?.trim() ?? '';
      if (selectedText.isNotEmpty) {
        onTrayButtonTapCommand(child.getPromptText(selectedText));
        contr.clear();
      }
    }
  }

  final flyoutContr = FlyoutController();

  @override
  Widget build(BuildContext context) {
    return FlyoutTarget(
      controller: flyoutContr,
      child: GestureDetector(
        onSecondaryTap: () => _onRightClick(context),
        child: Button(
          onPressed: () => _onTap(context, widget.prompt),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.prompt.icon, size: 18),
              const SizedBox(width: 4),
              Text(widget.prompt.title),
              if (widget.prompt.children.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: DropDownButton(
                    items: [
                      for (final child in widget.prompt.children)
                        MenuFlyoutItem(
                          leading: Icon(child.icon),
                          text: Text(child.title),
                          onPressed: () => _onTap(context, child),
                        )
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  _onRightClick(BuildContext context) {
    final item = widget.prompt;

    flyoutContr.showFlyout(builder: (ctx) {
      return FlyoutContent(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final child in item.children)
              FlyoutListTile(
                icon: Icon(child.icon),
                text: Text(child.title),
                onPressed: () => _onTap(ctx, child),
              ),
            if (item.children.isNotEmpty) const Divider(),
            FlyoutListTile(
              icon: const Icon(ic.FluentIcons.settings_20_regular),
              text: const Text('Edit'),
              onPressed: () async {
                final prompt = await showDialog<CustomPrompt?>(
                  context: context,
                  builder: (context) => EditPromptDialog(prompt: item),
                );
                if (prompt != null) {
                  // ignore: use_build_context_synchronously
                  final list = customPrompts.value.toList();
                  list.removeWhere((element) => element.id == item.id);
                  list.add(prompt);
                  list.sort((a, b) => a.index.compareTo(b.index));
                  customPrompts.add(list);
                  // ignore: use_build_context_synchronously
                  Navigator.of(ctx).pop();

                  //unbind old hotkey
                  if (item.hotkey != null) {
                    await hotKeyManager.unregister(item.hotkey!);

                    /// wait native channel to finish
                    await Future.delayed(const Duration(milliseconds: 200));
                  }
                  OverlayManager.bindHotkeys(customPrompts.value);
                }
              },
            ),
          ],
        ),
      );
    });
  }
}
