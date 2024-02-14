// import 'package:chat_gpt_flutter/chat_gpt_flutter.dart';
import 'dart:async';
import 'dart:developer';

import 'package:chatgpt_windows_flutter_app/shell_driver.dart';
import 'package:chatgpt_windows_flutter_app/theme.dart';
import 'package:chatgpt_windows_flutter_app/tray.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as ic;
import 'package:flutter/material.dart' as mat;
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:url_launcher/url_launcher.dart';
import 'package:url_launcher/url_launcher_string.dart';

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
        Text(
          'Words: ${chatProvider.countWordsInAllMessages}',
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.normal),
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
        const _HotShurtcutsWidget(),
        const _InputField()
      ],
    );
  }
}

class _InputField extends StatefulWidget {
  const _InputField({super.key});

  @override
  State<_InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<_InputField> {
  void onSubmit(String text, ChatGPTProvider chatProvider) {
    if (text.trim().isEmpty) {
      return;
    }
    chatProvider.sendMessage(text.trim());
    chatProvider.messageController.clear();
    promptTextFocusNode.requestFocus();
  }

  bool _shiftPressed = false;
  final FocusNode _focusNode = FocusNode();
  @override
  Widget build(BuildContext context) {
    final ChatGPTProvider chatProvider = context.read<ChatGPTProvider>();

    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: (RawKeyEvent event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
              event.logicalKey == LogicalKeyboardKey.shiftRight) {
            _shiftPressed = true;
          } else if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter) {
            if (_shiftPressed) {
              // Shift+Enter pressed, go to the next line
              // print('Shift+Enter pressed');
            } else {
              // Enter pressed, send message
              print('Enter pressed');
              onSubmit(chatProvider.messageController.text, chatProvider);
            }
          }
        } else if (event is RawKeyUpEvent) {
          if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
              event.logicalKey == LogicalKeyboardKey.shiftRight) {
            _shiftPressed = false;
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
              child: TextBox(
                focusNode: promptTextFocusNode,
                prefix: (chatProvider.selectedChatRoom.commandPrefix == null ||
                        chatProvider.selectedChatRoom.commandPrefix == '')
                    ? null
                    : Tooltip(
                        message: chatProvider.selectedChatRoom.commandPrefix,
                        child: const Card(
                            margin: EdgeInsets.all(4),
                            padding: EdgeInsets.all(4),
                            child: Text('SMART')),
                      ),
                prefixMode: OverlayVisibilityMode.always,
                controller: chatProvider.messageController,
                minLines: 2,
                maxLines: 30,
                placeholder: 'Type your message here',
              ),
            ),
            const SizedBox(width: 8.0),
            Button(
              onPressed: () =>
                  onSubmit(chatProvider.messageController.text, chatProvider),
              child: const Text('Send'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HotShurtcutsWidget extends StatefulWidget {
  const _HotShurtcutsWidget({super.key});

  @override
  State<_HotShurtcutsWidget> createState() => _HotShurtcutsWidgetState();
}

class _HotShurtcutsWidgetState extends State<_HotShurtcutsWidget> {
  Timer? timer;
  String textFromClipboard = '';

  @override
  void initState() {
    super.initState();

    /// periodically checks the clipboard for text and displays a widget if there is text
    /// in the clipboard
    timer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      Clipboard.getData(Clipboard.kTextPlain).then((value) {
        if (value?.text != textFromClipboard) {
          textFromClipboard = value?.text ?? '';
          if (mounted) setState(() {});
        }
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    if (textFromClipboard.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final chatProvider = context.read<ChatGPTProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          /// align to the left start
          alignment: WrapAlignment.start,
          spacing: 4,
          runSpacing: 4,
          children: [
            Tooltip(
              message: 'Paste:\n$textFromClipboard',
              child: Container(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Button(
                  style: ButtonStyle(
                      backgroundColor: ButtonState.all(Colors.blue)),
                  onPressed: () {
                    chatProvider.sendMessage(textFromClipboard);
                  },
                  child: Text(
                    textFromClipboard.replaceAll('\n', '').trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            Button(
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(ic.FluentIcons.info_16_regular, size: 16),
                    Text('Explain'),
                  ],
                ),
                onPressed: () {
                  chatProvider.sendMessage('Explain: "$textFromClipboard"');
                }),
            Button(
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(ic.FluentIcons.book_16_regular, size: 16),
                    Text('Check grammar'),
                  ],
                ),
                onPressed: () {
                  chatProvider
                      .sendMessage('Check grammar: "$textFromClipboard"');
                }),
            Button(
                child: const Text('Translate to English'),
                onPressed: () {
                  chatProvider.sendMessage(
                      'Translate to English: "$textFromClipboard"');
                }),
            Button(
                child: const Text('Translate to Rus'),
                onPressed: () {
                  chatProvider
                      .sendMessage('Translate to Rus: "$textFromClipboard"');
                }),
          ],
        ),
      ),
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
                onTapLink: (text, href, title) => launchUrlString(href!),
                extensionSet: md.ExtensionSet(
                  md.ExtensionSet.gitHubFlavored.blockSyntaxes,
                  <md.InlineSyntax>[
                    md.EmojiSyntax(),
                    ...md.ExtensionSet.gitHubFlavored.inlineSyntaxes
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
                        },
                        child: const Text('Dismiss'),
                      ),
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
