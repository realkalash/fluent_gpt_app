import 'dart:math';

import 'package:fluent_gpt/common/attachment.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/theme.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:fluent_gpt/widgets/input_field/additional_btns_input_field.dart';
import 'package:fluent_gpt/widgets/input_field/input_field.dart';
import 'package:fluent_gpt/widgets/markdown_builders/code_wrapper.dart';
import 'package:fluent_gpt/widgets/message_list_tile.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as ic;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

/// Compact chat opened by a screen-region snip (Cmd+Shift+drag on macOS).
///
/// This is a *fresh* overlay rather than a reuse of the legacy tray [OverlayUI]:
/// it focuses its input via a post-frame callback (so it never hits the
/// `RenderEditable was not laid out` race the tray overlay has), and it shows
/// the captured screenshot + the source app/window context grabbed natively.
class RegionChatOverlayUI extends StatefulWidget {
  const RegionChatOverlayUI({super.key});

  static Size defaultWindowSize() => const Size(440, 560);

  @override
  State<RegionChatOverlayUI> createState() => _RegionChatOverlayUIState();
}

class _RegionChatOverlayUIState extends State<RegionChatOverlayUI> {
  @override
  void initState() {
    super.initState();
    // Post-frame focus: the widget tree is laid out before we touch the
    // focus node, so the input is ready to type into immediately.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      FocusScope.of(context).unfocus(disposition: UnfocusDisposition.scope);
      await windowManager.focus();
      if (!mounted) return;
      promptTextFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    promptTextFocusNode.unfocus();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = context.read<AppTheme>();
    final backgroundColor = appTheme.isDark ? appTheme.darkBackgroundColor : appTheme.lightBackgroundColor;
    return CallbackShortcuts(
      bindings: {
        LogicalKeySet(LogicalKeyboardKey.escape): () {
          if (Navigator.maybeOf(context)?.canPop() == false) {
            // Restore normal window geometry + reset overlay state so the next
            // plain "show window" opens the full app, not a stale region chat.
            OverlayManager.hideOverlay();
          }
        },
      },
      child: ColoredBox(
        color: backgroundColor,
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(),
            _AttachmentsRow(),
            _InputRow(),
            Expanded(child: _MessagesList()),
            SizedBox(width: double.infinity, child: _LoadingIndicator()),
          ],
        ),
      ),
    );
  }
}

/// Draggable top bar: source-context chip on the left, window actions on the right.
class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) => WindowManager.instance.startDragging(),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
        child: Row(
          children: [
            const Expanded(child: _ContextChip()),
            const SizedBox(width: 4),
            SqueareIconButtonSized(
              onTap: () {
                onTrayButtonTapCommand('', TrayCommand.create_new_chat.name);
                regionCaptureContext.add(null);
              },
              icon: const Icon(ic.FluentIcons.chat_add_24_regular),
              tooltip: 'New chat'.tr,
            ),
            const SizedBox(width: 4),
            SqueareIconButtonSized(
              onTap: () => OverlayManager.switchToMainWindow(),
              icon: const Icon(ic.FluentIcons.open_24_regular),
              tooltip: 'Open in main app'.tr,
            ),
            const SizedBox(width: 4),
            SqueareIconButtonSized(
              onTap: () => OverlayManager.hideOverlay(),
              icon: const Icon(ic.FluentIcons.dismiss_24_regular),
              tooltip: 'Close'.tr,
            ),
          ],
        ),
      ),
    );
  }
}

class _ContextChip extends StatelessWidget {
  const _ContextChip();

