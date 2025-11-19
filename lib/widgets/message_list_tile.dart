import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:elevenlabs_flutter/elevenlabs_flutter.dart';
import 'package:fluent_gpt/common/attachment.dart';
import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/common/custom_prompt.dart';
import 'package:fluent_gpt/common/keyboard_shortcuts/intents.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/common/scrapper/web_search_result.dart';
import 'package:fluent_gpt/dialogs/info_about_user_dialog.dart';
import 'package:fluent_gpt/dialogs/search_chat_dialog.dart';
import 'package:fluent_gpt/features/pdf_utils.dart';
import 'package:fluent_gpt/features/text_to_speech.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/pages/home_page.dart';
import 'package:fluent_gpt/pages/new_settings_page.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/theme.dart';
import 'package:easy_image_viewer/easy_image_viewer.dart';
import 'package:file_selector/file_selector.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/confirmation_dialog.dart';
import 'package:fluent_gpt/widgets/context_menu_builders.dart';
import 'package:fluent_gpt/widgets/markdown_builders/code_wrapper.dart';
import 'package:fluent_gpt/widgets/markdown_builders/markdown_utils.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as ic;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:mime_type/mime_type.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:window_manager/window_manager.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';

import 'input_field.dart';

class MessageListTile extends StatelessWidget {
  const MessageListTile({
    super.key,
    this.leading,
    this.onPressed,
    required this.title,
    this.subtitle,
    this.tileColor,
  });
  final Widget? leading;
  final void Function()? onPressed;
  final Widget title;
  final Widget? subtitle;
  final Color? tileColor;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (leading != null)
          Padding(
            padding: const EdgeInsets.only(left: 8, top: 8, bottom: 8),
            child: leading!,
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 8),
                child: DefaultTextStyle(
                  style: theme.typography.title!,
                  child: title,
                ),
              ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  child: DefaultTextStyle(
                    style: theme.typography.subtitle!,
                    child: subtitle!,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class MessageCard extends StatefulWidget {
  const MessageCard({
    super.key,
    required this.message,
    required this.selectionMode,
    required this.textSize,
    required this.isCompactMode,
    this.shouldBlink = false,

    /// Index of the item in reversed list. 0 is the first bottom message
    this.indexMessage = 0,
  });
  final FluentChatMessage message;

  final bool selectionMode;
  final bool isCompactMode;
  final bool shouldBlink;
  final int textSize;

  /// Index of the item in reversed list. 0 is the first bottom message
  final int indexMessage;

  @override
  State<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard> {
  bool _isMarkdownView = true;
  bool _isLoadingReadAloud = false;
  bool _isExpanded = false;
  final flyoutController = FlyoutController();
  Color? backgroundColor;
  bool isEditing = false;
  TextEditingController? textEditingController;
  FocusNode? textEditingFocus;
  bool isFocused = false;
  String? selectedContent;
  final FocusNode focusNode = FocusNode();
  @override
  void initState() {
    super.initState();
    _isMarkdownView = AppCache.isMarkdownViewEnabled.value ?? true;
    if (widget.shouldBlink && mounted) {
      Timer.periodic(Duration(milliseconds: 600), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        final cardColor = context.theme.cardColor;
        backgroundColor = backgroundColor == cardColor ? Colors.yellow.dark : cardColor;
        if (mounted) setState(() {});

        if (timer.tick == 5) {
          timer.cancel();
          backgroundColor = cardColor;
          if (mounted) setState(() {});
        }
      });
    }
  }

  @override
  dispose() {
    flyoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formatDateTime = DateFormat('HH:mm:ss').format(DateTime.fromMillisecondsSinceEpoch(widget.message.timestamp));
    final appTheme = context.read<AppTheme>();
    final myMessageStyle = TextStyle(color: appTheme.color, fontSize: 14);
    Widget tileWidget;
    final isContentText = widget.message.isTextMessage;
    final theme = FluentTheme.of(context);

    if (widget.message.type == FluentChatMessageType.header) {
      return Text(
        widget.message.content,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 14,
          color: theme.typography.caption?.color?.withAlpha(127),
        ),
      );
    }

    if (widget.message.type == FluentChatMessageType.system)
      return Focus(
        autofocus: false,
        descendantsAreTraversable: false,
        descendantsAreFocusable: true,
        onFocusChange: (value) {
          if (isFocused == value) return;
          setState(() {
            isFocused = value;
          });
        },
        child: FlyoutTarget(
          controller: flyoutController,
          child: GestureDetector(
            onSecondaryTap: () {
              flyoutController.showFlyout(
                builder: (context) => _showOptionsFlyout(),
                position: mouseLocalPosition,
              );
            },
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.0),
                color: backgroundColor ?? context.theme.cardColor,
                border: Border.all(
                  color: isFocused ? context.theme.accentColor.withAlpha(127) : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('System', style: myMessageStyle)),
                      _isExpanded
                          ? const Icon(FluentIcons.chevron_up_16_filled, size: 12)
                          : const Icon(FluentIcons.chevron_down_16_filled, size: 12)
                    ],
                  ),
                  if (_isExpanded)
                    SelectableText(widget.message.content, style: TextStyle(fontSize: widget.textSize.toDouble())),
                ],
              ),
            ),
          ),
        ),
      );

    tileWidget = MessageListTile(
      title: Text(widget.message.creator, style: myMessageStyle),
      subtitle: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message.type == FluentChatMessageType.textAi && selectedChatRoom.characterAvatarPath != null)
            GestureDetector(
              onTap: () {
                final base64Image = base64Encode(File(selectedChatRoom.characterAvatarPath!).readAsBytesSync());
                _showImageDialog(context, FluentChatMessage.imageAi(id: '', content: base64Image));
              },
              child: SizedBox(
                width: 64,
                height: 64,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.0),
                      image: DecorationImage(
                        fit: BoxFit.cover,
                        image: FileImage(
                          File(selectedChatRoom.characterAvatarPath!),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.message.indexPin != null) Icon(ic.FluentIcons.pin_20_filled, size: 12, color: Colors.orange),
                if (widget.message.type == FluentChatMessageType.image ||
                    widget.message.type == FluentChatMessageType.imageAi)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => _showImageDialog(context, widget.message),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 0.0, right: 12, top: 8, bottom: 12),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10.0),
                          child: Image.memory(
                            decodeImage(widget.message.content),
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (isEditing && isContentText)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: TextBox(
                          focusNode: textEditingFocus,
                          maxLines: 999,
                          minLines: 1,
                          style: TextStyle(fontSize: widget.textSize.toDouble()),
                          controller: textEditingController,
                        ),
                      ),
                      SqueareIconButtonSized(
                        icon: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(FluentIcons.checkmark_16_filled),
                            const SizedBox(width: 4),
                            HotkeyText([LogicalKeyboardKey.alt, LogicalKeyboardKey.enter]),
                          ],
                        ),
                        tooltip: 'Save'.tr,
                        width: 100,
                        onTap: () async {
                          final provider = context.read<ChatProvider>();
                          await provider.editMessage(
                            widget.message.id,
                            widget.message.copyWith(
                              content: textEditingController!.text,
                            ),
                          );
                          _toggleEditing();
                        },
                      )
                    ],
                  )
                else if (isContentText && _isMarkdownView)
                  buildMarkdown(
                    context,
                    widget.message.content,
                    textSize: widget.textSize.toDouble(),
                    focusNode: FocusNode(descendantsAreTraversable: false),
                    onSelectionChanged: (text) {
                      selectedContent = text?.plainText;
                    },
                    contextMenuBuilder: (ctx, state) => ContextMenuBuilders.textChatMessageContextMenuBuilder(
                      ctx,
                      state,
                      onShowCommandsPressed: (text) {
                        flyoutController.showFlyout(
                          builder: (context) => _showCommandsFlyout(text),
                          position: mouseLocalPosition,
                        );
                      },
                      onMorePressed: () {
                        flyoutController.showFlyout(
                          builder: (context) => _showOptionsFlyout(),
                          position: mouseLocalPosition,
                        );
                      },
                      onQuoteSelectedText: (text) {
                        final provider = context.read<ChatProvider>();
                        provider.messageController.text = provider.messageController.text += '"$text" ';
                        promptTextFocusNode.requestFocus();
                      },
                      onImproveSelectedText: (text) {
                        final provider = context.read<ChatProvider>();
                        provider.sendMessage('Improve writing: "$text"', hidePrompt: true);
                      },
                    ),
                    contextMenuBuilderMarkdown: (ctx, state) {
                      return ContextMenuBuilders.markdownChatMessageContextMenuBuilder(
                        context,
                        flyoutController,
                        state,
                        onShowCommandsPressed: (text) {
                          flyoutController.showFlyout(
                            builder: (context) => _showCommandsFlyout(text),
                            position: mouseLocalPosition,
                          );
                        },
                        onMorePressed: () {
                          flyoutController.showFlyout(
                            builder: (context) => _showOptionsFlyout(),
                            position: mouseLocalPosition,
                          );
                        },
                        onQuoteSelectedText: (text) {
                          final provider = context.read<ChatProvider>();
                          provider.messageController.text = provider.messageController.text += '"$text" ';
                          promptTextFocusNode.requestFocus();
                        },
                        onImproveSelectedText: (text) {
                          final provider = context.read<ChatProvider>();
                          provider.sendMessage('Improve writing: "$text"', hidePrompt: true);
                        },
                      );
                    },
                  )
                else if (isContentText)
                  SelectableText(
                    widget.message.content,
                    contextMenuBuilder: (ctx, state) => ContextMenuBuilders.textChatMessageContextMenuBuilder(
                      ctx,
                      state,
                      onShowCommandsPressed: (text) {
                        flyoutController.showFlyout(
                          builder: (context) => _showCommandsFlyout(text),
                          position: mouseLocalPosition,
                        );
                      },
                      onMorePressed: () {
                        flyoutController.showFlyout(
                          builder: (context) => _showOptionsFlyout(),
                          position: mouseLocalPosition,
                        );
                      },
                      onQuoteSelectedText: (text) {
                        final provider = context.read<ChatProvider>();
                        provider.messageController.text = provider.messageController.text += '"$text" ';
                        promptTextFocusNode.requestFocus();
                      },
                      onImproveSelectedText: (text) {
                        final provider = context.read<ChatProvider>();
                        provider.sendMessage('Improve writing: "$text"', hidePrompt: true);
                      },
                    ),
                    style: TextStyle(fontSize: widget.textSize.toDouble(), fontWeight: FontWeight.normal),
                  ),
                if (widget.message.type == FluentChatMessageType.file)
                  Button(
                    onPressed: () async {
                      if (widget.message.path?.endsWith('.pdf') == true) {
                        final pdfImages = await PdfUtils.getImagesFromPdfPath(widget.message.path!);
                        ImagesDialog.show(
                          // ignore: use_build_context_synchronously
                          context,
                          pdfImages.map((e) => Attachment.fromInternalScreenshotBytes(e)).toList(),
                        );
                        return;
                      }
                      if (Platform.isWindows) {
                        final content = widget.message.content;
                        showDialog(
                            context: context,
                            barrierDismissible: true,
                            builder: (ctx) {
                              return ContentDialog(
                                title: Text(widget.message.fileName ?? 'File'),
                                constraints: const BoxConstraints(
                                  maxWidth: 800,
                                  maxHeight: 1200,
                                ),
                                actions: [
                                  Button(
                                    onPressed: () => Navigator.of(ctx).pop(),
                                    child: Text('Close'.tr),
                                  ),
                                ],
                                content: SizedBox(
                                  width: 800,
                                  child: SingleChildScrollView(
                                    child: SelectableText(
                                      content,
                                      style: TextStyle(fontSize: 16),
                                    ),
                                  ),
                                ),
                              );
                            });
                        return;
                      }
                      final tempDir = Directory.systemTemp;
                      final file = File(
                          '${tempDir.path}${Platform.pathSeparator}${widget.message.fileName?.isEmpty == true ? 'file' : widget.message.fileName}');
                      await file.writeAsString(widget.message.content);
                      final mimeType = mime(file.path);
                      await OpenFilex.open(file.path, type: mimeType);
                    },
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.message.path?.endsWith('.pdf') == false)
                          Icon(FluentIcons.document_24_filled, size: 24)
                        else
                          Icon(
                            FluentIcons.document_pdf_24_filled,
                            size: 24,
                            color: Colors.warningPrimaryColor,
                          ),
                        Text(
                          widget.message.fileName ?? 'File',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ],
                    ),
                  ),
                if (widget.message.type == FluentChatMessageType.webResult)
                  Wrap(
                    children: [
                      if (widget.message.content.isNotEmpty)
                        SelectableText(
                          widget.message.content,
                          style: TextStyle(fontSize: widget.textSize.toDouble()),
                        ),
                      for (final result in (widget.message.webResults ?? <WebSearchResult>[]))
                        SizedBox(
                          width: 200,
                          child: Button(
                            onPressed: () => launchUrlString(result.url),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (result.favicon != null)
                                  Image.network(
                                    result.favicon!,
                                    width: 24,
                                    height: 24,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Icon(
                                      FluentIcons.globe_16_regular,
                                      size: 24,
                                    ),
                                  ),
                                Text(
                                  result.title,
                                  style: theme.typography.subtitle!,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.start,
                                  maxLines: 2,
                                ),

                                /// url short one line
                                Text(
                                  result.url,
                                  style: theme.typography.caption!,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.start,
                                  maxLines: 1,
                                ),
                              ],
                            ),
                          ),
                        )
                    ],
                  ),
                if (widget.message.buttons != null)
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      for (final button in widget.message.buttons!.entries)
                        Button(
                          onPressed: button.value
                              ? () {
                                  final provider = context.read<ChatProvider>();
                                  provider.onMessageButtonTap(button.key, widget.message);
                                }
                              : null,
                          child: Text(button.key.tr),
                        )
                    ],
                  ),
                Text(
                  '$formatDateTime, T: ${widget.message.tokens}',
                  style: TextStyle(
                    fontSize: widget.textSize * 0.9,
                    fontWeight: FontWeight.w200,
                    color: context.theme.typography.body?.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    return Shortcuts(
      shortcuts: {
        LogicalKeySet(LogicalKeyboardKey.alt, LogicalKeyboardKey.enter): const ActivateIntent(),
        LogicalKeySet(LogicalKeyboardKey.escape): const DoNothingIntent(),
        LogicalKeySet(LogicalKeyboardKey.delete): DeleteIntent(),
        LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyC): CopySelectionTextIntent.copy,
        LogicalKeySet(LogicalKeyboardKey.meta, LogicalKeyboardKey.keyC): CopySelectionTextIntent.copy,
      },
      child: Actions(
        actions: {
          CopySelectionTextIntent: CallbackAction<CopySelectionTextIntent>(
            onInvoke: (intent) {
              Clipboard.setData(ClipboardData(text: selectedContent ?? ''));
              displayCopiedToClipboard();
              return null;
            },
          ),
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (intent) async {
              if (isEditing) {
                final provider = context.read<ChatProvider>();
                await provider.editMessage(
                  widget.message.id,
                  widget.message.copyWith(
                    content: textEditingController!.text,
                  ),
                );
                _toggleEditing();
              } else {
                _toggleEditing();
              }
              return null;
            },
          ),
          DoNothingIntent: CallbackAction<DoNothingIntent>(
            onInvoke: (intent) {
              if (isEditing) {
                _toggleEditing();
              }
              return null;
            },
          ),
          DeleteIntent: CallbackAction<DeleteIntent>(
            onInvoke: (intent) async {
              final provider = context.read<ChatProvider>();
              final confirmed = await ConfirmationDialog.show(context: context);
              if (!confirmed) {
                // ignore: use_build_context_synchronously
                FocusScope.of(context).requestFocus(focusNode);
                return;
              }
              provider.deleteMessage(widget.message.id);
              // ignore: use_build_context_synchronously
              FocusScope.of(context).nextFocus();
              return null;
            },
          ),
        },
        child: Listener(
          behavior: HitTestBehavior.deferToChild,
          onPointerDown: (event) async {
            // if right click - ignore
            if (event.buttons == kSecondaryMouseButton) {
              return;
            }
            FocusScope.of(context).unfocus(disposition: UnfocusDisposition.previouslyFocusedChild);
            // ideal delay to unfocus the previous tile, but still not loose focus on current one
            await Future.delayed(Duration(milliseconds: 1));
            // even if we are focused on current one, since we unfocused unknown previous one we need to focus on current one again
            try {
              FocusManager.instance.primaryFocus?.requestFocus(focusNode);
            } catch (e) {
              logError(e.toString());
            }
          },
          child: Focus(
            focusNode: focusNode,
            autofocus: false,
            descendantsAreTraversable: false,
            descendantsAreFocusable: true,
            canRequestFocus: true,
            onFocusChange: (value) async {
              if (isFocused == value) return;
              setState(() {
                isFocused = value;
              });
            },
            child: Stack(
              children: [
                GestureDetector(
                  onSecondaryTap: () {
                    flyoutController.showFlyout(
                      builder: (context) => _showOptionsFlyout(),
                      position: mouseLocalPosition,
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: EdgeInsets.only(bottom: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8.0),
                      color: backgroundColor ?? context.theme.cardColor.withAlpha(127),
                      border: Border.all(
                        color: isFocused ? context.theme.accentColor.withAlpha(127) : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: tileWidget,
                  ),
                ),
                if (widget.isCompactMode)
                  Positioned(
                    right: 16,
                    top: 8,
                    child: Row(
                      children: [
                        //copy button
                        SqueareIconButton(
                          icon: const Icon(FluentIcons.copy_16_regular),
                          onTap: () {
                            Clipboard.setData(ClipboardData(text: widget.message.content));
                            displayCopiedToClipboard();
                          },
                          tooltip: 'Copy'.tr,
                        ),
                        SizedBox(width: 8),
                        FlyoutTarget(
                          controller: flyoutController,
                          child: SqueareIconButton(
                            icon: const Icon(FluentIcons.more_vertical_16_filled),
                            onTap: () {
                              flyoutController.showFlyout(
                                builder: (ctx) => _showOptionsFlyout(),
                              );
                            },
                            tooltip: 'More'.tr,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Positioned(
                    right: 16,
                    bottom: 8,
                    child: Focus(
                      canRequestFocus: false,
                      descendantsAreFocusable: false,
                      descendantsAreTraversable: false,
                      child: Wrap(
                        spacing: 4,
                        children: [
                          if (widget.message.isTextMessage) ...[
                            SqueareIconButton(
                              tooltip: _isMarkdownView ? 'Show text' : 'Show markdown',
                              icon: const Icon(FluentIcons.paint_brush_12_regular),
                              onTap: () {
                                AppCache.isMarkdownViewEnabled.value = !_isMarkdownView;
                                setState(() {
                                  _isMarkdownView = !_isMarkdownView;
                                });
                              },
                            ),
                            SqueareIconButton(
                              tooltip: 'Edit'.tr,
                              icon: const Icon(FluentIcons.edit_12_regular),
                              onTap: () {
                                // _showEditMessageDialog(context, widget.message);
                                _toggleEditing();
                              },
                            ),
                            // only for the last 2 items
                            if (widget.indexMessage < 2)
                              SqueareIconButton(
                                tooltip: 'Regenerate message',
                                icon: widget.message.isTextFromMe
                                    ? const Icon(FluentIcons.arrow_down_12_regular)
                                    : const Icon(FluentIcons.arrow_counterclockwise_16_filled),
                                onTap: () {
                                  final provider = context.read<ChatProvider>();
                                  final indexInReversedList = messagesReversedList.indexOf(widget.message);
                                  provider.regenerateMessage(widget.message, indexInReversedList: indexInReversedList);
                                },
                              ),
                            SqueareIconButton(
                              tooltip: 'Read aloud (Requires Speech API)',
                              icon: _isLoadingReadAloud
                                  ? ProgressRing()
                                  : TextToSpeechService.isReadingAloud
                                      ? Icon(
                                          FluentIcons.stop_24_filled,
                                          color: context.theme.accentColor,
                                        )
                                      : const Icon(FluentIcons.sound_wave_circle_24_regular),
                              onTap: () async {
                                if (TextToSpeechService.isValid() == false) {
                                  displayInfoBar(context, builder: (ctx, close) {
                                    return InfoBar(
                                      severity: InfoBarSeverity.warning,
                                      title: Text('${TextToSpeechService.serviceName} API key is not set'),
                                      action: Button(
                                          child: Text('Settings'.tr),
                                          onPressed: () {
                                            Navigator.of(context).push(
                                              FluentPageRoute(builder: (context) {
                                                return const NewSettingsPage();
                                              }),
                                            );
                                          }),
                                    );
                                  });
                                  return;
                                }
                                if (TextToSpeechService.isReadingAloud) {
                                  TextToSpeechService.stopReadingAloud();
                                } else {
                                  try {
                                    setState(() {
                                      _isLoadingReadAloud = true;
                                    });
                                    await TextToSpeechService.readAloud(
                                      widget.message.content,
                                      onCompleteReadingAloud: () {
                                        setState(() {
                                          _isLoadingReadAloud = false;
                                        });
                                      },
                                    );
                                    setState(() {
                                      _isLoadingReadAloud = false;
                                    });
                                  } catch (e) {
                                    setState(() {
                                      _isLoadingReadAloud = false;
                                    });
                                    if (e is DeadlineExceededException) {
                                      // ignore: use_build_context_synchronously
                                      displayInfoBar(context, builder: (ctx, close) {
                                        return InfoBar(
                                          severity: InfoBarSeverity.error,
                                          title: Text('Timeout exceeded. Please try again later.'),
                                        );
                                      });
                                    } else {
                                      // ignore: use_build_context_synchronously
                                      displayInfoBar(context, builder: (ctx, close) {
                                        return InfoBar(
                                          severity: InfoBarSeverity.error,
                                          title: Text('$e'),
                                        );
                                      });

                                      rethrow;
                                    }
                                  }
                                }
                                await Future.delayed(const Duration(milliseconds: 100));
                                setState(() {});
                              },
                            ),
                          ],
                          SqueareIconButton(
                            tooltip: 'Copy'.tr,
                            icon: const Icon(FluentIcons.copy_16_regular),
                            onTap: () async {
                              if (widget.message.type == FluentChatMessageType.image ||
                                  widget.message.type == FluentChatMessageType.imageAi) {
                                {
                                  final bytes = decodeImage(widget.message.content);
                                  await Pasteboard.writeImage(bytes);
                                  displayCopiedToClipboard();
                                  return;
                                }
                              }
                              Clipboard.setData(ClipboardData(text: widget.message.content));
                              displayCopiedToClipboard();
                            },
                          ),
                          SqueareIconButton(
                            tooltip: 'Delete'.tr,
                            icon: Icon(FluentIcons.delete_16_filled, color: Colors.red),
                            onTap: () async {
                              final provider = context.read<ChatProvider>();
                              provider.deleteMessage(widget.message.id);
                            },
                          ),
                          FlyoutTarget(
                            controller: flyoutController,
                            child: SqueareIconButton(
                              icon: const Icon(FluentIcons.more_vertical_16_filled),
                              onTap: () {
                                flyoutController.showFlyout(
                                  builder: (context) => _showOptionsFlyout(),
                                );
                              },
                              tooltip: 'More'.tr,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _toggleEditing() {
    // final focusScope = FocusScope.of(context);
    textEditingController?.dispose();
    textEditingController = TextEditingController(text: widget.message.content);
    textEditingFocus = FocusNode();
    isEditing = !isEditing;
    setState(() {});

    if (isEditing == false) {
      textEditingController?.dispose();
      // textEditingFocus?.dispose();
      // textEditingFocus = null;
      textEditingController = null;
      // focusScope.unfocus();
      try {
        final focusScope = FocusScope.of(context);

        focusScope.requestFocus(focusScope);
        // ignore: empty_catches
      } catch (e) {}
    } else {
      textEditingFocus?.requestFocus();
    }
  }

  void _copyCodeToClipboard(String string) {
    final code = getCodeFromMarkdown(string);
    log(code.toString());
    if (code.isEmpty) {
      displayInfoBar(
        context,
        builder: (context, close) => const InfoBar(
          title: Text('No code snippet found'),
          severity: InfoBarSeverity.warning,
        ),
      );
      return;
    }
    if (code.length == 1) {
      Clipboard.setData(ClipboardData(text: code.first));
      displayCopiedToClipboard();
      return;
    }
    // if more than one code snippet is found, show a dialog to select one
    chooseCodeBlockDialog(context, code);
  }

  Future<void> _showImageDialog(BuildContext context, FluentChatMessage message) async {
    final image = decodeImage(message.content);
    final provider = Image.memory(
      image,
      filterQuality: FilterQuality.high,
    ).image;

    showDialog(
      context: context,
      barrierColor: Colors.black,
      barrierDismissible: true,
      builder: (context) {
        return ImageViewerDialog(provider: provider, description: message.imagePrompt);
      },
    );
  }

  List<MenuFlyoutItemBase> _buildMenuItems(List<CustomPrompt> commands, String selectedText) {
    List<MenuFlyoutItemBase> items = [];
    for (final command in commands) {
      if (command.showInContextMenu == false) {
        continue;
      }
      if (command.children.isNotEmpty) {
        items.add(MenuFlyoutSubItem(
          text: Text(command.title.tr),
          leading: Icon(command.icon),
          items: (BuildContext context) {
            return _buildMenuItems(command.children, selectedText);
          },
        ));
      } else {
        items.add(MenuFlyoutItem(
          text: Text(command.title.tr),
          leading: Icon(command.icon),
          onPressed: () {
            final provider = context.read<ChatProvider>();
            provider.sendToQuickOverlay(command.title, command.getPromptText(selectedText));
          },
        ));
      }
    }
    return items;
  }

  MenuFlyout _showCommandsFlyout(String? selectedText) {
    if (selectedText == null || selectedText.isEmpty) {
      selectedText = widget.message.content;
    }
    return MenuFlyout(items: _buildMenuItems(customPrompts.value, selectedText));
  }

  MenuFlyout _showOptionsFlyout() {
    final message = widget.message;
    return MenuFlyout(
      items: [
        if (message.indexPin == null)
          MenuFlyoutItem(
              text: Text('Pin message'.tr),
              leading: const Icon(FluentIcons.pin_20_filled),
              onPressed: () {
                final provider = context.read<ChatProvider>();
                provider.pinMessage(message.id);
              })
        else
          MenuFlyoutItem(
              text: Text('Unpin message'.tr),
              leading: const Icon(FluentIcons.pin_off_20_filled),
              onPressed: () {
                final provider = context.read<ChatProvider>();
                provider.unpinMessage(message.id);
              }),
        MenuFlyoutItem(
            text: Text('Shorter'.tr),
            leading: const Icon(FluentIcons.text_align_justify_low_20_filled),
            onPressed: () {
              final provider = context.read<ChatProvider>();
              provider.shortenMessage(widget.message.id);
            }),
        MenuFlyoutItem(
            text: Text('Longer'.tr),
            leading: const Icon(FluentIcons.text_description_16_filled),
            onPressed: () {
              final provider = context.read<ChatProvider>();
              provider.lengthenMessage(widget.message.id);
            }),
        const MenuFlyoutSeparator(),
        MenuFlyoutItem(
            text: Text('Continue'.tr),
            leading: const Icon(FluentIcons.arrow_forward_20_filled),
            onPressed: () {
              final provider = context.read<ChatProvider>();
              provider.continueMessage(widget.message.id);
            }),
        if (message.isTextMessage) ...[
          MenuFlyoutItem(
            text: Text('Remember this'.tr),
            leading: const Icon(FluentIcons.brain_circuit_20_regular),
            onPressed: () async {
              final provider = context.read<ChatProvider>();
              final messageIndex = messagesReversedList.indexOf(message);
              final previous =
                  messagesReversedList.length > messageIndex + 1 ? messagesReversedList[messageIndex + 1] : null;
              final next =
                  messagesReversedList.length > messageIndex - 1 ? messagesReversedList[messageIndex - 1] : null;
              final messagesRange = await provider.convertMessagesToString([
                if (previous != null) previous,
                message,
                if (next != null) next,
              ]);
              messagesReversedList[messageIndex + 1];
              final information = await provider.generateUserKnowladgeBasedOnText(
                messagesRange,
              );
              displayInfoBar(provider.context!, builder: (ctx, close) {
                return InfoBar(
                  title: Text('Memory updated'.tr),
                  content: Text(information),
                  severity: InfoBarSeverity.success,
                  isLong: true,
                  action: Button(
                    onPressed: () async {
                      close();
                      await Future.delayed(const Duration(milliseconds: 400));
                      showDialog(
                        // ignore: use_build_context_synchronously
                        context: provider.context!,
                        builder: (ctx) => const InfoAboutUserDialog(),
                        barrierDismissible: true,
                      );
                    },
                    child: Text('Open memory'.tr),
                  ),
                );
              });
            },
          ),
          MenuFlyoutItem(
            text: Text('Edit'.tr),
            leading: const Icon(FluentIcons.edit_16_regular),
            onPressed: () async {
              await Navigator.of(context).maybePop();
              _toggleEditing();
            },
          ),
        ],
        MenuFlyoutSubItem(
          text: Text('Commands'.tr),
          trailing: const Icon(FluentIcons.chevron_right_16_filled),
          items: (context) => _buildMenuItems(customPrompts.value, widget.message.content),
        ),
        if ((message.type == FluentChatMessageType.imageAi) || message.type == FluentChatMessageType.image) ...[
          const MenuFlyoutSeparator(),
          MenuFlyoutItem(
            text: Text('Save image to file'.tr),
            leading: const Icon(FluentIcons.save_16_regular),
            onPressed: () => _saveImageToFile(context),
          ),
          MenuFlyoutItem(
            text: Text('Copy image'.tr),
            leading: const Icon(FluentIcons.copy_16_regular),
            onPressed: () => _copyImageToClipboard(context),
          ),
        ],
        const MenuFlyoutSeparator(),
        MenuFlyoutItem(
          text: Text('New conversation branch from here'.tr),
          leading: const Icon(FluentIcons.branch_20_regular),
          onPressed: () {
            final provider = context.read<ChatProvider>();
            provider.createNewBranchFromLastMessage(widget.message.id);
          },
        ),
        const MenuFlyoutSeparator(),
        MenuFlyoutItem(
          text: Text('Delete everything above'.tr, style: TextStyle(color: Colors.red)),
          leading: Icon(FluentIcons.arrow_up_exclamation_20_regular, color: Colors.red),
          onPressed: () async {
            final provider = context.read<ChatProvider>();
            await provider.deleteMessagesAbove(widget.message.id);
            // ignore: use_build_context_synchronously
            Navigator.of(context).maybePop();
          },
        ),
        MenuFlyoutItem(
          text: Text('Delete everything below'.tr, style: TextStyle(color: Colors.red)),
          leading: Icon(FluentIcons.arrow_down_exclamation_20_regular, color: Colors.red),
          onPressed: () async {
            final provider = context.read<ChatProvider>();
            await provider.deleteMessagesBelow(widget.message.id);
            // ignore: use_build_context_synchronously
            Navigator.of(context).maybePop();
          },
        ),
        MenuFlyoutItem(
          text: Text('Delete'.tr, style: TextStyle(color: Colors.red)),
          leading: Icon(FluentIcons.delete_12_regular, color: Colors.red),
          onPressed: () {
            final provider = context.read<ChatProvider>();
            provider.deleteMessage(widget.message.id);
          },
        ),
      ],
    );
  }

  Future<void> _saveImageToFile(BuildContext context) async {
    final fileBytesString = widget.message.content;
    final fileBytes = base64.decode(fileBytesString);
    final file = XFile.fromData(
      fileBytes,
      name: 'image.png',
      mimeType: 'image/png',
      length: fileBytes.lengthInBytes,
    );

    final FileSaveLocation? location = await getSaveLocation(
      suggestedName: '${fileBytes.lengthInBytes}.png',
      acceptedTypeGroups: [
        const XTypeGroup(
          label: 'images',
          extensions: ['png', 'jpg', 'jpeg'],
        ),
      ],
    );

    if (location != null) {
      await file.saveTo(location.path);
      // ignore: use_build_context_synchronously
      // Navigator.of(context).maybePop();
    }
  }

  _copyImageToClipboard(BuildContext context) async {
    Navigator.of(context).maybePop();

    final imageBytesString = widget.message.content;
    final imageBytes = base64.decode(imageBytesString);
    Pasteboard.writeImage(imageBytes);
    displayCopiedToClipboard();
  }
}

class HotkeyText extends StatelessWidget {
  const HotkeyText(this.keys, {super.key, required});
  final List<LogicalKeyboardKey> keys;

  @override
  Widget build(BuildContext context) {
    final String label = keys.map((k) => k.keyLabel).join(' + ');

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.blue.withAlpha(32), // 0.12 opacity
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.blue.withAlpha(77)), // 0.3 opacity
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.blue.withAlpha(217), // 0.85 opacity
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class ImageViewerDialog extends StatefulWidget {
  const ImageViewerDialog({
    super.key,
    required this.provider,
    this.description,
    this.barrierDismissible = true,
    this.backgroundColor,
  });

  final ImageProvider<Object> provider;
  final String? description;
  final bool barrierDismissible;
  final Color? backgroundColor;

  @override
  State<ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<ImageViewerDialog> {
  bool isDescriptionVisible = false;
  bool fullScreen = false;
  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final backgroundColor = widget.backgroundColor ?? theme.scaffoldBackgroundColor;
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: backgroundColor),
        EasyImageView(imageProvider: widget.provider),
        Positioned(
          top: 16,
          right: 16,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SqueareIconButton(
                onTap: () {
                  setState(() {
                    fullScreen = !fullScreen;
                  });
                  WindowManager.instance.setFullScreen(fullScreen);
                },
                icon: Icon(
                  fullScreen ? FluentIcons.full_screen_minimize_16_filled : FluentIcons.full_screen_maximize_16_filled,
                ),
                tooltip: 'Full screen',
              ),
              const SizedBox(width: 8),
              SqueareIconButtonSized(
                width: 50,
                onTap: () {
                  if (fullScreen) {
                    WindowManager.instance.setFullScreen(false);
                  }
                  Navigator.of(context).pop();
                },
                icon: const Text('X  [esc]', style: TextStyle(fontSize: 12)),
                tooltip: 'Close',
              ),
            ],
          ),
        ),
        if (widget.description != null) ...[
          Positioned(
            right: 16,
            bottom: 16,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              height: isDescriptionVisible ? 200 : 48,
              width: isDescriptionVisible ? MediaQuery.sizeOf(context).width - 300 : 48,
              decoration: BoxDecoration(
                color: context.theme.cardColor,
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isDescriptionVisible)
                      Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: SelectableText(
                          widget.description!,
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 24,
            right: 24,
            child: SqueareIconButton(
              onTap: () {
                setState(() {
                  isDescriptionVisible = !isDescriptionVisible;
                });
              },
              icon: Icon(
                isDescriptionVisible ? FluentIcons.chevron_right_16_filled : FluentIcons.chevron_left_16_filled,
              ),
              tooltip: 'Close',
            ),
          ),
        ]
      ],
    );
  }
}
