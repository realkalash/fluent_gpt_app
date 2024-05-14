import 'package:chatgpt_windows_flutter_app/dialogs/cost_dialog.dart';
import 'package:chatgpt_windows_flutter_app/log.dart';

import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:chatgpt_windows_flutter_app/common/chat_room.dart';
import 'package:chatgpt_windows_flutter_app/file_utils.dart';
import 'package:chatgpt_windows_flutter_app/main.dart';
import 'package:chatgpt_windows_flutter_app/shell_driver.dart';
import 'package:chatgpt_windows_flutter_app/system_messages.dart';
import 'package:chatgpt_windows_flutter_app/theme.dart';
import 'package:chatgpt_windows_flutter_app/widgets/input_field.dart';
import 'package:chatgpt_windows_flutter_app/widgets/markdown_builders/md_code_builder.dart';
import 'package:easy_image_viewer/easy_image_viewer.dart';
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

class ModelChooserCards extends StatelessWidget {
  const ModelChooserCards({super.key});
  static const textStyle = TextStyle(fontSize: 16, fontWeight: FontWeight.bold);

  Color applyOpacityIfSelected(bool isSelected, Color color) {
    if (!isSelected) {
      return color.withOpacity(0.2);
    }
    return color;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatGPTProvider>();
    final selectedModel = provider.selectedModel.model;
    final currentChat = provider.selectedChatRoomName;
    bool isGPT4O = selectedModel == 'gpt-4o';
    bool isGPT4 = selectedModel == 'gpt-4';
    bool isGPT3_5 = selectedModel == 'gpt-3.5-turbo';
    bool isLocal = selectedModel == 'local';
    return SizedBox(
      width: 400,
      height: 50,
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () =>
                  provider.selectModelForChat(currentChat, GPT4OModel()),
              child: Card(
                backgroundColor: applyOpacityIfSelected(isGPT4O, Colors.blue),
                child: const Text('GPT-4o',
                    style: textStyle, textAlign: TextAlign.center),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                provider.selectModelForChat(currentChat, Gpt4ChatModel());
              },
              child: Card(
                  backgroundColor:
                      applyOpacityIfSelected(isGPT4, Colors.yellow),
                  child: const Text('GPT-4',
                      style: textStyle, textAlign: TextAlign.center)),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () =>
                  provider.selectModelForChat(currentChat, GptTurboChatModel()),
              child: Card(
                  backgroundColor:
                      applyOpacityIfSelected(isGPT3_5, Colors.green),
                  child: const Text('GPT-3.5',
                      style: textStyle, textAlign: TextAlign.center)),
            ),
          ),
          GestureDetector(
            onTap: () =>
                provider.selectModelForChat(currentChat, LocalChatModel()),
            child: Card(
              backgroundColor: applyOpacityIfSelected(isLocal, Colors.purple),
              child: const Text('Local',
                  style: textStyle, textAlign: TextAlign.center),
            ),
          ),
        ],
      ),
    );
  }
}

class PageHeaderText extends StatelessWidget {
  const PageHeaderText({super.key});

