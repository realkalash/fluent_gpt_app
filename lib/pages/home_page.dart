import 'dart:developer';

import 'package:chatgpt_windows_flutter_app/shell_driver.dart';
import 'package:chatgpt_windows_flutter_app/theme.dart';
import 'package:chatgpt_windows_flutter_app/widgets/input_field.dart';
import 'package:chatgpt_windows_flutter_app/widgets/markdown_builders/md_code_builder.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher_string.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as ic;

import '../providers/chat_gpt_provider.dart';

final promptTextFocusNode = FocusNode();

class ChatRoomPage extends StatelessWidget {
  const ChatRoomPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScaffoldPage(
      header: PageHeader(title: PageHeaderText()),
      content: ChatGPTContent(),
    );
  }
}

class PageHeaderText extends StatelessWidget {
  const PageHeaderText({super.key});

  @override
  Widget build(BuildContext context) {
    var chatProvider = context.watch<ChatGPTProvider>();
    final model = chatProvider.selectedModel.model;
    final selectedRoom = chatProvider.selectedChatRoomName;
    return Column(
      children: [
        Text('Chat GPT ($model) ($selectedRoom)'),
        Row(
          children: [
            Expanded(
              child: Text(
                'Words: ${chatProvider.countWordsInAllMessages}',
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.normal),
              ),
            ),
            if (chatProvider.selectionModeEnabled) ...[
              IconButton(
                icon: Icon(ic.FluentIcons.delete_16_filled, color: Colors.red),
                onPressed: () {
                  chatProvider.deleteSelectedMessages();
                },
              ),
              IconButton(
                icon: const Icon(FluentIcons.cancel),
                onPressed: () {
                  chatProvider.disableSelectionMode();
                },
              ),
            ]
          ],
        ),
      ],
    );
  }
}

class ChatGPTContent extends StatefulWidget {
  const ChatGPTContent({super.key});

  @override
  State<ChatGPTContent> createState() => _ChatGPTContentState();
}

class _ChatGPTContentState extends State<ChatGPTContent> {
  @override
  void initState() {
    super.initState();
    promptTextFocusNode.requestFocus();

    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      var chatProvider = context.read<ChatGPTProvider>();
      chatProvider.listItemsScrollController.animateTo(
        chatProvider.listItemsScrollController.position.maxScrollExtent + 200,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    var chatProvider = context.watch<ChatGPTProvider>();
    chatProvider.context = context;

    return Column(
      children: <Widget>[
        Expanded(
          child: ListView.builder(
            controller: chatProvider.listItemsScrollController,
            itemCount: chatProvider.messages.entries.length,
            itemBuilder: (context, index) {
              final message =
                  chatProvider.messages.entries.elementAt(index).value;
              final dateTimeRaw =
                  chatProvider.messages.entries.elementAt(index).key;
              final DateTime dateTime = DateTime.parse(dateTimeRaw);
              return MessageCard(
                message: message,
                dateTime: dateTime,
                selectionMode: chatProvider.selectionModeEnabled,
              );
            },
          ),
        ),
        const HotShurtcutsWidget(),
        const InputField()
      ],
    );
  }
}

class MessageCard extends StatefulWidget {
  const MessageCard(
      {super.key,
      required this.message,
      required this.dateTime,
      required this.selectionMode});
  final Map<String, String> message;
  final DateTime dateTime;
  final bool selectionMode;

  @override
  State<MessageCard> createState() => _MessageCardState();
}

class _MessageCardState extends State<MessageCard> {
  bool _isMarkdownView = true;
  bool _containsPythonCode = false;

