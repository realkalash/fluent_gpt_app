import 'dart:convert';
import 'dart:io';

import 'package:elevenlabs_flutter/elevenlabs_flutter.dart';
import 'package:fluent_gpt/common/custom_messages/text_file_custom_message.dart';
import 'package:fluent_gpt/common/custom_messages_src.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/features/text_to_speech.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/pages/home_page.dart';
import 'package:fluent_gpt/pages/settings_page.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/theme.dart';
import 'package:easy_image_viewer/easy_image_viewer.dart';
import 'package:file_selector/file_selector.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/context_menu_builders.dart';
import 'package:fluent_gpt/widgets/markdown_builders/code_wrapper.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gpt_tokenizer/flutter_gpt_tokenizer.dart';
import 'package:langchain/langchain.dart';
import 'package:mime_type/mime_type.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:provider/provider.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'markdown_builders/markdown_utils.dart';

class _MessageListTile extends StatelessWidget {
  const _MessageListTile({
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
      button: true,
      enabled: onPressed != null,
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
                      padding:
                          const EdgeInsets.only(left: 16, top: 4, bottom: 8),
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
    this.dateTime,
    required this.selectionMode,
    required this.id,
    required this.isError,
    required this.textSize,
    required this.isCompactMode,
  });
  final ChatMessage message;
  final String id;
  final DateTime? dateTime;
  final bool selectionMode;
  final bool isError;
  final bool isCompactMode;
  final int textSize;

