import 'dart:convert';
import 'dart:developer';
import 'dart:ffi';

import 'package:chatgpt_windows_flutter_app/common/prefs/app_cache.dart';
import 'package:chatgpt_windows_flutter_app/file_utils.dart';
import 'package:chatgpt_windows_flutter_app/main.dart';
import 'package:chatgpt_windows_flutter_app/pages/home_page.dart';
import 'package:chatgpt_windows_flutter_app/providers/chat_gpt_provider.dart';
import 'package:chatgpt_windows_flutter_app/theme.dart';
import 'package:easy_image_viewer/easy_image_viewer.dart';
import 'package:file_selector/file_selector.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:url_launcher/url_launcher_string.dart';

// ignore: depend_on_referenced_packages
import 'package:intl/intl.dart';
import 'package:markdown/markdown.dart' as md;

import 'markdown_builders/md_code_builder.dart';

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
      child: Container(
        decoration: BoxDecoration(
          color: tileColor ?? FluentTheme.of(context).cardColor,
          borderRadius: BorderRadius.circular(8.0),
        ),
        alignment: Alignment.centerLeft,
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
  final Map<String, String> message;
  final DateTime? dateTime;
  final bool selectionMode;
  final String id;
  final bool isError;
  final bool isCompactMode;
  final int textSize;

  @override
  State<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard> {
  bool _isMarkdownView = true;
  bool _containsCode = false;
  @override
  void initState() {
    super.initState();
    _isMarkdownView = AppCache.isMarkdownView.value ?? true;
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
    Widget? leading = widget.selectionMode
        ? Checkbox(
            onChanged: (v) {
              final provider = context.read<ChatGPTProvider>();
              provider.toggleSelectMessage(widget.id);
            },
            checked: widget.message['selected'] == 'true',
          )
        : null;
    if (widget.message['role'] == 'user') {
      tileWidget = _MessageListTile(
        leading: leading,
        tileColor: widget.message['commandMessage'] == 'true'
            ? Colors.blue.withOpacity(0.5)
            : null,
        onPressed: () {
          final provider = context.read<ChatGPTProvider>();
          provider.toggleSelectMessage(widget.id);
        },
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
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.message['commandMessage'] == 'true')
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Command prompt'),
                      IconButton(
                        icon: Icon(widget.message['hidePrompt'] == 'true'
                            ? FluentIcons.chevron_down
                            : FluentIcons.chevron_up),
                        onPressed: () {
                          final provider = context.read<ChatGPTProvider>();
                          provider.toggleHidePrompt(widget.id);
                        },
                      ),
                    ],
                  ),
                if (widget.message['hidePrompt'] != 'true')
                  SelectableText(
                    '${widget.message['content']}',
                    style: FluentTheme.of(context).typography.body?.copyWith(
                          fontSize: widget.textSize.toDouble(),
                        ),
                    selectionControls: fluentTextSelectionControls,
                  ),
              ],
            ),
            if (widget.message['image'] != null)
              GestureDetector(
                onTap: () {
                  _showImageDialog(context, widget.message);
                },
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
                      decodeImage(widget.message['image']!),
                      fit: BoxFit.fitHeight,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
    } else {
      tileWidget = _MessageListTile(
        leading: leading,
        tileColor: widget.isError ? Colors.red.withOpacity(0.2) : null,
        onPressed: () {
          final provider = context.read<ChatGPTProvider>();
          provider.toggleSelectMessage(widget.id);
        },
        title: Row(
          children: [
            Text('$formatDateTime ',
                style: FluentTheme.of(context).typography.caption!),
            Text('${widget.message['role']}:', style: botMessageStyle),
          ],
        ),
        subtitle: !_isMarkdownView
            ? SelectableText(
                '${widget.message['content']}',
                style: FluentTheme.of(context).typography.body?.copyWith(
                      fontSize: widget.textSize.toDouble(),
                    ),
              )
            : Markdown(
                data: widget.message['content'] ?? '',
                softLineBreak: true,
                selectable: true,
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(fontSize: widget.textSize.toDouble()),
                  code: TextStyle(
                    fontSize: widget.textSize.toDouble() + 2,
                    backgroundColor: Colors.transparent,
                  ),
                ),
                builders: {
                  'code': CodeElementBuilder(
                      isDarkTheme: FluentTheme.of(context).brightness ==
                          Brightness.dark),
                },
                onTapLink: (text, href, title) => launchUrlString(href!),
                extensionSet: md.ExtensionSet(
                  md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                  <md.InlineSyntax>[
                    md.EmojiSyntax(),
                    ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes,
                  ],
                ),
              ),
      );
    }
    _containsCode = widget.message['content'].toString().contains('```');

    return Stack(
      children: [
        GestureDetector(
          onSecondaryTap: () {
            showDialog(
                context: context,
                builder: (ctx) {
                  final provider = context.read<ChatGPTProvider>();
                  return ContentDialog(
                    title: const Text('Message options'),
                    content: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.message['image'] != null)
                          Container(
                            width: 100,
                            height: 100,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12.0)),
                            child: Image.memory(
                              decodeImage(widget.message['image']!),
                              fit: BoxFit.fitHeight,
                              gaplessPlayback: true,
                            ),
                          ),
                        const SizedBox(height: 8),
                        Button(
                          onPressed: () async {
                            Navigator.of(context).maybePop();

                            final item = DataWriterItem();
                            final imageBytesString = widget.message['image']!;
                            final imageBytes = base64.decode(imageBytesString);

                            item.add(Formats.png(imageBytes));
                            await SystemClipboard.instance!.write([item]);
                            // ignore: use_build_context_synchronously
                            displayCopiedToClipboard(context);
                          },
                          child: const Text('Copy image data'),
                        ),
                        const SizedBox(height: 8),
                        Button(
                          onPressed: () async {
                            final fileBytesString = widget.message['image']!;
                            final fileBytes = base64.decode(fileBytesString);
                            final file = XFile.fromData(
                              fileBytes,
                              name: 'image.png',
                              mimeType: 'image/png',
                              length: fileBytes.lengthInBytes,
                            );

                            final FileSaveLocation? location =
                                await getSaveLocation(
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
                        Button(
                          onPressed: () {
                            Navigator.of(context).maybePop();
                            provider.toggleSelectMessage(widget.id);
                          },
                          child: const Text('Select'),
                        ),
                        const SizedBox(height: 8),
                        Button(
                          onPressed: () {
                            Navigator.of(context).maybePop();
                            _showRawMessageDialog(context, widget.message);
                          },
                          child: const Text('Show raw message'),
                        ),
                        const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Divider(),
                        ),
                        if (provider.selectionModeEnabled)
                          Button(
                            onPressed: () {
                              Navigator.of(context).maybePop();
                              provider.mergeSelectedMessagesToAssistant();
                            },
                            child: Text(
                                'Merge ${provider.selectedMessages.length} messages'),
                          ),
                        const SizedBox(height: 8),
                        Button(
                            onPressed: () {
                              Navigator.of(context).maybePop();
                              if (provider.selectionModeEnabled) {
                                provider.deleteSelectedMessages();
                                provider.disableSelectionMode();
                              } else {
                                provider.deleteMessage(widget.id);
                              }
                            },
                            style: ButtonStyle(
                                backgroundColor: ButtonState.all(Colors.red)),
                            child: provider.selectionModeEnabled
                                ? Text(
                                    'Delete ${provider.selectedMessages.length}')
                                : const Text('Delete')),
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
          },
          child: Card(
            margin: const EdgeInsets.all(4),
            padding: EdgeInsets.zero,
            borderRadius: BorderRadius.circular(8.0),
            child: tileWidget,
          ),
        ),
        Positioned(
          right: 16,
          top: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Tooltip(
                message: _isMarkdownView ? 'Show text' : 'Show markdown',
                child: SizedBox.square(
                  dimension: 30,
                  child: ToggleButton(
                    onChanged: (_) {
                      setState(() {
                        _isMarkdownView = !_isMarkdownView;
                      });
                      prefs!.setBool('isMarkdownView', _isMarkdownView);
                    },
                    checked: false,
                    child: const Icon(FluentIcons.format_painter, size: 10),
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
                    child: const Icon(FluentIcons.edit, size: 10),
                  ),
                ),
              ),
              Tooltip(
                message: 'Copy text to clipboard',
                child: SizedBox.square(
                  dimension: 30,
                  child: ToggleButton(
                    onChanged: (_) {
                      Clipboard.setData(
                        ClipboardData(text: '${widget.message['content']}'),
                      );
                      displayCopiedToClipboard(context);
                    },
                    checked: false,
                    child: const Icon(FluentIcons.copy, size: 10),
                  ),
                ),
              ),
              if (_containsCode)
                Tooltip(
                  message: 'Copy python code to clipboard',
                  child: SizedBox.square(
                    dimension: 30,
                    child: ToggleButton(
                      onChanged: (_) {
                        _copyCodeToClipboard(
                            widget.message['content'].toString());
                      },
                      checked: false,
                      style: ToggleButtonThemeData(
                        uncheckedButtonStyle: ButtonStyle(
                            backgroundColor: ButtonState.all(Colors.blue)),
                      ),
                      child: const Icon(FluentIcons.code, size: 10),
                    ),
                  ),
                ),
              if (_containsCode)
                Tooltip(
                  message: 'Run python code',
                  child: RunCodeButton(
                    code: widget.message['content'].toString(),
                  ),
                ),
            ],
          ),
        ),
      ],
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
      displayCopiedToClipboard(context);
      return;
    }
    // if more than one code snippet is found, show a dialog to select one
    chooseCodeBlockDialog(context, code);
  }

  void _showRawMessageDialog(
      BuildContext context, Map<String, String> message) {
    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('Raw message'),
        content: SelectableText.rich(
          TextSpan(
            children: [
              for (final entry in message.entries) ...[
                TextSpan(
                  text: '"${entry.key}": ',
                  style: TextStyle(color: Colors.blue),
                ),
                TextSpan(
                  text: '"${entry.value}",\n',
                  style: TextStyle(color: Colors.green),
                ),
              ],
            ],
          ),
          style: FluentTheme.of(context).typography.body,
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

  void _showEditMessageDialog(
      BuildContext context, Map<String, String> message) {
    final contentController = TextEditingController(text: message['content']);
    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('Edit message'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const IncludeConversationSwitcher(),
            const SizedBox(height: 8),
            TextBox(
              controller: contentController,
              minLines: 5,
              maxLines: 10,
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () {
              final provider = context.read<ChatGPTProvider>();
              provider.editMessage(message, contentController.text);
              provider.regenerateMessage(message);
              Navigator.of(ctx).pop();
            },
            child: const Text('Save & regenerate'),
          ),
          Button(
            onPressed: () {
              final provider = context.read<ChatGPTProvider>();
              provider.editMessage(message, contentController.text);
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
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
                Clipboard.setData(
                  ClipboardData(text: message['image']!),
                );
                displayCopiedToClipboard(context);
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
}
