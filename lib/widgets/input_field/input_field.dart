import 'dart:async';
import 'dart:math';

import 'package:cross_file/cross_file.dart';

import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/common/debouncer.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/common/prompts_templates.dart';
import 'package:fluent_gpt/dialogs/ai_prompts_library_dialog.dart';
import 'package:fluent_gpt/dialogs/search_chat_dialog.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/pages/home_page.dart';
import 'package:fluent_gpt/widgets/input_field/additional_btns_input_field.dart';
import 'package:fluent_gpt/widgets/input_field/aliases_overlay.dart';
import 'package:fluent_gpt/widgets/input_field/input_field_main.dart';
import 'package:fluent_gpt/widgets/input_field/input_field_mini.dart';
import 'package:fluent_gpt/widgets/input_field/input_field_shortcuts_activator.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
// ignore: unused_import
import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';
import 'package:mime_type/mime_type.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';

import '../../providers/chat_provider.dart';

final promptTextFocusNode = FocusNode();

class InputField extends StatefulWidget {
  const InputField({super.key, this.isMini = false});
  final bool isMini;

  @override
  State<InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<InputField> {
  Future<void> onSubmit(String text) async {
    final chatProvider = context.read<ChatProvider>();
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

    if (text.trim().isEmpty && chatProvider.fileInputs.isEmpty) {
      return;
    }

    chatProvider.sendMessage(text.trim());
    clearFieldAndFocus();
  }

  void clearFieldAndFocus() {
    ChatProvider.messageControllerGlobal.clear();
    promptTextFocusNode.requestFocus();
  }

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

  void onShortcutPasteImage(Uint8List? image) async {
    if (image == null) return;

    final chatProvider = context.read<ChatProvider>();
    // final imageFilePng = await image.toPNG();
    // final base64 = await imageFilePng.imageToBase64();
    chatProvider.addAttachmentAiLens(image);
  }

  Future<void> onShortcutPasteToField() async {
    final chatProvider = context.read<ChatProvider>();

    final files = await Pasteboard.files();
    if (files.isNotEmpty) {
      final listXFiles = <XFile>[];
      for (var file in files) {
        final filePath = file;
        final xfile = XFile(
          filePath,
          mimeType: mime(filePath) ?? 'application/octet-stream',
          name: filePath.split('/').last,
        );
        listXFiles.add(xfile);
      }
      chatProvider.addFilesToInput(listXFiles);
      listXFiles.clear();
      return;
    }
    final text = await Pasteboard.text;
    if (text != null) {
      return onShortcutPasteText(text);
    }
    final image = await Pasteboard.image;

    if (image != null) {
      return onShortcutPasteImage(image);
    }
  }

  Future<void> arrowUpPressed() async {
    // Get the current text editing controller and selection
    final chatProvider = context.read<ChatProvider>();
    final controller = chatProvider.messageController;
    final selection = controller.selection;

    // If the caret is at the very start (offset 0), move focus to previous focusable widget
    if (selection.baseOffset == 0 && selection.extentOffset == 0) {
      // Move focus to previous focusable widget in the focus tree
      // FocusScope.of(context).requestFocus(messagesFocusScopeNode);
      FocusScope.of(context).unfocus();
      await Future.delayed(Duration(milliseconds: 5));
      // ignore: use_build_context_synchronously
      FocusScope.of(context).requestFocus(messagesFocusScopeNode);
      return;
    }

    // Otherwise, move the caret up one line (like in a multiline textbox)
    final text = controller.text;
    final offset = selection.baseOffset;

    // Find the position of the previous newline before the caret
    final prevNewline = text.lastIndexOf('\n', offset - 1);

    if (prevNewline == -1) {
      // If there is no previous line, move caret to start
      controller.selection = TextSelection.collapsed(offset: 0);
      return;
    }

    // Calculate the column (caret position in the current line)
    final currentLineStart = text.lastIndexOf('\n', offset - 1) + 1;
    final column = offset - currentLineStart;

    // Find the start of the previous line
    final prevLineStart = text.lastIndexOf('\n', prevNewline - 1) + 1;
    final prevLineEnd = prevNewline;

    // Calculate the offset for the caret in the previous line
    final prevLineLength = prevLineEnd - prevLineStart;
    final newOffset = prevLineStart + (column > prevLineLength ? prevLineLength : column);

    controller.selection = TextSelection.collapsed(offset: newOffset);
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

  final debouncer = Debouncer(milliseconds: 500);
 

  @override
  Widget build(BuildContext context) {
    final ChatProvider chatProvider = context.watch<ChatProvider>();
    final totalTokens = chatProvider.totalTokensByMessages;

    return CallbackShortcuts(
      bindings: InputFieldShortcutsActivator.bindings(
        onShortcutPasteSilently,
        onShortcutPasteToField,
        onShortcutSearchPressed,
        onDigitPressed,
        arrowUpPressed,
        onShortcutCopyToThirdParty,
      ),
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
            if (chatProvider.fileInputs.isNotEmpty) FileThumbnails(),
            if (widget.isMini) InputFieldMini(onSubmit: onSubmit),
            if (!widget.isMini)
              InputFieldMain(
                onSubmit: onSubmit,
                onSecondaryTap: _onSecondaryTap,
                menuController: menuController,
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
    final text = controller.text.trim();
    if (text.isEmpty && provider.fileInputs.isEmpty == true) return;
    menuController.showFlyout(builder: (ctx) {
      return MenuFlyout(
        items: [
          MenuFlyoutItem(
              text: Text('Add to chat as SYSTEM'.tr),
              trailing: Text('(alt+enter)'),
              onPressed: () async {
                if (text.isNotEmpty)
                  provider.addCustomMessageToList(
                    FluentChatMessage.system(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      content: controller.text,
                      timestamp: DateTime.now().millisecondsSinceEpoch,
                      tokens: await provider.countTokensString(text),
                    ),
                  );
                if (provider.fileInputs.isNotEmpty == true) {
                  await provider.sendAllAttachmentsToChatSilently();
                }
                clearFieldAndFocus();
              }),
          MenuFlyoutItem(
              text: Text('Add to chat as USER'.tr),
              trailing: Text('(alt+u)'),
              onPressed: () async {
                final timestamp = DateTime.now().millisecondsSinceEpoch;
                if (text.isNotEmpty)
                  provider.addHumanMessageToList(
                    FluentChatMessage.humanText(
                        id: timestamp.toString(),
                        content: controller.text,
                        creator: AppCache.userName.value ?? 'User',
                        timestamp: timestamp,
                        tokens: await provider.countTokensString(text)),
                  );
                if (provider.fileInputs.isNotEmpty == true) {
                  await provider.sendAllAttachmentsToChatSilently();
                }
                clearFieldAndFocus();
              }),
          MenuFlyoutItem(
              text:
                  Text('Add to chat as {name}'.tr.replaceAll('{{name}}', selectedChatRoom.characterName.toUpperCase())),
              trailing: Text('(alt+i)'),
              onPressed: () async {
                final timestamp = DateTime.now().millisecondsSinceEpoch;
                if (text.isNotEmpty)
                  provider.addBotMessageToList(
                    FluentChatMessage.ai(
                      id: timestamp.toString(),
                      content: controller.text,
                      timestamp: timestamp,
                      tokens: await provider.countTokensString(text),
                    ),
                  );
                if (provider.fileInputs.isNotEmpty == true) {
                  await provider.sendAllAttachmentsToChatSilently();
                }
                clearFieldAndFocus();
                if (text.isNotEmpty) provider.onResponseEnd(controller.text, '$timestamp');
              }),
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

  Future<void> onShortcutPasteSilently(FluentChatMessageType messageType) async {
    final provider = context.read<ChatProvider>();
    final message = provider.messageController.text;
    if (provider.fileInputs.isNotEmpty == true) {
      await provider.sendAllAttachmentsToChatSilently();
    }
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

class ContextUsageRing extends StatelessWidget {
  const ContextUsageRing({
    required this.totalTokens,
    required this.maxTokenLength,
    required this.onTap,
  });

  final int totalTokens;
  final int maxTokenLength;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final maxLen = maxTokenLength <= 0 ? 1 : maxTokenLength;
    final ratio = totalTokens / maxLen;
    final percentStr = (ratio * 100).toStringAsFixed(0);
    final tooltipMessage = '$percentStr${'% overflow. Click here to go to the last visible to AI message'.tr}';

    final captionColor = FluentTheme.of(context).typography.caption?.color;
    final base = captionColor ?? const Color(0xFFB3B3B3);
    final trackColor = base.withAlpha(70);
    final progressColor = ratio > 1.0 ? FluentTheme.of(context).accentColor : base.withAlpha(230);

    return Tooltip(
      message: tooltipMessage,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: SizedBox(
            width: 16,
            height: 16,
            child: CustomPaint(
              painter: ContextUsageRingPainter(
                progress: ratio,
                trackColor: trackColor,
                progressColor: progressColor,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ContextUsageRingPainter extends CustomPainter {
  ContextUsageRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;

  static const double _strokeWidth = 1.6;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (min(size.width, size.height) - _strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..isAntiAlias = true;

    canvas.drawCircle(center, radius, trackPaint);

    final sweep = 2 * pi * progress.clamp(0.0, 1.0);
    if (sweep <= 0) return;

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, -pi / 2, sweep, false, progressPaint);
  }

  @override
  bool shouldRepaint(covariant ContextUsageRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor;
  }
}
