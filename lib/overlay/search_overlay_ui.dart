import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/common/prompts_templates.dart';
import 'package:fluent_gpt/dialogs/ai_prompts_library_dialog.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/pages/home_page.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/theme.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/drop_region.dart';
import 'package:fluent_gpt/widgets/input_field.dart';
import 'package:fluent_gpt/widgets/markdown_builders/code_wrapper.dart';
import 'package:fluent_gpt/widgets/message_list_tile.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as ic;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:provider/provider.dart';
import 'package:widget_and_text_animator/widget_and_text_animator.dart';
import 'package:window_manager/window_manager.dart';

class SearchOverlayUI extends StatefulWidget {
  const SearchOverlayUI({super.key});

  static Size defaultWindowSize() {
    return Size(800, 200);
  }

  @override
  State<SearchOverlayUI> createState() => _OverlayUIState();
}

class _OverlayUIState extends State<SearchOverlayUI> {
  StreamSubscription<bool>? listener;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      FocusScope.of(context).unfocus(disposition: UnfocusDisposition.scope);
      await windowManager.focus();
      promptTextFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    promptTextFocusNode.unfocus();
    listener?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = context.read<AppTheme>();
    final backgroundColor = appTheme.isDark ? appTheme.darkBackgroundColor : appTheme.lightBackgroundColor;
    return CallbackShortcuts(
      bindings: {
        /// esc
        LogicalKeySet(LogicalKeyboardKey.escape): () {
          // if can't go back, close overlay
          if (Navigator.maybeOf(context)?.canPop() == false) {
            hideWindow();
          }
        },
      },
      child: Stack(
        alignment: Alignment.topCenter,
        fit: StackFit.expand,
        children: [
          SizedBox.expand(
            child: GestureDetector(
              onPanStart: (v) => WindowManager.instance.startDragging(),
              child: ColoredBox(
                color: backgroundColor,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const ChooseModelButton(),
                        const SizedBox(width: 4),
                        SqueareIconButtonSized(
                          onTap: () {
                            onTrayButtonTapCommand('', TrayCommand.create_new_chat.name);
                            windowManager.setSize(
                              SearchOverlayUI.defaultWindowSize(),
                              animate: true,
                            );
                          },
                          icon: const Icon(ic.FluentIcons.chat_add_32_regular),
                          tooltip: 'Create new chat'.tr,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: _InputField(),
                        ),
                        const AddFileButton(),
                        Container(
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: const BoxDecoration(
                            color: Colors.grey,
                            borderRadius: BorderRadius.all(Radius.circular(4)),
                          ),
                          width: 4,
                        ),
                        SqueareIconButtonSized(
                          onTap: () => OverlayManager.switchToMainWindow(),
                          icon: const Icon(ic.FluentIcons.open_20_regular),
                          tooltip: 'Open main app',
                        ),
                        const SizedBox(width: 8),
                      ],
                    ),
                    const ToggleButtonsRow(),
                    // const HotShurtcutsOneLineWidget(),
                    const Expanded(
                      child: _MessagesList(),
                    ),
                    const SizedBox(
                      width: double.infinity,
                      child: _LoadingIndicator(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const HomeDropOverlay(),
          const HomeDropRegion(showAiLens: false),
        ],
      ),
    );
  }
}

class _InputField extends StatefulWidget {
  const _InputField();

  @override
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      ChatProvider.messageControllerGlobal.addListener(onTextChangedListener);
    });
  }

  @override
  void dispose() {
    promptTextFocusNode.unfocus();
    ChatProvider.messageControllerGlobal.removeListener(onTextChangedListener);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.read<ChatProvider>();
    return CallbackShortcuts(
      bindings: {
        if (Platform.isMacOS) ...{
          const SingleActivator(LogicalKeyboardKey.keyU, alt: true): () =>
              onShortcutPasteSilently(FluentChatMessageType.textHuman),
          const SingleActivator(LogicalKeyboardKey.keyI, alt: true): () =>
              onShortcutPasteSilently(FluentChatMessageType.textAi),
          const SingleActivator(LogicalKeyboardKey.keyV, meta: true): onShortcutPasteToField,
          // digits
          SingleActivator(LogicalKeyboardKey.digit1, meta: true): () => onDigitPressed(1),
          SingleActivator(LogicalKeyboardKey.digit2, meta: true): () => onDigitPressed(2),
          SingleActivator(LogicalKeyboardKey.digit3, meta: true): () => onDigitPressed(3),
          SingleActivator(LogicalKeyboardKey.digit4, meta: true): () => onDigitPressed(4),
          SingleActivator(LogicalKeyboardKey.digit5, meta: true): () => onDigitPressed(5),
          SingleActivator(LogicalKeyboardKey.digit6, meta: true): () => onDigitPressed(6),
          SingleActivator(LogicalKeyboardKey.digit7, meta: true): () => onDigitPressed(7),
          SingleActivator(LogicalKeyboardKey.digit8, meta: true): () => onDigitPressed(8),
          SingleActivator(LogicalKeyboardKey.digit9, meta: true): () => onDigitPressed(9),
          SingleActivator(LogicalKeyboardKey.keyH, meta: true): toggleEnableHistory,
        } else ...{
          const SingleActivator(LogicalKeyboardKey.keyU, alt: true): () =>
              onShortcutPasteSilently(FluentChatMessageType.textHuman),
          const SingleActivator(LogicalKeyboardKey.keyI, alt: true): () =>
              onShortcutPasteSilently(FluentChatMessageType.textAi),
          const SingleActivator(LogicalKeyboardKey.keyV, control: true): onShortcutPasteToField,
          // digits
          SingleActivator(LogicalKeyboardKey.digit1, control: true): () => onDigitPressed(1),
          SingleActivator(LogicalKeyboardKey.digit2, control: true): () => onDigitPressed(2),
          SingleActivator(LogicalKeyboardKey.digit3, control: true): () => onDigitPressed(3),
          SingleActivator(LogicalKeyboardKey.digit4, control: true): () => onDigitPressed(4),
          SingleActivator(LogicalKeyboardKey.digit5, control: true): () => onDigitPressed(5),
          SingleActivator(LogicalKeyboardKey.digit6, control: true): () => onDigitPressed(6),
          SingleActivator(LogicalKeyboardKey.digit7, control: true): () => onDigitPressed(7),
          SingleActivator(LogicalKeyboardKey.digit8, control: true): () => onDigitPressed(8),
          SingleActivator(LogicalKeyboardKey.digit9, control: true): () => onDigitPressed(9),
          SingleActivator(LogicalKeyboardKey.keyH, control: true): toggleEnableHistory,
        },
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): onShortcutCopyToThirdParty,
        const SingleActivator(LogicalKeyboardKey.arrowUp, meta: true): () {},
      },
      child: TextBox(
        focusNode: promptTextFocusNode,
        minLines: 1,
        maxLines: 4,
        textInputAction: TextInputAction.send,
        suffix: const MicrophoneButton(),
        controller: chatProvider.messageController,
        style: TextStyle(fontSize: 24),
        placeholder: 'Type your message here'.tr,
        onSubmitted: (value) => onSubmit(value, chatProvider),
      ),
    );
  }

  Future<void> toggleEnableHistory() async {
    final provider = context.read<ChatProvider>();
    provider.setIncludeWholeConversation(!provider.includeConversationGlobal);
    if (provider.includeConversationGlobal) {
      displayTextInfoBar('History enabled'.tr);
    } else {
      displayTextInfoBar('History disabled'.tr);
    }
  }

  Future<void> onSubmit(String text, ChatProvider chatProvider) async {
    if (shiftPressedStream.valueOrNull == true) {
      final currentText = chatProvider.messageController.text;
      final selection = chatProvider.messageController.selection;
      final cursorPosition = selection.baseOffset;

      if (cursorPosition >= 0 && cursorPosition <= currentText.length) {
        // Insert newline at cursor position
        final newText = '${currentText.substring(0, cursorPosition)}\n${currentText.substring(cursorPosition)}';
        chatProvider.messageController.text = newText;
        // Place cursor after the inserted newline
        chatProvider.messageController.selection = TextSelection.collapsed(offset: cursorPosition + 1);
      } else {
        // Fallback if cursor position is invalid
        chatProvider.messageController.text = '$currentText\n';
      }

      promptTextFocusNode.requestFocus();
      return;
    }

    if (altPressedStream.value) {
      chatProvider.addCustomMessageToList(
        FluentChatMessage.system(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          content: chatProvider.messageController.text,
          timestamp: DateTime.now().millisecondsSinceEpoch,
          tokens: await chatProvider.countTokensString(text),
        ),
      );

      clearFieldAndFocus();
      return;
    }

    if (text.trim().isEmpty && chatProvider.fileInputs == null) {
      return;
    }

    chatProvider.sendMessage(text.trim());
    clearFieldAndFocus();
  }

  void clearFieldAndFocus() {
    ChatProvider.messageControllerGlobal.clear();
    promptTextFocusNode.requestFocus();
  }

  Future onDigitPressed(int number) async {
    if (quickInputCommandsList.isEmpty) return;
    final selectedPrompt = quickInputCommandsList[number - 1];
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
        final isContainsPlaceHolder = placeholdersRegex.hasMatch(findedCustomPrompt.getPromptText());
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
          ChatProvider.messageControllerGlobal.text = '${findedCustomPrompt.getPromptText()} ';
        }
      }
    }
    removeInputFieldQuickCommandsOverlay();
    promptTextFocusNode.requestFocus();
  }

  Future<void> onShortcutCopyToThirdParty() async {
    final lastMessage = messages.value.values.last;
    Pasteboard.writeText(lastMessage.content);
    displayCopiedToClipboard();
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
          newText = currentText.substring(0, end) + clipboard + currentText.substring(start);
          newCursorPosition = end + clipboard.length;
        } else {
          newText = currentText.substring(0, start) + clipboard + currentText.substring(end);
          newCursorPosition = start + clipboard.length;
        }
      } else {
        // Handle cursor insertion safely
        final currentCursorPosition = max(0, min(textSelection.base.offset, currentText.length));
        newText =
            currentText.substring(0, currentCursorPosition) + clipboard + currentText.substring(currentCursorPosition);
        newCursorPosition = currentCursorPosition + clipboard.length;
      }

      chatProvider.messageController.text = newText;
      chatProvider.messageController.selection = TextSelection.collapsed(offset: newCursorPosition);

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

  void onShortcutPasteImage(Uint8List? image) async {
    if (image == null) return;

    final chatProvider = context.read<ChatProvider>();
    // final imageFilePng = await image.toPNG();
    // final base64 = await imageFilePng.imageToBase64();
    chatProvider.addAttachmentAiLens(image);
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

  void onShortcutPasteSilently(FluentChatMessageType messageType) async {
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

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 200),
      firstChild: const SizedBox.shrink(),
      secondChild: const SizedBox(
        width: double.infinity,
        child: Padding(
          padding: EdgeInsets.all(4.0),
          child: ProgressBar(strokeWidth: 8),
        ),
      ),
      crossFadeState: (chatProvider.isAnswering || chatProvider.isGeneratingImage)
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
    );
  }
}

class _MessagesList extends StatelessWidget {
  const _MessagesList();

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.read<ChatProvider>();
    return StreamBuilder(
      stream: messages,
      builder: (context, snapshot) {
        final reverseList = messagesReversedList;
        if (reverseList.isEmpty) {
          final randWelcome =
              OverlayManager.welcomesForEmptyList[Random().nextInt(OverlayManager.welcomesForEmptyList.length)];
          return Center(
            child: TextAnimator(
              randWelcome,
              initialDelay: Duration(milliseconds: 200),
              style: TextStyle(fontSize: 30),
              textAlign: TextAlign.center,
            ),
          );
        }
        return ListView.builder(
          controller: chatProvider.listItemsScrollController,
          itemCount: messages.value.entries.length,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          reverse: false,
          shrinkWrap: true,
          itemBuilder: (context, index) {
            final FluentChatMessage message = reverseList.elementAt(index);

            return MessageCard(
              message: message,
              selectionMode: false,
              textSize: AppCache.compactMessageTextSize.value!,
              isCompactMode: true,
              shouldBlink: chatProvider.blinkMessageId == message.id,
              indexMessage: index,
            );
          },
        );
      },
    );
  }
}
