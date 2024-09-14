import 'dart:convert';

import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/common/scrapper/web_scrapper.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/pages/home_page.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/theme.dart';
import 'package:easy_image_viewer/easy_image_viewer.dart';
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:langchain/langchain.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:provider/provider.dart';
import 'package:super_clipboard/super_clipboard.dart';

// ignore: depend_on_referenced_packages
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
  final flyoutController = FlyoutController();

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
          ],
        ),
      );
    } else if (widget.message is CustomChatMessage) {
      final message = widget.message as CustomChatMessage;
      dynamic jsonContent;
      try {
        jsonContent = jsonDecode(message.content);
      } catch (e, stack) {
        logError(e.toString(), stack);
      }
      if (jsonContent is List) {
        final results =
            jsonContent.map((e) => SearchResult.fromJson(e)).toList();
        tileWidget = _MessageListTile(
          title: Wrap(
            children: [
              for (final result in results)
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
      } else {
        tileWidget = const Text('Unknown message type');
      }
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
              )
            : Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: SelectableText(
                  widget.message.contentAsString,
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
              _onSecondaryTap(context, widget.message);
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
                  Tooltip(
                    message: _isMarkdownView ? 'Show text' : 'Show markdown',
                    child: SizedBox.square(
                      dimension: 30,
                      child: ToggleButton(
                        onChanged: (_) {
                          AppCache.isMarkdownViewEnabled.value =
                              !_isMarkdownView;
                          setState(() {
                            _isMarkdownView = !_isMarkdownView;
                          });
                        },
                        checked: _isMarkdownView,
                        child: const Icon(FluentIcons.paint_brush_12_regular,
                            size: 10),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Edit message',
                    child: SizedBox.square(
                      dimension: 30,
                      child: ToggleButton(
                        onChanged: (_) {
                          _showEditMessageDialog(context, widget.message);
                        },
                        checked: false,
                        child:
                            const Icon(FluentIcons.edit_12_regular, size: 10),
                      ),
                    ),
                  ),
                  Tooltip(
                    message: 'Copy to clipboard',
                    child: SizedBox.square(
                      dimension: 30,
                      child: Button(
                        onPressed: () async {
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
                          Clipboard.setData(ClipboardData(
                              text: widget.message.contentAsString));
                          displayCopiedToClipboard();
                        },
                        child:
                            const Icon(FluentIcons.copy_16_regular, size: 10),
                      ),
                    ),
                  ),
                  // additional options
                  SizedBox.square(
                    dimension: 30,
                    child: FlyoutTarget(
                      controller: flyoutController,
                      child: Button(
                        onPressed: () => flyoutController.showFlyout(
                          builder: (context) => _showOptionsFlyout(context),
                        ),
                        child: const Icon(FluentIcons.more_vertical_16_filled,
                            size: 10),
                      ),
                    ),
                  )
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

  void _onSecondaryTap(BuildContext context, ChatMessage message) {
    showDialog(
        context: context,
        builder: (ctx) {
          final provider = context.read<ChatProvider>();
          return ContentDialog(
            title: const Text('Message options'),
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Button(
                  onPressed: () async {
                    Navigator.of(context).maybePop();

                    final item = DataWriterItem();
                    final imageBytesString = widget.message.contentAsString;
                    final imageBytes = base64.decode(imageBytesString);

                    item.add(Formats.png(imageBytes));
                    await SystemClipboard.instance!.write([item]);
                    // ignore: use_build_context_synchronously
                    displayCopiedToClipboard();
                  },
                  child: const Text('Copy image data'),
                ),
                const SizedBox(height: 8),
                Button(
                  onPressed: () async {
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
                  },
                  child: const Text('Save image to file'),
                ),
                const SizedBox(height: 8),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Divider(),
                ),
                const SizedBox(height: 8),
                Button(
                    onPressed: () {
                      Navigator.of(context).maybePop();
                      provider.deleteMessage(widget.id);
                    },
                    style: ButtonStyle(
                        backgroundColor: WidgetStateProperty.all(Colors.red)),
                    child: const Text('Delete')),
              ],
            ),
            actions: [
              Button(
                onPressed: () {
                  Navigator.of(context).maybePop();
                },
                child: const Text('Dismiss'),
              ),
            ],
          );
        });
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
              provider.sendMessage('Continue');
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
}