  @override
  Widget build(BuildContext context) {
    final formatDateTime = DateFormat('HH:mm:ss').format(widget.dateTime);
    final appTheme = context.read<AppTheme>();
    final myMessageStyle = TextStyle(color: appTheme.color, fontSize: 14);
    final botMessageStyle = TextStyle(color: Colors.green, fontSize: 14);
    Widget tileWidget;
    Widget? leading = widget.selectionMode
        ? Checkbox(
            onChanged: (v) {
              final provider = context.read<ChatGPTProvider>();
              provider.toggleSelectMessage(widget.dateTime);
            },
            checked: widget.message['selected'] == 'true',
          )
        : null;
    if (widget.message['role'] == 'user') {
      tileWidget = ListTile(
        leading: leading,
        title: Text('You:', style: myMessageStyle),
        trailing: Text(formatDateTime,
            style: FluentTheme.of(context).typography.caption!),
        subtitle: SelectableText('${widget.message['content']}',
            style: FluentTheme.of(context).typography.body),
      );
    } else {
      tileWidget = ListTile(
        leading: leading,
        title: Text('${widget.message['role']}:', style: botMessageStyle),
        trailing: Text(formatDateTime,
            style: FluentTheme.of(context).typography.caption!),
        subtitle: !_isMarkdownView
            ? SelectableText('${widget.message['content']}',
                style: FluentTheme.of(context).typography.body)
            : Markdown(
                data: widget.message['content'] ?? '',
                softLineBreak: true,
                selectable: true,
                shrinkWrap: true,
                styleSheet: MarkdownStyleSheet(
                  code: const TextStyle(
                      fontSize: 14, backgroundColor: Colors.transparent),
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
    _containsPythonCode =
        widget.message['content'].toString().contains('```python');

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
                    actions: [
                      Button(
                        onPressed: () {
                          Navigator.of(context).maybePop();
                          provider.toggleSelectMessage(widget.dateTime);
                        },
                        child: const Text('Select'),
                      ),
                      Button(
                        onPressed: () {
                          Navigator.of(context).maybePop();
                        },
                        child: const Text('Dismiss'),
                      ),
                      Button(
                          onPressed: () {
                            Navigator.of(context).maybePop();
                            if (provider.selectionModeEnabled) {
                              provider.deleteSelectedMessages();
                            } else {
                              provider.deleteMessage(widget.dateTime);
                            }
                          },
                          style: ButtonStyle(
                              backgroundColor: ButtonState.all(Colors.red)),
                          child: provider.selectionModeEnabled
                              ? Text(
                                  'Delete ${provider.selectedMessages.length}')
                              : const Text('Delete')),
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
          child: Wrap(
            spacing: 4,
            children: [
              Tooltip(
                message: _isMarkdownView ? 'Show text' : 'Show markdown',
                child: SizedBox.square(
                  dimension: 30,
                  child: ToggleButton(
                    onChanged: (_) => setState(() {
                      _isMarkdownView = !_isMarkdownView;
                    }),
                    checked: false,
                    child: const Icon(FluentIcons.format_painter, size: 10),
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
                        ClipboardData(
                            text: widget.message['content'].toString()),
                      );
                    },
                    checked: false,
                    child: const Icon(FluentIcons.copy, size: 10),
                  ),
                ),
              ),
              if (_containsPythonCode)
                Tooltip(
                  message: 'Copy python code to clipboard',
                  child: SizedBox.square(
                    dimension: 30,
                    child: ToggleButton(
                      onChanged: (_) {
                        _copyPythonCodeToClipboard(
                            widget.message['content'].toString());
                      },
                      checked: false,
                      child: const Icon(FluentIcons.code, size: 10),
                    ),
                  ),
                ),
              if (_containsPythonCode)
                Tooltip(
                  message: 'Run python code',
                  child: RunPythonCodeButton(
                    code: getPythonCodeFromMarkdown(
                      widget.message['content'].toString(),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String getPythonCodeFromMarkdown(String string) {
    final lines = string.split('\n');
    final codeLines = <String>[];
    final regex = RegExp(r'```python');
    final endRegex = RegExp(r'```');
    var isCode = false;
    for (final line in lines) {
      if (regex.hasMatch(line)) {
        isCode = true;
        continue;
      }
      if (endRegex.hasMatch(line)) {
        isCode = false;
        continue;
      }
      if (isCode) {
        codeLines.add(line);
      }
    }
    return codeLines.join('\n');
  }

  void _copyPythonCodeToClipboard(String string) {
    final code = getPythonCodeFromMarkdown(string);
    log(code);
    Clipboard.setData(ClipboardData(text: code));
  }
}

class RunPythonCodeButton extends StatelessWidget {
  const RunPythonCodeButton({super.key, required this.code});
  final String code;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 30,
      child: StreamBuilder(
        stream: ShellDriver.isRunningStream,
        builder: (BuildContext ctx, AsyncSnapshot<dynamic> snap) {
          late Widget child;
          if (snap.data == true) {
            child = const Icon(FluentIcons.progress_ring_dots, size: 10);
          } else {
            child = const Icon(FluentIcons.play_solid, size: 10);
          }
          return ToggleButton(
            onChanged: (_) async {
              final result = await ShellDriver.runPythonCode(code);
              // ignore: use_build_context_synchronously
              Provider.of<ChatGPTProvider>(context, listen: false)
                  .sendResultOfRunningShellCode(result);
            },
            checked: snap.data == true,
            child: child,
          );
        },
      ),
    );
  }
}