  @override
  State<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard> {
  bool _isMarkdownView = true;
  bool _isFocused = false;
  bool _isLoadingReadAloud = false;
  final flyoutController = FlyoutController();
  static Tokenizer tokenizer = Tokenizer();

  @override
  void initState() {
    super.initState();
    _isMarkdownView = AppCache.isMarkdownViewEnabled.value ?? true;
  }

  @override
  Widget build(BuildContext context) {
    final formatDateTime = widget.dateTime == null
        ? ''
        : DateFormat('HH:mm:ss').format(widget.dateTime!);
    final appTheme = context.read<AppTheme>();
    final myMessageStyle = TextStyle(color: appTheme.color, fontSize: 14);
    final botMessageStyle = TextStyle(color: Colors.green, fontSize: 14);
    Widget tileWidget;

    if (widget.message is HumanChatMessage) {
      tileWidget = _MessageListTile(
        title: Row(
          children: [
            Text('$formatDateTime ',
                style: FluentTheme.of(context).typography.caption!),
            Text('You:', style: myMessageStyle),
          ],
        ),
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if ((widget.message as HumanChatMessage).content
                is ChatMessageContentImage)
              Image.memory(
                decodeImage(
                  ((widget.message as HumanChatMessage).content
                          as ChatMessageContentImage)
                      .data,
                ),
                fit: BoxFit.cover,
                gaplessPlayback: true,
              ),
            if ((widget.message as HumanChatMessage).content
                is ChatMessageContentText)
              SelectableText(
                widget.message.contentAsString,
                style: TextStyle(
                    fontSize: widget.textSize.toDouble(),
                    fontWeight: FontWeight.normal),
              ),
            if (widget.message is ChatMessageContentImage)
              GestureDetector(
                onTap: () {},
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    width: 400,
                    height: 400,
                    margin: const EdgeInsets.all(8.0),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12.0),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.4),
                            blurRadius: 10,
                            spreadRadius: 5,
                          )
                        ]),
                    child: Image.memory(
                      decodeImage(
                          (widget.message as ChatMessageContentImage).data),
                      fit: BoxFit.fitHeight,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
            if ((widget.message as HumanChatMessage).content
                is ChatMessageContentText)
              FutureBuilder(
                future: tokenizer.count(
                    ((widget.message as HumanChatMessage).content
                            as ChatMessageContentText)
                        .text,
                    modelName: 'gpt-4'),
                builder: (context, snapshot) {
                  if (snapshot.data is int) {
                    return Text('Tokens: ${snapshot.data}',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.normal));
                  }
                  return const SizedBox();
                },
              ),
          ],
        ),
      );
    } else if (widget.message is WebResultCustomMessage) {
      tileWidget = _MessageListTile(
        title: Wrap(
          children: [
            for (final result
                in (widget.message as WebResultCustomMessage).searchResults)
              SizedBox(
                width: 200,
                // height: 120,
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
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                            FluentIcons.globe_16_regular,
                            size: 24,
                          ),
                        ),
                      Text(
                        result.title,
                        style: FluentTheme.of(context).typography.subtitle!,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.start,
                        maxLines: 2,
                      ),

                      /// url short one line
                      Text(
                        result.url,
                        style: FluentTheme.of(context).typography.caption!,
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
      );
    } else if (widget.message is TextFileCustomMessage) {
      final message = widget.message as TextFileCustomMessage;
      tileWidget = _MessageListTile(
        title: Text('You:', style: myMessageStyle),
        subtitle: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Button(
              onPressed: () async {
                if (Platform.isWindows) {
                  final content = message.content;
                  showDialog(
                      context: context,
                      barrierDismissible: true,
                      builder: (ctx) {
                        return ContentDialog(
                          title: Text(message.fileName),
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
                    '${tempDir.path}${Platform.pathSeparator}${message.fileName.isEmpty ? 'file' : message.fileName}');
                await file.writeAsString(message.content);
                final mimeType = mime(file.path);
                await OpenFilex.open(file.path, type: mimeType);
              },
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.document_24_filled, size: 24),
                  Text(
                    message.fileName,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            FutureBuilder(
                future: message.tokensLenght,
                builder: (context, snapshot) {
                  if (snapshot.data is int) {
                    return Text('Tokens: ${snapshot.data}',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.normal));
                  }
                  return const SizedBox();
                })
          ],
        ),
      );
    } else {
      tileWidget = _MessageListTile(
        tileColor: widget.isError ? Colors.red.withOpacity(0.2) : null,
        title: Row(
          children: [
            Text('$formatDateTime ',
                style: FluentTheme.of(context).typography.caption!),
            Text('Ai:', style: botMessageStyle),
          ],
        ),
        subtitle: _isMarkdownView
            ? buildMarkdown(
                context,
                widget.message.contentAsString,
                textSize: widget.textSize.toDouble(),
                contextMenuBuilder: (ctx, textState) =>
                    ContextMenuBuilders.markdownChatMessageContextMenuBuilder(
                  ctx,
                  textState,
                  () {
                    flyoutController.showFlyout(
                      builder: (context) => _showOptionsFlyout(context),
                    );
                  },
                ),
              )
            : Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SelectableText(
                  widget.message.contentAsString,
                  contextMenuBuilder: (ctx, textState) =>
                      ContextMenuBuilders.textChatMessageContextMenuBuilder(
                    ctx,
                    textState,
                    () {
                      flyoutController.showFlyout(
                        builder: (context) => _showOptionsFlyout(context),
                      );
                    },
                  ),
                  style: TextStyle(
                    fontSize: widget.textSize.toDouble(),
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
      );
    }

    return Focus(
      onFocusChange: (isFocused) {
        setState(() {
          _isFocused = isFocused;
        });
      },
      child: Stack(
        children: [
          GestureDetector(
            onSecondaryTap: () {
              flyoutController.showFlyout(
                builder: (context) => _showOptionsFlyout(context),
              );
            },
            child: Card(
              margin: const EdgeInsets.all(4),
              padding: const EdgeInsets.only(bottom: 16),
              borderRadius: BorderRadius.circular(8.0),
              borderColor: _isFocused ? Colors.blue : Colors.transparent,
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
                  if (widget.message is AIChatMessage ||
                      (widget.message is HumanChatMessage &&
                          (widget.message as HumanChatMessage).content
                              is ChatMessageContentText))
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
                              widget.message.contentAsString,
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

                  SqueareIconButton(
                    tooltip: 'Copy to clipboard',
                    icon: const Icon(FluentIcons.copy_16_regular),
                    onTap: () async {
                      if (widget.message is HumanChatMessage) {
                        if ((widget.message as HumanChatMessage).content
                            is ChatMessageContentImage) {
                          final bytes =
                              decodeImage(widget.message.contentAsString);
                          await Pasteboard.writeImage(bytes);
                          displayCopiedToClipboard();
                          return;
                        }
                      }
                      Clipboard.setData(
                          ClipboardData(text: widget.message.contentAsString));
                      displayCopiedToClipboard();
                    },
                  ),
                  // additional options
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

  void _showEditMessageDialog(BuildContext context, ChatMessage message) {
    final contentController =
        TextEditingController(text: message.contentAsString);
    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('Edit message'),
        constraints:
            const BoxConstraints(maxWidth: 800, maxHeight: 800, minHeight: 200),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const IncludeConversationSwitcher(),
            const SizedBox(height: 8),
            Expanded(
              child: TextBox(
                controller: contentController,
                minLines: 5,
                maxLines: 50,
              ),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () {
              final provider = context.read<ChatProvider>();
              provider.editMessage(widget.id, contentController.text);
              Navigator.of(ctx).pop();
            },
            child: const Text('Apply'),
          ),
          Button(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
  }

  void _showImageDialog(BuildContext context, Map<String, String> message) {
    final image = decodeImage(message['image']!);
    final provider = Image.memory(
      image,
      filterQuality: FilterQuality.high,
    ).image;
    showImageViewer(context, provider);
  }

  @Deprecated('Not used')
  void _showContextMenuImage(
      BuildContext context, Map<String, String> message) {
    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('Image options'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 100,
              height: 100,
              clipBehavior: Clip.antiAlias,
              decoration:
                  BoxDecoration(borderRadius: BorderRadius.circular(12.0)),
              child: Image.memory(
                decodeImage(message['image']!),
                fit: BoxFit.fitHeight,
                gaplessPlayback: true,
              ),
            ),
            const SizedBox(height: 8),
            Button(
              onPressed: () {
                Navigator.of(context).maybePop();
                Pasteboard.writeImage(
                  decodeImage(message['image']!),
                );
                displayCopiedToClipboard();
              },
              child: const Text('Copy image data'),
            ),
            // save to file
            Button(
              onPressed: () async {
                final fileBytesString = message['image']!;
                final fileBytes = base64.decode(fileBytesString);
                final file = XFile.fromData(
                  fileBytes,
                  name: 'image.png',
                  mimeType: 'image/png',
                  length: fileBytes.length,
                );
                final first8Bytes = fileBytes.sublist(0, 8).toString();
                final FileSaveLocation? location = await getSaveLocation(
                  suggestedName: '$first8Bytes.png',
                  acceptedTypeGroups: [
                    const XTypeGroup(
                      label: 'images',
                      extensions: ['png', 'jpg', 'jpeg'],
                    ),
                  ],
                );

                if (location != null) {
                  // Save the file to the selected path
                  await file.saveTo(location.path);
                  // Optionally, show a confirmation message to the user
                }
              },
              child: const Text('Save image to file'),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Dismiss'),
          ),
        ],
      ),
    );
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
              provider.shortenMessage(widget.id);
            }),
        MenuFlyoutItem(
            text: const Text('Longer'),
            leading: const Icon(FluentIcons.text_description_16_filled),
            onPressed: () {
              final provider = context.read<ChatProvider>();
              provider.lengthenMessage(widget.id);
            }),
        const MenuFlyoutSeparator(),
        MenuFlyoutItem(
            text: const Text('Continue'),
            leading: const Icon(FluentIcons.arrow_forward_20_filled),
            onPressed: () {
              final provider = context.read<ChatProvider>();
              provider.continueMessage(widget.id);
            }),
        MenuFlyoutItem(
          text: const Text('Generate again'),
          leading: const Icon(FluentIcons.arrow_counterclockwise_16_filled),
          onPressed: () {
            final provider = context.read<ChatProvider>();
            provider.regenerateMessage(widget.message);
          },
        ),
        if (message is HumanChatMessage &&
            message.content is ChatMessageContentText)
          MenuFlyoutItem(
            text: const Text('Remember this'),
            leading: const Icon(FluentIcons.brain_circuit_20_regular),
            onPressed: () async {
              final provider = context.read<ChatProvider>();
              final information =
                  await provider.generateUserKnowladgeBasedOnText(
                widget.message.contentAsString,
              );
              displayInfoBar(provider.context!, builder: (ctx, close) {
                return InfoBar(
                  title: const Text('Updated info about user'),
                  content: Text(information),
                  severity: InfoBarSeverity.success,
                  isLong: true,
                );
              });
            },
          ),
        if (message is HumanChatMessage &&
            message.content is ChatMessageContentImage) ...[
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
            provider.createNewBranchFromLastMessage(widget.id);
          },
        ),
        const MenuFlyoutSeparator(),
        MenuFlyoutItem(
          text: Text('Delete', style: TextStyle(color: Colors.red)),
          leading: Icon(FluentIcons.delete_12_regular, color: Colors.red),
          onPressed: () {
            final provider = context.read<ChatProvider>();
            provider.deleteMessage(widget.id);
          },
        ),
      ],
    );
  }

  Future<void> _saveImageToFile(BuildContext context) async {
    final fileBytesString = widget.message.contentAsString;
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
      displayInfoBar(
        // ignore: use_build_context_synchronously
        context,
        builder: (context, close) => const InfoBar(
          title: Text('Image saved to file'),
          severity: InfoBarSeverity.success,
        ),
      );
      // ignore: use_build_context_synchronously
      Navigator.of(context).maybePop();
    }
  }

  _copyImageToClipboard(BuildContext context) async {
    Navigator.of(context).maybePop();

    final item = DataWriterItem();
    final imageBytesString = widget.message.contentAsString;
    final imageBytes = base64.decode(imageBytesString);

    item.add(Formats.png(imageBytes));
    await SystemClipboard.instance!.write([item]);
    // ignore: use_build_context_synchronously
    displayCopiedToClipboard();
  }
}
