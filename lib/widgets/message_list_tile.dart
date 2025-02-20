import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:elevenlabs_flutter/elevenlabs_flutter.dart';
import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/common/custom_prompt.dart';
import 'package:fluent_gpt/common/debouncer.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/dialogs/info_about_user_dialog.dart';
import 'package:fluent_gpt/features/text_to_speech.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/pages/home_page.dart';
import 'package:fluent_gpt/pages/settings_page.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/theme.dart';
import 'package:easy_image_viewer/easy_image_viewer.dart';
import 'package:file_selector/file_selector.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/context_menu_builders.dart';
import 'package:fluent_gpt/widgets/markdown_builders/code_wrapper.dart';
import 'package:fluent_gpt/widgets/markdown_builders/markdown_utils.dart';
import 'package:fluent_gpt/widgets/wiget_constants.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:mime_type/mime_type.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:provider/provider.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:window_manager/window_manager.dart';

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
    return Semantics(
      onTap: onPressed,
      child: GestureDetector(
        onTap: onPressed,
        onLongPress: onPressed,
        child: Row(
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
                      style: FluentTheme.of(context).typography.title!,
                      child: title,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 16, bottom: 8),
                      child: DefaultTextStyle(
                        style: FluentTheme.of(context).typography.subtitle!,
                        child: subtitle!,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MessageCard extends StatefulWidget {
  const MessageCard({
    super.key,
    required this.message,
    required this.selectionMode,
    required this.isError,
    required this.textSize,
    required this.isCompactMode,
    this.shouldBlink = false,

    /// Index of the item in reversed list. 0 is the first bottom message
    this.indexMessage = 0,
  });
  final FluentChatMessage message;

  final bool selectionMode;
  final bool isError;
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
        backgroundColor =
            backgroundColor == cardColor ? Colors.yellow.dark : cardColor;
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
    final formatDateTime = DateFormat('HH:mm:ss')
        .format(DateTime.fromMillisecondsSinceEpoch(widget.message.timestamp));
    final appTheme = context.read<AppTheme>();
    final myMessageStyle = TextStyle(color: appTheme.color, fontSize: 14);
    Widget tileWidget;
    final isContentText = widget.message.isTextMessage;

    if (widget.message.type == FluentChatMessageType.system)
      return FlyoutTarget(
        controller: flyoutController,
        child: GestureDetector(
          onSecondaryTap: () {
            flyoutController.showFlyout(
              builder: (context) => _showOptionsFlyout(context),
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
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('System', style: myMessageStyle)),
                    _isExpanded
                        ? const Icon(FluentIcons.chevron_up_16_filled, size: 12)
                        : const Icon(FluentIcons.chevron_down_16_filled,
                            size: 12)
                  ],
                ),
                if (_isExpanded)
                  SelectableText(widget.message.content,
                      style: TextStyle(fontSize: widget.textSize.toDouble())),
              ],
            ),
          ),
        ),
      );

    tileWidget = MessageListTile(
      tileColor: Colors.red,
      title: Text(widget.message.creator, style: myMessageStyle),
      subtitle: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.message.type == FluentChatMessageType.textAi &&
              selectedChatRoom.characterAvatarPath != null)
            GestureDetector(
              onTap: () {
                final base64Image = base64Encode(
                    File(selectedChatRoom.characterAvatarPath!)
                        .readAsBytesSync());
                _showImageDialog(context,
                    FluentChatMessage.imageAi(id: '', content: base64Image));
              },
              child: Container(
                width: 64,
                height: 64,
                margin: const EdgeInsets.only(right: 8),
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
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.message.type == FluentChatMessageType.image ||
                    widget.message.type == FluentChatMessageType.imageAi)
                  MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => _showImageDialog(context, widget.message),
                      child: Padding(
                        padding: const EdgeInsets.only(
                            left: 0.0, right: 12, top: 8, bottom: 12),
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
                if (isContentText && _isMarkdownView)
                  buildMarkdown(
                    context,
                    widget.message.content,
                    textSize: widget.textSize.toDouble(),
                    contextMenuBuilder: (ctx, state) => ContextMenuBuilders
                        .markdownChatMessageContextMenuBuilder(
                      context,
                      state,
                      onShowCommandsPressed: (text) {
                        flyoutController.showFlyout(
                          builder: (context) => _showCommandsFlyout(text),
                          position: mouseLocalPosition,
                        );
                      },
                      onMorePressed: () {
                        flyoutController.showFlyout(
                          builder: (context) => _showOptionsFlyout(context),
                          position: mouseLocalPosition,
                        );
                      },
                      onQuoteSelectedText: (text) {
                        final provider = context.read<ChatProvider>();
                        provider.messageController.text =
                            provider.messageController.text += '"$text" ';
                        promptTextFocusNode.requestFocus();
                      },
                      onImproveSelectedText: (text) {
                        final provider = context.read<ChatProvider>();
                        provider.sendMessage('Improve writing: "$text"',
                            hidePrompt: true);
                      },
                    ),
                  )
                else if (isContentText)
                  SelectableText(
                    widget.message.content,
                    contextMenuBuilder: (ctx, state) =>
                        ContextMenuBuilders.textChatMessageContextMenuBuilder(
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
                          builder: (context) => _showOptionsFlyout(context),
                          position: mouseLocalPosition,
                        );
                      },
                      onQuoteSelectedText: (text) {
                        final provider = context.read<ChatProvider>();
                        provider.messageController.text =
                            provider.messageController.text += '"$text" ';
                        promptTextFocusNode.requestFocus();
                      },
                      onImproveSelectedText: (text) {
                        final provider = context.read<ChatProvider>();
                        provider.sendMessage('Improve writing: "$text"',
                            hidePrompt: true);
                      },
                    ),
                    style: TextStyle(
                        fontSize: widget.textSize.toDouble(),
                        fontWeight: FontWeight.normal),
                  ),
                if (widget.message.type == FluentChatMessageType.file)
                  Button(
                    onPressed: () async {
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
                                    child: const Text('Close'),
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
                        Icon(FluentIcons.document_24_filled, size: 24),
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
                      for (final result in (widget.message.webResults!))
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
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            const Icon(
                                      FluentIcons.globe_16_regular,
                                      size: 24,
                                    ),
                                  ),
                                Text(
                                  result.title,
                                  style: FluentTheme.of(context)
                                      .typography
                                      .subtitle!,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.start,
                                  maxLines: 2,
                                ),

                                /// url short one line
                                Text(
                                  result.url,
                                  style: FluentTheme.of(context)
                                      .typography
                                      .caption!,
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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$formatDateTime, ',
                        style: FluentTheme.of(context).typography.caption!),
                    Text(
                      'T: ${widget.message.tokens}',
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.normal),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );

    return Focus(
      child: Stack(
        children: [
          GestureDetector(
            onSecondaryTap: () {
              flyoutController.showFlyout(
                builder: (context) => _showOptionsFlyout(context),
                position: mouseLocalPosition,
              );
            },
            child: Container(
              margin: const EdgeInsets.only(top: 4),
              padding: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.0),
                color: backgroundColor ?? context.theme.cardColor,
              ),
              child: tileWidget,
            ),
          ),
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
                      tooltip: 'Edit message',
                      icon: const Icon(FluentIcons.edit_12_regular),
                      onTap: () {
                        _showEditMessageDialog(context, widget.message);
                      },
                    ),
                    // only for the last 2 items
                    if (widget.indexMessage < 2)
                      SqueareIconButton(
                        tooltip: 'Regenerate message',
                        icon: widget.message.isTextFromMe
                            ? const Icon(FluentIcons.arrow_down_12_regular)
                            : const Icon(
                                FluentIcons.arrow_counterclockwise_16_filled),
                        onTap: () {
                          final provider = context.read<ChatProvider>();
                          final indexInReversedList =
                              messagesReversedList.indexOf(widget.message);
                          provider.regenerateMessage(widget.message,
                              indexInReversedList: indexInReversedList);
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
                              : const Icon(
                                  FluentIcons.sound_wave_circle_24_regular),
                      onTap: () async {
                        if (TextToSpeechService.isValid() == false) {
                          displayInfoBar(context, builder: (ctx, close) {
                            return InfoBar(
                              severity: InfoBarSeverity.warning,
                              title: Text(
                                  '${TextToSpeechService.serviceName} API key is not set'),
                              action: Button(
                                  child: const Text('Settings'),
                                  onPressed: () {
                                    Navigator.of(context).push(
                                      FluentPageRoute(builder: (context) {
                                        return const SettingsPage();
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
                                  title: Text(
                                      'Timeout exceeded. Please try again later.'),
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
                    tooltip: 'Copy to clipboard',
                    icon: const Icon(FluentIcons.copy_16_regular),
                    onTap: () async {
                      if (widget.message.type == FluentChatMessageType.image ||
                          widget.message.type ==
                              FluentChatMessageType.imageAi) {
                        {
                          final bytes = decodeImage(widget.message.content);
                          await Pasteboard.writeImage(bytes);
                          displayCopiedToClipboard();
                          return;
                        }
                      }
                      Clipboard.setData(
                          ClipboardData(text: widget.message.content));
                      displayCopiedToClipboard();
                    },
                  ),
                  SqueareIconButton(
                    tooltip: 'Delete',
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
                          builder: (context) => _showOptionsFlyout(context),
                        );
                      },
                      tooltip: 'More',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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

  void _showEditMessageDialog(BuildContext context, FluentChatMessage message) {
    final contentController = TextEditingController(text: message.content);
    final characterName = TextEditingController(text: message.creator);
    int tokens = message.tokens;
    final Debouncer debouncer = Debouncer(milliseconds: 500);
    final provider = context.read<ChatProvider>();
    final textStyle = DefaultTextStyle.of(context).style;
    bool canRegenerate = false;
    final isLastMessage = messagesReversedList.first == message;
    if (isLastMessage) {
      canRegenerate = true;
      final previousMessage =
          messagesReversedList.length > 1 ? messagesReversedList[1] : null;
      if (previousMessage?.type == FluentChatMessageType.textAi || message.type == FluentChatMessageType.textAi) {
        canRegenerate = false;
      }
    }
    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('Edit message'),
        constraints:
            const BoxConstraints(maxWidth: 800, maxHeight: 800, minHeight: 200),
        content: CallbackShortcuts(
          bindings: {
            if (Platform.isMacOS) ...{
              LogicalKeySet(
                  LogicalKeyboardKey.metaLeft, LogicalKeyboardKey.enter): () {
                final provider = context.read<ChatProvider>();
                provider.editMessage(
                  widget.message.id,
                  message.copyWith(
                    creator: characterName.text,
                    content: contentController.text,
                  ),
                );
                Navigator.of(ctx).pop();
              }
            } else ...{
              LogicalKeySet(
                  LogicalKeyboardKey.altLeft, LogicalKeyboardKey.enter): () {
                final provider = context.read<ChatProvider>();
                provider.editMessage(
                  widget.message.id,
                  message.copyWith(
                    creator: characterName.text,
                    content: contentController.text,
                  ),
                );
                Navigator.of(ctx).pop();
              },
            }
          },
          child: ListView(
            shrinkWrap: true,
            children: [
              const Text('Character name'),
              TextBox(controller: characterName, maxLines: 1),
              spacer,
              const Text('Content'),
              TextBox(
                autofocus: true,
                controller: contentController,
                minLines: 5,
                maxLines: 50,
                onChanged: (value) {
                  debouncer.run(
                    () async {
                      final count = await provider.countTokensString(value);
                      setState(() {
                        tokens = count;
                      });
                    },
                  );
                },
              ),
              Text('Tokens: $tokens'),
              Divider(),
              Text('Press tab to navigate to buttons below',
                  style: TextStyle(color: textStyle.color?.withAlpha(128))),
            ],
          ),
        ),
        actions: [
          if (canRegenerate)
            FilledButton(
                onPressed: () {
                  final provider = context.read<ChatProvider>();
                  final newMessage = message.copyWith(
                    creator: characterName.text,
                    content: contentController.text,
                  );
                  final indexInReversedList =
                      messagesReversedList.indexOf(widget.message);

                  provider
                      .regenerateMessage(newMessage,
                          indexInReversedList: indexInReversedList)
                      .then((value) {
                    provider.sortMessages();
                  });
                  Navigator.of(ctx).pop();
                },
                child: RichText(
                  text: TextSpan(
                    text: 'Apply ',
                    style: DefaultTextStyle.of(context).style,
                    children: <TextSpan>[
                      // TextSpan(
                      //   text: '(ctrl+alt+enter)',
                      //   style: TextStyle(
                      //     color: textStyle.color?.withAlpha(128),
                      //   ),
                      // ),
                    ],
                  ),
                )),
          Button(
            onPressed: () {
              final provider = context.read<ChatProvider>();
              provider.editMessage(
                widget.message.id,
                message.copyWith(
                  creator: characterName.text,
                  content: contentController.text,
                ),
              );
              Navigator.of(ctx).pop();
            },
            child: RichText(
              text: TextSpan(
                text: 'Apply silent ',
                style: DefaultTextStyle.of(context).style,
                children: <TextSpan>[
                  TextSpan(
                    text: '(alt+enter)',
                    style: TextStyle(color: textStyle.color?.withAlpha(128)),
                  ),
                ],
              ),
            ),
          ),
          Button(
              onPressed: () {
                Navigator.of(ctx).pop();
              },
              child: RichText(
                text: TextSpan(
                  text: 'Dissmiss ',
                  style: DefaultTextStyle.of(context).style,
                  children: <TextSpan>[
                    TextSpan(
                      text: '(esc)',
                      style: TextStyle(
                        color: textStyle.color?.withAlpha(128),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Future<void> _showImageDialog(
      BuildContext context, FluentChatMessage message) async {
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
        return ImageViewerDialog(
            provider: provider, description: message.imagePrompt);
      },
    );
  }

  List<MenuFlyoutItemBase> _buildMenuItems(
      List<CustomPrompt> commands, String selectedText) {
    List<MenuFlyoutItemBase> items = [];
    for (final command in commands) {
      if (command.showInContextMenu == false) {
        continue;
      }
      if (command.children.isNotEmpty) {
        items.add(MenuFlyoutSubItem(
          text: Text(command.title),
          leading: Icon(command.icon),
          items: (BuildContext context) {
            return _buildMenuItems(command.children, selectedText);
          },
        ));
      } else {
        items.add(MenuFlyoutItem(
          text: Text(command.title),
          leading: Icon(command.icon),
          onPressed: () {
            final provider = context.read<ChatProvider>();
            provider.sendToQuickOverlay(
                command.title, command.getPromptText(selectedText));
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
    return MenuFlyout(
        items: _buildMenuItems(customPrompts.value, selectedText));
  }

  MenuFlyout _showOptionsFlyout(BuildContext context) {
    final message = widget.message;
    return MenuFlyout(
      items: [
        MenuFlyoutItem(
            text: const Text('Shorter'),
            leading: const Icon(FluentIcons.text_align_justify_low_20_filled),
            onPressed: () {
              final provider = context.read<ChatProvider>();
              provider.shortenMessage(widget.message.id);
            }),
        MenuFlyoutItem(
            text: const Text('Longer'),
            leading: const Icon(FluentIcons.text_description_16_filled),
            onPressed: () {
              final provider = context.read<ChatProvider>();
              provider.lengthenMessage(widget.message.id);
            }),
        const MenuFlyoutSeparator(),
        MenuFlyoutItem(
            text: const Text('Continue'),
            leading: const Icon(FluentIcons.arrow_forward_20_filled),
            onPressed: () {
              final provider = context.read<ChatProvider>();
              provider.continueMessage(widget.message.id);
            }),
        if (message.isTextMessage) ...[
          MenuFlyoutItem(
            text: const Text('Remember this'),
            leading: const Icon(FluentIcons.brain_circuit_20_regular),
            onPressed: () async {
              final provider = context.read<ChatProvider>();
              final messageIndex = messagesReversedList.indexOf(message);
              final previous = messagesReversedList.length > messageIndex + 1
                  ? messagesReversedList[messageIndex + 1]
                  : null;
              final next = messagesReversedList.length > messageIndex - 1
                  ? messagesReversedList[messageIndex - 1]
                  : null;
              final messagesRange = await provider.convertMessagesToString([
                if (previous != null) previous,
                message,
                if (next != null) next,
              ]);
              messagesReversedList[messageIndex + 1];
              final information =
                  await provider.generateUserKnowladgeBasedOnText(
                messagesRange,
              );
              displayInfoBar(provider.context!, builder: (ctx, close) {
                return InfoBar(
                  title: const Text('Memory updated'),
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
                    child: Text('Open memory'),
                  ),
                );
              });
            },
          ),
          MenuFlyoutItem(
            text: const Text('Edit'),
            leading: const Icon(FluentIcons.edit_16_regular),
            onPressed: () async {
              await Navigator.of(context).maybePop();
              _showEditMessageDialog(
                  navigatorKey.currentContext!, widget.message);
            },
          ),
        ],
        MenuFlyoutSubItem(
          text: const Text('Commands'),
          trailing: const Icon(FluentIcons.chevron_right_16_filled),
          items: (context) =>
              _buildMenuItems(customPrompts.value, widget.message.content),
        ),
        if ((message.type == FluentChatMessageType.imageAi) ||
            message.type == FluentChatMessageType.image) ...[
          const MenuFlyoutSeparator(),
          MenuFlyoutItem(
            text: const Text('Save image to file'),
            leading: const Icon(FluentIcons.save_16_regular),
            onPressed: () => _saveImageToFile(context),
          ),
          MenuFlyoutItem(
            text: const Text('Copy image'),
            leading: const Icon(FluentIcons.copy_16_regular),
            onPressed: () => _copyImageToClipboard(context),
          ),
        ],
        const MenuFlyoutSeparator(),
        MenuFlyoutItem(
          text: const Text('New conversation branch from here'),
          leading: const Icon(FluentIcons.branch_20_regular),
          onPressed: () {
            final provider = context.read<ChatProvider>();
            provider.createNewBranchFromLastMessage(widget.message.id);
          },
        ),
        const MenuFlyoutSeparator(),
        MenuFlyoutItem(
          text: Text('Delete', style: TextStyle(color: Colors.red)),
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

    final item = DataWriterItem();
    final imageBytesString = widget.message.content;
    final imageBytes = base64.decode(imageBytesString);

    item.add(Formats.png(imageBytes));
    await SystemClipboard.instance!.write([item]);
    // ignore: use_build_context_synchronously
    displayCopiedToClipboard();
  }
}

class ImageViewerDialog extends StatefulWidget {
  const ImageViewerDialog({
    super.key,
    required this.provider,
    this.description,
    this.barrierDismissible = true,
  });

  final ImageProvider<Object> provider;
  final String? description;
  final bool barrierDismissible;

  @override
  State<ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<ImageViewerDialog> {
  bool isDescriptionVisible = false;
  bool fullScreen = false;
  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
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
                  fullScreen
                      ? FluentIcons.full_screen_minimize_16_filled
                      : FluentIcons.full_screen_maximize_16_filled,
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
              duration: Duration(milliseconds: 400),
              height: isDescriptionVisible ? 200 : 48,
              width: isDescriptionVisible ? MediaQuery.sizeOf(context).width - 300 : 48,
              decoration: BoxDecoration(
                color: context.theme.cardColor,
                borderRadius: BorderRadius.circular(10),
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
                isDescriptionVisible
                    ? FluentIcons.chevron_right_16_filled
                    : FluentIcons.chevron_left_16_filled,
              ),
              tooltip: 'Close',
            ),
          ),
        ]
      ],
    );
  }
}