  @override
  Widget build(BuildContext context) {
    final appTheme = context.read<AppTheme>();
    return StreamBuilder<RegionCaptureContext?>(
      stream: regionCaptureContext,
      initialData: regionCaptureContext.valueOrNull,
      builder: (context, snapshot) {
        final ctx = snapshot.data;
        if (ctx == null || !ctx.hasContext) {
          return const SizedBox.shrink();
        }
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            color: appTheme.isDark ? Colors.white.withValues(alpha: 0.06) : Colors.black.withValues(alpha: 0.05),
            borderRadius: const BorderRadius.all(Radius.circular(6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(ic.FluentIcons.crop_24_regular, size: 14),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  ctx.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Thumbnails of the captured screenshot (and any extra files the user adds).
class _AttachmentsRow extends StatelessWidget {
  const _AttachmentsRow();

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final attachments = chatProvider.fileInputs;
    if (attachments.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: SizedBox(
        height: 52,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: attachments.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (context, index) {
            final attachment = attachments[index];
            return attachment.toWidgetThumbnail(
              onRemove: (a) => chatProvider.removeAttachmentFromInput(a),
            );
          },
        ),
      ),
    );
  }
}

class _InputRow extends StatelessWidget {
  const _InputRow();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          ChooseModelButton(),
          SizedBox(width: 4),
          Expanded(child: _InputField()),
          SizedBox(width: 4),
          AddFileButton(),
        ],
      ),
    );
  }
}

class _InputField extends StatelessWidget {
  const _InputField();

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.read<ChatProvider>();
    return TextBox(
      focusNode: promptTextFocusNode,
      minLines: 1,
      maxLines: 4,
      textInputAction: TextInputAction.send,
      suffix: const MicrophoneButton(),
      controller: chatProvider.messageController,
      placeholder: 'Ask about the selection…'.tr,
      onSubmitted: (value) => _onSubmit(value, chatProvider),
    );
  }

  Future<void> _onSubmit(String text, ChatProvider chatProvider) async {
    // Shift+Enter inserts a newline instead of sending.
    if (shiftPressedStream.valueOrNull == true) {
      final controller = chatProvider.messageController;
      final currentText = controller.text;
      final cursor = controller.selection.baseOffset;
      if (cursor >= 0 && cursor <= currentText.length) {
        final newText = '${currentText.substring(0, cursor)}\n${currentText.substring(cursor)}';
        controller.text = newText;
        controller.selection = TextSelection.collapsed(offset: cursor + 1);
      } else {
        controller.text = '$currentText\n';
      }
      promptTextFocusNode.requestFocus();
      return;
    }

    final trimmed = text.trim();
    if (trimmed.isEmpty && chatProvider.fileInputs.isEmpty) return;

    // Prepend the captured source context so the model knows where the
    // screenshot came from (e.g. `Captured from: Firefox — "(2) YouTube"`).
    final prefix = regionCaptureContext.valueOrNull?.promptPrefix ?? '';
    final fullMessage = prefix.isNotEmpty ? '$prefix\n\n$trimmed' : trimmed;

    chatProvider.sendMessage(fullMessage);
    ChatProvider.messageControllerGlobal.clear();
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
        // Chronological order (oldest → newest) with reverse:false so the newest
        // message sits at the bottom, matching `scrollToEnd`'s maxScrollExtent
        // target and the main chat page's behavior.
        final chronoList = messages.value.values.toList();
        if (chronoList.isEmpty) {
          final randWelcome =
              OverlayManager.welcomesForEmptyList[Random().nextInt(OverlayManager.welcomesForEmptyList.length)];
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                randWelcome,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 20),
              ),
            ),
          );
        }
        return ListView.builder(
          controller: chatProvider.listItemsScrollController,
          itemCount: chronoList.length,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          itemBuilder: (context, index) {
            final message = chronoList[index];
            final isStreaming = message.id == chatProvider.streamingMessageId;
            return KeyedSubtree(
              key: isStreaming ? chatProvider.streamingMessageKey : ValueKey('region_message_${message.id}'),
              child: MessageCard(
                message: message,
                selectionMode: false,
                textSize: AppCache.compactMessageTextSize.value!,
                isCompactMode: true,
                shouldBlink: chatProvider.blinkMessageId == message.id,
                indexMessage: index,
              ),
            );
          },
        );
      },
    );
  }
}
