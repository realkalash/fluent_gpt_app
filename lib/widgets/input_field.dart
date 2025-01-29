import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:fluent_gpt/common/chat_model.dart';
import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/common/custom_prompt.dart';
import 'package:fluent_gpt/common/debouncer.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/common/prompts_templates.dart';
import 'package:fluent_gpt/common/stop_reason_enum.dart';
import 'package:fluent_gpt/dialogs/ai_prompts_library_dialog.dart';
import 'package:fluent_gpt/dialogs/answer_with_tags_dialog.dart';
import 'package:fluent_gpt/dialogs/models_list_dialog.dart';
import 'package:fluent_gpt/dialogs/search_chat_dialog.dart';
import 'package:fluent_gpt/features/push_to_talk_tool.dart';
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
import 'package:fluent_gpt/widgets/custom_list_tile.dart';
import 'package:fluent_gpt/widgets/markdown_builders/code_wrapper.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as ic;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
// ignore: unused_import
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
    if (_isShiftPressed) {
      chatProvider.messageController.text =
          '${chatProvider.messageController.text}\n';
      promptTextFocusNode.requestFocus();
      return;
    }
    if (altPressedStream.value) {
      chatProvider.addMessageSystem(text).then((_) {
        chatProvider.updateUI();
      });
      clearFieldAndFocus();
      return;
    }
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
    shiftPressedStream.listen((isShiftPressed) {
      _isShiftPressed = isShiftPressed;
      if (mounted) setState(() {});
    });

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      ChatProvider.messageControllerGlobal.addListener(onTextChangedListener);
    });
  }

  @override
  void dispose() {
    ChatProvider.messageControllerGlobal.removeListener(onTextChangedListener);
    super.dispose();
  }

  void onShortcutPasteText(String text) {
    if (text.isEmpty) return;

    final clipboard = text;
    final chatProvider = context.read<ChatProvider>();
    final textSelection = chatProvider.messageController.selection;
    final currentText = chatProvider.messageController.text;

    try {
      String newText;
      int newCursorPosition;

      if (textSelection.isValid && !textSelection.isCollapsed) {
        // Validate selection bounds
        final start = textSelection.start.clamp(0, currentText.length);
        final end = textSelection.end.clamp(0, currentText.length);

        if (start > end) {
          // Swap if reversed
          newText = currentText.substring(0, end) +
              clipboard +
              currentText.substring(start);
          newCursorPosition = end + clipboard.length;
        } else {
          newText = currentText.substring(0, start) +
              clipboard +
              currentText.substring(end);
          newCursorPosition = start + clipboard.length;
        }
      } else {
        // Handle cursor insertion safely
        final currentCursorPosition =
            max(0, min(textSelection.base.offset, currentText.length));
        newText = currentText.substring(0, currentCursorPosition) +
            clipboard +
            currentText.substring(currentCursorPosition);
        newCursorPosition = currentCursorPosition + clipboard.length;
      }

      chatProvider.messageController.text = newText;
      chatProvider.messageController.selection =
          TextSelection.collapsed(offset: newCursorPosition);

      // Safe focus management
      try {
        windowManager.focus();
        promptTextFocusNode.requestFocus();
      } catch (e) {
        debugPrint('Focus management error: $e');
      }
    } catch (e) {
      debugPrint('Paste operation error: $e');
    }
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

  Future<void> toggleEnableHistory() async {
    final provider = context.read<ChatProvider>();
    provider.setIncludeWholeConversation(!provider.includeConversationGlobal);
    if (provider.includeConversationGlobal) {
      displayInfoBar(
        context,
        builder: (ctx, close) {
          return const InfoBar(
            title: Text('History enabled'),
          );
        },
        duration: const Duration(milliseconds: 1400),
      );
    } else {
      displayInfoBar(
        context,
        builder: (ctx, close) {
          return const InfoBar(
            title: Text('History disabled'),
          );
        },
        duration: const Duration(milliseconds: 1400),
      );
    }
  }

  Future<void> onShortcutCopyToThirdParty() async {
    final lastMessage = messages.value.values.last;
    Pasteboard.writeText(lastMessage.content);
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

  Future onDigitPressed(int number) async {
    if (_quickInputCommandsList.isEmpty) return;
    final selectedPrompt = _quickInputCommandsList[number - 1];
    if (selectedPrompt[0] == '/') {
      ChatProvider.messageControllerGlobal.text = '$selectedPrompt ';
    } else {
      var findedCustomPrompt = promptsLibrary.firstWhereOrNull(
        (element) => element.title == selectedPrompt,
      );
      findedCustomPrompt ??= customPrompts.value.firstWhereOrNull(
        (element) => element.title == selectedPrompt,
      );
      if (findedCustomPrompt != null) {
        final isContainsPlaceHolder =
            placeholdersRegex.hasMatch(findedCustomPrompt.getPromptText());
        if (isContainsPlaceHolder) {
          final newText = await showDialog<String>(
            context: context,
            builder: (context) => ReplaceAllPlaceHoldersDialog(
              originalText: findedCustomPrompt!.getPromptText(),
            ),
          );
          if (newText != null) {
            ChatProvider.messageControllerGlobal.text = newText;
          }
        } else {
          ChatProvider.messageControllerGlobal.text =
              '${findedCustomPrompt.getPromptText()} ';
        }
      }
    }
    removeInputFieldQuickCommandsOverlay();
    promptTextFocusNode.requestFocus();
  }

  bool _isShiftPressed = false;
  bool _useShimmer = false;

  final debouncer = Debouncer(milliseconds: 500);

  @override
  Widget build(BuildContext context) {
    final ChatProvider chatProvider = context.watch<ChatProvider>();
    final totalTokens = chatProvider.totalTokensForCurrentChat.value;

    return CallbackShortcuts(
      bindings: {
        if (Platform.isMacOS) ...{
          const SingleActivator(LogicalKeyboardKey.keyU, alt: true): () =>
              onShortcutPasteSilently(FluentChatMessageType.textHuman),
          const SingleActivator(LogicalKeyboardKey.keyI, alt: true): () =>
              onShortcutPasteSilently(FluentChatMessageType.textAi),
          const SingleActivator(LogicalKeyboardKey.keyV, meta: true):
              onShortcutPasteToField,

          const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
              onShortcutSearchPressed,
          // digits
          SingleActivator(LogicalKeyboardKey.digit1, meta: true): () =>
              onDigitPressed(1),
          SingleActivator(LogicalKeyboardKey.digit2, meta: true): () =>
              onDigitPressed(2),
          SingleActivator(LogicalKeyboardKey.digit3, meta: true): () =>
              onDigitPressed(3),
          SingleActivator(LogicalKeyboardKey.digit4, meta: true): () =>
              onDigitPressed(4),
          SingleActivator(LogicalKeyboardKey.digit5, meta: true): () =>
              onDigitPressed(5),
          SingleActivator(LogicalKeyboardKey.digit6, meta: true): () =>
              onDigitPressed(6),
          SingleActivator(LogicalKeyboardKey.digit7, meta: true): () =>
              onDigitPressed(7),
          SingleActivator(LogicalKeyboardKey.digit8, meta: true): () =>
              onDigitPressed(8),
          SingleActivator(LogicalKeyboardKey.digit9, meta: true): () =>
              onDigitPressed(9),
          SingleActivator(LogicalKeyboardKey.keyH, meta: true):
              toggleEnableHistory,
        } else ...{
          const SingleActivator(LogicalKeyboardKey.keyU, alt: true): () =>
              onShortcutPasteSilently(FluentChatMessageType.textHuman),
          const SingleActivator(LogicalKeyboardKey.keyI, alt: true): () =>
              onShortcutPasteSilently(FluentChatMessageType.textAi),
          const SingleActivator(LogicalKeyboardKey.keyV, control: true):
              onShortcutPasteToField,
          const SingleActivator(LogicalKeyboardKey.keyF, control: true):
              onShortcutSearchPressed,
          // digits
          SingleActivator(LogicalKeyboardKey.digit1, control: true): () =>
              onDigitPressed(1),
          SingleActivator(LogicalKeyboardKey.digit2, control: true): () =>
              onDigitPressed(2),
          SingleActivator(LogicalKeyboardKey.digit3, control: true): () =>
              onDigitPressed(3),
          SingleActivator(LogicalKeyboardKey.digit4, control: true): () =>
              onDigitPressed(4),
          SingleActivator(LogicalKeyboardKey.digit5, control: true): () =>
              onDigitPressed(5),
          SingleActivator(LogicalKeyboardKey.digit6, control: true): () =>
              onDigitPressed(6),
          SingleActivator(LogicalKeyboardKey.digit7, control: true): () =>
              onDigitPressed(7),
          SingleActivator(LogicalKeyboardKey.digit8, control: true): () =>
              onDigitPressed(8),
          SingleActivator(LogicalKeyboardKey.digit9, control: true): () =>
              onDigitPressed(9),
          SingleActivator(LogicalKeyboardKey.keyH, control: true):
              toggleEnableHistory,
        },
        const SingleActivator(LogicalKeyboardKey.enter, meta: true):
            onShortcutCopyToThirdParty,
        const SingleActivator(LogicalKeyboardKey.arrowUp, meta: true): () {},
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            StreamBuilder(
              stream: altPressedStream,
              builder: (_, snap) {
                final isAltPressed = snap.data == true;
                if (isAltPressed) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 12.0),
                    child: Text(
                      'alt+enter: as System; alt+u: as User; alt+i: as AI',
                      style: context.theme.typography.caption,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
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
                  onSubmitted: (value) => onSubmit(value, chatProvider),
                  placeholder: 'Use "/" for commands or type your message here',
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
                          focusNode: promptTextFocusNode,
                          prefixMode: OverlayVisibilityMode.always,
                          controller: chatProvider.messageController,
                          minLines: 2,
                          maxLines: 30,
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
                          onSubmitted: (value) => onSubmit(value, chatProvider),
                          placeholder:
                              'Use "/" for commands or type your message here',
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  if (_isShiftPressed)
                    const Icon(ic.FluentIcons.arrow_up_12_filled),
                  const SizedBox(width: 4),
                  if (chatProvider.isAnswering)
                    SizedBox.square(
                      dimension: 52,
                      child: IconButton(
                        style: ButtonStyle(
                            backgroundColor: WidgetStatePropertyAll(
                          context.theme.scaffoldBackgroundColor,
                        )),
                        onPressed: () => chatProvider.stopAnswering(StopReason.canceled),
                        icon: Icon(
                          ic.FluentIcons.stop_24_filled,
                          size: 24,
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
            if (!widget.isMini &&
                totalTokens >= 0.8 * selectedChatRoom.maxTokenLength)
              Align(
                alignment: Alignment.centerLeft,
                child: GestureDetector(
                  onTap: chatProvider.scrollToLastOverflowMessage,
                  child: Text(
                    '${(totalTokens / selectedChatRoom.maxTokenLength * 100).toStringAsFixed(0)}% overflow. Click here to go to the last overflow message',
                    style: context.theme.typography.caption?.copyWith(
                      color: context.theme.typography.caption?.color
                          ?.withOpacity(0.5),
                    ),
                  ),
                ),
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
      final text = controller.text.trim();
      return MenuFlyout(
        items: [
          if (text.isNotEmpty)
            MenuFlyoutItem(
                text: const Text('Send silently as assistant'),
                trailing: Text('(alt+enter)'),
                onPressed: () {
                  provider.addMessageSystem(controller.text);
                  clearFieldAndFocus();
                }),
          if (text.isNotEmpty)
            MenuFlyoutItem(
                text: const Text('Send silently as user'),
                trailing: Text('(alt+u)'),
                onPressed: () async {
                  final timestamp = DateTime.now().millisecondsSinceEpoch;
                  provider.addHumanMessageToList(
                    FluentChatMessage.humanText(
                        id: timestamp.toString(),
                        content: controller.text,
                        creator: AppCache.userName.value ?? 'User',
                        timestamp: timestamp,
                        tokens: await provider.countTokensString(text)),
                  );
                  clearFieldAndFocus();
                }),
          if (text.isNotEmpty)
            MenuFlyoutItem(
                text: Text(
                    'Send silently as ${selectedChatRoom.characterName.toUpperCase()} answer'),
                trailing: Text('(alt+i)'),
                onPressed: () async {
                  final timestamp = DateTime.now().millisecondsSinceEpoch;
                  provider.addBotMessageToList(
                    FluentChatMessage.ai(
                      id: timestamp.toString(),
                      content: controller.text,
                      timestamp: timestamp,
                      tokens: await provider.countTokensString(text),
                    ),
                  );
                  clearFieldAndFocus();
                  provider.onResponseEnd(controller.text, '$timestamp');
                }),
          MenuFlyoutSeparator(),
          if (text.isNotEmpty)
            MenuFlyoutItem(
              text: const Text(
                  'Send not in real-time (can help with some LLM providers)'),
              onPressed: () {
                provider.sendMessage(controller.text,
                    hidePrompt: false, sendStream: false);
                clearFieldAndFocus();
              },
            )
        ],
      );
    });
  }

  void onTextChangedListener() {
    final text = ChatProvider.messageControllerGlobal.text;
    if (text.isEmpty) {
      removeInputFieldQuickCommandsOverlay();
      return;
    }

    if (text[0] == '/' && aliasesCommandsOverlay == null) {
      // show overlay
      aliasesCommandsOverlay = OverlayEntry(
        builder: (context) => AliasesOverlay(),
        opaque: false,
      );
      Overlay.of(context).insert(aliasesCommandsOverlay!);
      return;
    }
    if (aliasesCommandsOverlay != null && text[0] != '/') {
      removeInputFieldQuickCommandsOverlay();
      return;
    }
  }

  onShortcutPasteSilently(FluentChatMessageType messageType) async {
    final provider = context.read<ChatProvider>();
    final message = provider.messageController.text;
    if (message.isEmpty) return;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fMessage = FluentChatMessage(
      id: timestamp.toString(),
      type: messageType,
      content: message,
      creator: messageType == FluentChatMessageType.textHuman
          ? AppCache.userName.value ?? 'User'
          : selectedChatRoom.characterName,
      timestamp: timestamp,
      tokens: await provider.countTokensString(message),
    );
    provider.addHumanMessageToList(fMessage);
    provider.messageController.clear();
    promptTextFocusNode.requestFocus();
  }
}

OverlayEntry? aliasesCommandsOverlay;
List<String> _quickInputCommandsList = [
  // ...AliasesOverlay.quickInputDefaultCommands,
];
void removeInputFieldQuickCommandsOverlay() {
  if (aliasesCommandsOverlay != null) {
    _quickInputCommandsList.clear();
    aliasesCommandsOverlay!.remove();
    aliasesCommandsOverlay!.dispose();
    aliasesCommandsOverlay = null;
  }
}

class AliasesOverlay extends StatefulWidget {
  const AliasesOverlay({super.key});
  static List<String> quickInputDefaultCommands = [
    '/settings',
    '/${TrayCommand.generate_dalle_image.name}',
  ];
  @override
  State<AliasesOverlay> createState() => _AliasesOverlayState();
}

class _AliasesOverlayState extends State<AliasesOverlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ChatProvider.messageControllerGlobal.addListener(onTextChangedListener);
      escPressedStream.listen(onEscPressedListener);
      loadAllCommands();
    });
  }

  void onEscPressedListener(bool isPressed) {
    if (isPressed) {
      removeInputFieldQuickCommandsOverlay();
    }
  }

  void loadAllCommands() {
    final allPrompts = promptsLibrary.map((e) => e.title).toList();
    final allCustomPrompts = customPrompts.value.map((e) => e.title).toList();
    quickInputAllCommands.clear();
    quickInputAllCommands.addAll(AliasesOverlay.quickInputDefaultCommands);
    quickInputAllCommands.addAll(allCustomPrompts);
    quickInputAllCommands.addAll(allPrompts);
    _quickInputCommandsList.addAll(quickInputAllCommands);
    setState(() {});
  }

  @override
  void dispose() {
    ChatProvider.messageControllerGlobal.removeListener(onTextChangedListener);
    super.dispose();
  }

  void onTextChangedListener() {
    final text = ChatProvider.messageControllerGlobal.text;
    if (text.isEmpty) {
      return;
    }
    _quickInputCommandsList.clear();
    if (text.length == 1 && text[0] == '/') {
      _quickInputCommandsList.clear();
      loadAllCommands();
      return;
    }
    final clearTextLowerCase = text.trim().toLowerCase().replaceAll('/', '');
    for (final command in quickInputAllCommands) {
      final clearTextWords = clearTextLowerCase.split(' ');
      for (final word in clearTextWords) {
        if (word.isEmpty) continue;
        if (command.toLowerCase().contains(word)) {
          _quickInputCommandsList.add(command);
          break;
        }
      }
    }
    if (_quickInputCommandsList.isNotEmpty) {
      setState(() {});
    }
  }

  List<String> quickInputAllCommands = [
    ...AliasesOverlay.quickInputDefaultCommands,
  ];

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 64,
      left: 60,
      right: 60,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 300),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: Acrylic(
          blurAmount: 10,
          tint: Colors.black,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Tooltip(
                      message: 'Close',
                      child: SizedBox(
                        child: Button(
                          onPressed: () {
                            _quickInputCommandsList.clear();
                            quickInputAllCommands.clear();
                            removeInputFieldQuickCommandsOverlay();
                          },
                          style: const ButtonStyle(
                            padding: WidgetStatePropertyAll(EdgeInsets.all(4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(ic.FluentIcons.arrow_down_16_filled,
                                  size: 16),
                              Text('[esc]'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Flexible(
                  fit: FlexFit.loose,
                  child: ListView.builder(
                    itemCount: _quickInputCommandsList.length,
                    shrinkWrap: true,
                    itemBuilder: (context, i) {
                      final command = _quickInputCommandsList[i];
                      bool isHovered = false;
                      return StatefulBuilder(
                        builder: (
                          BuildContext context,
                          void Function(void Function()) setState,
                        ) {
                          return MouseRegion(
                            onHover: (event) {
                              setState(() {
                                isHovered = true;
                              });
                            },
                            onExit: (event) {
                              setState(() {
                                isHovered = false;
                              });
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: BasicListTile(
                                title: Text(command),
                                color: isHovered
                                    ? context.theme.accentColor.withOpacity(0.2)
                                    : Colors.black.withOpacity(0.1),
                                padding: EdgeInsets.symmetric(
                                    vertical: 4, horizontal: 16),
                                onTap: () async {
                                  final isGlobalCommand = command[0] == '/';
                                  if (!isGlobalCommand) {
                                    var prompt =
                                        promptsLibrary.firstWhereOrNull(
                                      (element) => element.title == command,
                                    );
                                    prompt ??=
                                        customPrompts.value.firstWhereOrNull(
                                      (element) => element.title == command,
                                    );
                                    if (prompt == null) return;
                                    final isContainsPlaceHolder =
                                        placeholdersRegex
                                            .hasMatch(prompt.getPromptText());
                                    if (isContainsPlaceHolder) {
                                      final newText = await showDialog<String>(
                                        context: context,
                                        builder: (context) =>
                                            ReplaceAllPlaceHoldersDialog(
                                          originalText: prompt!.getPromptText(),
                                        ),
                                      );
                                      if (newText != null) {
                                        ChatProvider.messageControllerGlobal
                                            .text = newText;
                                      }
                                    } else {
                                      ChatProvider.messageControllerGlobal
                                          .text = '${prompt.getPromptText()} ';
                                    }
                                    removeInputFieldQuickCommandsOverlay();
                                    promptTextFocusNode.requestFocus();
                                    return;
                                  }
                                  if (command == '/settings') {
                                    Navigator.of(context).push(
                                      FluentPageRoute(
                                        builder: (context) =>
                                            const SettingsPage(),
                                      ),
                                    );
                                  } else {
                                    ChatProvider.messageControllerGlobal.text =
                                        '$command ';
                                    promptTextFocusNode.requestFocus();
                                    removeInputFieldQuickCommandsOverlay();
                                  }
                                },
                                trailing: i < 9
                                    ? Button(
                                        onPressed: null,
                                        focusable: false,
                                        child: Platform.isMacOS
                                            ? Text('⌘${i + 1}')
                                            : Text('[ctrl+${i + 1}]'),
                                      )
                                    : null,
                              ),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MicrophoneButton extends StatefulWidget {
  const _MicrophoneButton({super.key});

  @override
  State<_MicrophoneButton> createState() => __MicrophoneButtonState();
}

class __MicrophoneButtonState extends State<_MicrophoneButton> {
  Future<bool> checkPermission() async {
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
    PushToTalkTool.isRecording = true;
    // ignore: use_build_context_synchronously
    final provider = context.read<ChatProvider>();
    final resultStart = await provider.startListeningForInput();
    if (!resultStart) {
      PushToTalkTool.isRecording = false;
    }
  }

  void stopRecording() {
    PushToTalkTool.isRecording = false;
    final provider = context.read<ChatProvider>();
    provider.stopListeningForInput();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Object>(
        stream: PushToTalkTool.isRecordingStream,
        builder: (context, _) {
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Container(
              width: 42,
              height: 30,
              margin: const EdgeInsets.only(right: 4),
              child: ToggleButtonAdvenced(
                onChanged: (v) {
                  if (PushToTalkTool.isRecording) {
                    stopRecording();
                  } else {
                    startRecording();
                  }
                },
                contextItems: [
                  for (final locale in gptLocales)
                    FlyoutListTile(
                      text: Text(locale.languageCode),
                      selected:
                          AppCache.speechLanguage.value == locale.languageCode,
                      onPressed: () {
                        AppCache.speechLanguage.value = locale.languageCode;
                        setState(() {});
                        Navigator.of(context).pop();
                      },
                    ),
                ],
                maxWidthContextMenu: 84,
                checked: PushToTalkTool.isRecording,
                padding: EdgeInsets.zero,
                icon: ic.FluentIcons.mic_24_regular,
                tooltip: 'Use voice input',
              ),
            ),
          );
        });
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
    final models = allModels.value;
    return Focus(
      canRequestFocus: false,
      descendantsAreTraversable: false,
      child: FlyoutTarget(
        controller: flyoutController,
        child: Listener(
          onPointerDown: (_) => openFlyout(context),
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              if (event.scrollDelta.dy > 0) {
                final selectedModel = selectedChatRoom.model;
                final index = models.indexOf(selectedModel);
                if (index < models.length - 1) {
                  final model = models[index + 1];
                  provider.selectNewModel(model);
                  displayTextInfoBar('Model changed to ${model.customName}');
                }
              } else {
                final models = allModels.value;
                final selectedModel = selectedChatRoom.model;
                final index = models.indexOf(selectedModel);
                if (index > 0) {
                  final model = models[index - 1];
                  provider.selectNewModel(model);
                  displayTextInfoBar('Model changed to ${model.customName}');
                }
              }
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: FluentTheme.of(context).cardColor,
              borderRadius: BorderRadius.circular(4),
            ),
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(left: 8),
            padding: const EdgeInsets.all(2),
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
      return StatefulBuilder(
        builder: (_, setState) => MenuFlyout(
          items: [
            ...List.generate(models.length, (i) {
              final e = models[i];
              return MenuFlyoutItem(
                selected: e.modelName == selectedModel.modelName,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (e.modelName == selectedModel.modelName)
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: const Icon(ic.FluentIcons.checkmark_16_filled),
                      ),
                    SqueareIconButton(
                      onTap: () async {
                        Navigator.of(ctx).pop();

                        final changedModel = await showDialog<ChatModelAi>(
                          context: context,
                          builder: (context) =>
                              AddAiModelDialog(initialModel: e),
                        );
                        if (changedModel != null) {
                          provider.removeCustomModel(e);
                          await provider.addNewCustomModel(changedModel);
                          await Future.delayed(
                              const Duration(milliseconds: 100));
                          provider.selectNewModel(changedModel);
                        }
                      },
                      icon: Icon(ic.FluentIcons.edit_16_regular),
                      tooltip: 'Edit',
                    ),
                    const SizedBox(width: 4),
                    if (i != 0)
                      SqueareIconButton(
                        onTap: () async {
                          // move this item 1 element up
                          final index = models.indexOf(e);
                          final previous = models[index - 1];
                          models[index - 1] = e;
                          models[index] = previous;
                          allModels.value = models;
                          setState(() {});
                        },
                        icon: Icon(ic.FluentIcons.arrow_up_12_regular),
                        tooltip: 'Move up',
                      ),
                  ],
                ),
                leading: SizedBox.square(dimension: 24, child: e.modelIcon),
                text: Text(e.customName),
                onPressed: () => provider.selectNewModel(e),
              );
            }),
            const MenuFlyoutSeparator(),
            MenuFlyoutItem(
              leading: const Icon(ic.FluentIcons.edit_16_regular),
              text: const Text('Edit'),
              onPressed: () {
                Navigator.of(ctx).pop();
                showDialog(
                    context: context, builder: (ctx) => ModelsListDialog());
              },
            ),
          ],
        ),
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
    return Tooltip(
      message: 'Supports jpeg, png, docx, xlsx, txt, csv',
      child: SizedBox.square(
        dimension: isMini ? 30 : 48,
        child: IconButton(
          onPressed: () async {
            FilePickerResult? result = await FilePicker.platform.pickFiles(
              allowedExtensions: [
                'jpg',
                'jpeg',
                'png',
                'docx',
                'xlsx',
                'txt',
                'csv',
              ],
              type: FileType.custom,
            );
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
        fit: StackFit.expand,
        children: [
          Positioned(
            top: 0,
            right: 0,
            left: 0,
            child: IconButton(
              onPressed: () async {
                if (chatProvider.isSendingFile) {
                  return;
                }
                FilePickerResult? result =
                    await FilePicker.platform.pickFiles();
                if (result != null && result.files.isNotEmpty) {
                  chatProvider.addFileToInput(result.files.first.toXFile());
                  windowManager.focus();
                  promptTextFocusNode.requestFocus();
                }
              },
              icon: const Icon(ic.FluentIcons.document_number_1_16_regular,
                  size: 24),
            ),
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
            )
          else if (chatProvider.fileInput!.name.isNotEmpty)
            Positioned.fill(
              top: 28,
              right: 0,
              left: 0,
              child: Tooltip(
                message: chatProvider.fileInput!.name.isEmpty
                    ? '-'
                    : chatProvider.fileInput!.name,
                child: Text(
                  chatProvider.fileInput!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
                  ToggleButtonAdvenced(
                    icon: ic.FluentIcons.settings_20_regular,
                    onChanged: (_) => showDialog(
                      context: context,
                      builder: (ctx) => const CustomPromptsSettingsDialog(),
                    ),
                    tooltip: 'Customize custom promtps',
                  ),
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