  Future<void> editChatRoomDialog(
      BuildContext context, ChatRoom room, ChatGPTProvider provider) async {
    var roomName = room.chatRoomName;
    var commandPrefix = room.commandPrefix;
    var maxLength = room.maxTokenLength;
    var token = room.token;
    var orgID = room.orgID;
    await showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('Edit chat room'),
        actions: [
          Button(
            onPressed: () {
              provider.editChatRoom(
                room.chatRoomName,
                room.copyWith(
                  chatRoomName: roomName,
                  commandPrefix: commandPrefix,
                  maxLength: maxLength,
                  token: token,
                  orgID: orgID,
                ),
                switchToForeground: true,
              );
              Navigator.of(ctx).pop();
            },
            child: const Text('Save'),
          ),
          Button(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
        content: ListView(
          shrinkWrap: true,
          children: [
            const Text('Chat room name'),
            TextBox(
              controller: TextEditingController(text: room.chatRoomName),
              onChanged: (value) {
                roomName = value;
              },
            ),
            const Text('Command prefix'),
            TextBox(
              controller: TextEditingController(text: room.commandPrefix),
              onChanged: (value) {
                commandPrefix = value;
              },
            ),
            const Text('Max length'),
            TextBox(
              controller:
                  TextEditingController(text: room.maxTokenLength.toString()),
              onChanged: (value) {
                maxLength = int.parse(value);
              },
            ),
            const Text('Token'),
            TextBox(
              controller: TextEditingController(text: room.token),
              obscureText: true,
              onChanged: (value) {
                token = value;
              },
            ),
            const Text('Org ID'),
            TextBox(
              controller: TextEditingController(text: room.orgID),
              onChanged: (value) {
                orgID = value;
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    var chatProvider = context.watch<ChatGPTProvider>();
    final selectedRoom = chatProvider.selectedChatRoomName;
    return Column(
      children: [
        GestureDetector(
          onTap: () => editChatRoomDialog(
              context, chatProvider.chatRooms[selectedRoom]!, chatProvider),
          child: Text(selectedRoom, maxLines: 2),
        ),
        const ModelChooserCards(),
        Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Text(
                    'Words: ${chatProvider.countWordsInAllMessages}',
                    style: const TextStyle(
                        fontSize: 12, fontWeight: FontWeight.normal),
                  ),
                  HyperlinkButton(
                    onPressed: () {
                      showCostCalculatorDialog(context, chatProvider);
                    },
                    child: Text(
                      ' Tokens: ${chatProvider.selectedChatRoom.tokens ?? 0} | ${(chatProvider.selectedChatRoom.costUSD ?? 0.0).toStringAsFixed(4)}\$',
                      style: const TextStyle(fontSize: 12),
                    ),
                  )
                ],
              ),
            ),
            const IncludeConversationSwitcher(),
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

  void showCostCalculatorDialog(
      BuildContext context, ChatGPTProvider chatProvider) {
    final tokens = chatProvider.selectedChatRoom.tokens ?? 0;
    showDialog(
      context: context,
      builder: (context) => CostDialog(tokens: tokens),
    );
  }
}

class IncludeConversationSwitcher extends StatelessWidget {
  const IncludeConversationSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    final ChatGPTProvider chatProvider = context.watch<ChatGPTProvider>();
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text('Include conversation', style: TextStyle(fontSize: 12)),
        ToggleSwitch(
            checked: chatProvider.includeConversationGlobal,
            onChanged: (v) {
              chatProvider.setIncludeWholeConversation(v);
            }),
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

    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
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
        ),
        const Positioned(
          bottom: 128,
          right: 16,
          child: _ScrollToBottomButton(),
        ),
      ],
    );
  }
}

class _ScrollToBottomButton extends StatefulWidget {
  const _ScrollToBottomButton({super.key});

  @override
  State<_ScrollToBottomButton> createState() => __ScrollToBottomButtonState();
}

class __ScrollToBottomButtonState extends State<_ScrollToBottomButton> {
  bool isAtBottom = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final chatProvider = context.read<ChatGPTProvider>();
      chatProvider.listItemsScrollController.addListener(() {
        if (mounted == false) return;
        final isAtBottomNew = chatProvider.listItemsScrollController.offset ==
            chatProvider.listItemsScrollController.position.maxScrollExtent;
        if (isAtBottom == isAtBottomNew) return;
        if (isAtBottomNew) {
          setState(() {
            isAtBottom = true;
          });
        } else {
          setState(() {
            isAtBottom = false;
          });
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isAtBottom) {
      return const SizedBox.shrink();
    }
    return SizedBox.square(
      dimension: 48,
      child: GestureDetector(
          onTap: () {
            final chatProvider = context.read<ChatGPTProvider>();
            chatProvider.listItemsScrollController.animateTo(
              chatProvider.listItemsScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOut,
            );
          },
          child: const Card(child: Icon(FluentIcons.down, size: 16))),
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
  bool _containsCode = false;
  @override
  void initState() {
    super.initState();
    _isMarkdownView = prefs!.getBool('isMarkdownView') ?? true;
  }

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
        contentPadding: EdgeInsets.zero,
        onPressed: () {
          final provider = context.read<ChatGPTProvider>();
          provider.toggleSelectMessage(widget.dateTime);
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
            SelectableText(
              '${widget.message['content']}',
              style: FluentTheme.of(context).typography.body,
              selectionControls: fluentTextSelectionControls,
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
      tileWidget = ListTile(
        leading: leading,
        onPressed: () {
          final provider = context.read<ChatGPTProvider>();
          provider.toggleSelectMessage(widget.dateTime);
        },
        contentPadding: EdgeInsets.zero,
        title: Row(
          children: [
            Text('$formatDateTime ',
                style: FluentTheme.of(context).typography.caption!),
            Text('${widget.message['role']}:', style: botMessageStyle),
          ],
        ),
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
                        Button(
                          onPressed: () {
                            Navigator.of(context).maybePop();
                            provider.toggleSelectMessage(widget.dateTime);
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
                        ClipboardData(
                            text: widget.message['content'].toString()),
                      );
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

  String getCodeFromMarkdown(String assistantContent) {
    if (shellCommandRegex.hasMatch(assistantContent)) {
      final match = shellCommandRegex.firstMatch(assistantContent);
      final command = match?.group(1);
      if (command != null) {
        return command;
      }
    } else if (pythonCommandRegex.hasMatch(assistantContent)) {
      final match = pythonCommandRegex.firstMatch(assistantContent);
      final command = match?.group(1);
      if (command != null) {
        return command;
      }
    } else if (everythingSearchCommandRegex.hasMatch(assistantContent)) {
      final match = everythingSearchCommandRegex.firstMatch(assistantContent);
      final command = match?.group(1);
      if (command != null) {
        return command;
      }
    } else if (grammarCheckRegex.hasMatch(assistantContent)) {
      final match = grammarCheckRegex.firstMatch(assistantContent);
      final command = match?.group(1);
      if (command != null) {
        return command;
      }
    }

    return '';
  }

  void _copyCodeToClipboard(String string) {
    final code = getCodeFromMarkdown(string);
    log(code);
    Clipboard.setData(ClipboardData(text: code));
    displayInfoBar(
      context,
      builder: (context, close) => const InfoBar(
        title: Text('The result is copied to clipboard'),
        severity: InfoBarSeverity.info,
      ),
    );
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
}

class RunCodeButton extends StatelessWidget {
  const RunCodeButton({super.key, required this.code});
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
              final provider =
                  Provider.of<ChatGPTProvider>(context, listen: false);
              if (shellCommandRegex.hasMatch(code)) {
                final match = shellCommandRegex.firstMatch(code);
                final command = match?.group(1);
                if (command != null) {
                  final result = await ShellDriver.runShellCommand(command);
                  provider.sendResultOfRunningShellCode(result);
                }
              } else if (pythonCommandRegex.hasMatch(code)) {
                final match = pythonCommandRegex.firstMatch(code);
                final command = match?.group(1);
                if (command != null) {
                  final result = await ShellDriver.runPythonCode(command);
                  provider.sendResultOfRunningShellCode(result);
                }
              } else if (everythingSearchCommandRegex.hasMatch(code)) {
                final match = everythingSearchCommandRegex.firstMatch(code);
                final command = match?.group(1);
                if (command != null) {
                  final result =
                      await ShellDriver.runShellSearchFileCommand(command);
                  provider.sendResultOfRunningShellCode(result);
                }
              }
            },
            checked: snap.data == true,
            style: ToggleButtonThemeData(
              uncheckedButtonStyle:
                  ButtonStyle(backgroundColor: ButtonState.all(Colors.green)),
            ),
            child: child,
          );
        },
      ),
    );
  }
}
