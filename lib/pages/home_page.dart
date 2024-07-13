import 'dart:io';

import 'package:chatgpt_windows_flutter_app/common/prefs/app_cache.dart';
import 'package:chatgpt_windows_flutter_app/dialogs/cost_dialog.dart';
import 'package:chatgpt_windows_flutter_app/log.dart';
import 'package:chatgpt_windows_flutter_app/widgets/drop_region.dart';
import 'package:chatgpt_windows_flutter_app/widgets/message_list_tile.dart';
import 'package:file_selector/file_selector.dart';
import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:chatgpt_windows_flutter_app/common/chat_room.dart';
import 'package:chatgpt_windows_flutter_app/shell_driver.dart';
import 'package:chatgpt_windows_flutter_app/system_messages.dart';
import 'package:chatgpt_windows_flutter_app/widgets/input_field.dart';
import 'package:chatgpt_windows_flutter_app/widgets/markdown_builders/md_code_builder.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
// ignore: depend_on_referenced_packages
import 'package:rxdart/rxdart.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as ic;

import '../providers/chat_gpt_provider.dart';

final promptTextFocusNode = FocusNode();

class ChatRoomPage extends StatelessWidget {
  const ChatRoomPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const ScaffoldPage(
      header: PageHeader(title: PageHeaderText()),
      content: Stack(
        fit: StackFit.expand,
        children: [
          ChatGPTContent(),
          HomeDropOverlay(),
          HomeDropRegion(),
        ],
      ),
    );
  }
}

// isDropOverlayVisible is a BehaviorSubject that is used to show the overlay when a drag is over the drop region.
final BehaviorSubject<bool> isDropOverlayVisible =
    BehaviorSubject<bool>.seeded(false);

class HomeDropOverlay extends StatelessWidget {
  const HomeDropOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: isDropOverlayVisible,
      builder: (context, snapshot) {
        if (snapshot.data == true) {
          return Container(
            color: Colors.black.withOpacity(0.2),
            child: Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: FluentTheme.of(context).accentColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: const Center(
                  child: Icon(
                    FluentIcons.file_image,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class ModelChooserCards extends StatelessWidget {
  const ModelChooserCards({super.key});
  static const textStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.bold);

  Color applyOpacityIfSelected(bool isSelected, Color color) {
    if (!isSelected) {
      return color.withOpacity(0.2);
    }
    return color;
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ChatGPTProvider>();
    return StreamBuilder<Map<String, ChatRoom>>(
        stream: chatRoomsStream,
        builder: (context, snapshot) {
          final currentChat = selectedChatRoomName;
          bool isGPT4O = selectedModel.model == 'gpt-4o';
          bool isGPT4 = selectedModel.model == 'gpt-4';
          bool isGPT3_5 = selectedModel.model == 'gpt-3.5-turbo';
          bool isLocal = selectedModel.model == 'local';
          return SizedBox(
            width: 400,
            height: 46,
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () =>
                        provider.selectModelForChat(currentChat, GPT4OModel()),
                    child: Card(
                      backgroundColor:
                          applyOpacityIfSelected(isGPT4O, Colors.blue),
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
                    onTap: () => provider.selectModelForChat(
                        currentChat, GptTurboChatModel()),
                    child: Card(
                        backgroundColor:
                            applyOpacityIfSelected(isGPT3_5, Colors.green),
                        child: const Text('GPT-3.5',
                            style: textStyle, textAlign: TextAlign.center)),
                  ),
                ),
                GestureDetector(
                  onTap: () => provider.selectModelForChat(
                      currentChat, LocalChatModel()),
                  child: Card(
                    backgroundColor:
                        applyOpacityIfSelected(isLocal, Colors.purple),
                    child: const Text('Local',
                        style: textStyle, textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          );
        });
  }
}

class PageHeaderText extends StatelessWidget {
  const PageHeaderText({super.key});

  Future<void> editChatRoomDialog(
      BuildContext context, ChatRoom room, ChatGPTProvider provider) async {
    var roomName = room.chatRoomName;
    var commandPrefix = room.systemMessage;
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
              controller: TextEditingController(text: room.systemMessage),
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
    final selectedRoom = selectedChatRoomName;
    return Column(
      children: [
        GestureDetector(
          onTap: () => editChatRoomDialog(
              context, chatRooms[selectedRoom]!, chatProvider),
          child: Text(selectedRoom, maxLines: 2),
        ),
        const ModelChooserCards(),
        Row(
          children: [
            HyperlinkButton(
              style: ButtonStyle(
                padding: ButtonState.all(EdgeInsets.zero),
              ),
              onPressed: () => showCostCalculatorDialog(context),
              child: Text(
                ' Tokens: ${selectedChatRoom.tokens ?? 0} | ${(selectedChatRoom.costUSD ?? 0.0).toStringAsFixed(4)}\$',
                style: const TextStyle(fontSize: 12),
              ),
            ),
            const Spacer(),
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

  void showCostCalculatorDialog(BuildContext context) {
    final tokens = selectedChatRoom.tokens ?? 0;
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
        FlyoutListTile(
          text: const Icon(FluentIcons.full_history),
          tooltip: 'Include conversation',
          trailing: Checkbox(
            checked: chatProvider.includeConversationGlobal,
            onChanged: (value) {
              chatProvider.setIncludeWholeConversation(value ?? false);
            },
          ),
        ),
        FlyoutListTile(
          text: const Icon(FluentIcons.search_data),
          tooltip: 'Tool Search files',
          trailing: Checkbox(
            checked: AppCache.gptToolSearchEnabled.value!,
            onChanged: (value) {
              AppCache.gptToolSearchEnabled.value = value;
              // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
              chatProvider.notifyListeners();
            },
          ),
        ),
        FlyoutListTile(
          text: const Icon(FluentIcons.python_language),
          tooltip: 'Tool Python code execution',
          trailing: Checkbox(
            checked: AppCache.gptToolPythonEnabled.value!,
            onChanged: (value) {
              AppCache.gptToolPythonEnabled.value = value;
              // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
              chatProvider.notifyListeners();
            },
          ),
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

    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          children: <Widget>[
            Expanded(
              child: StreamBuilder(
                  stream: chatRoomsStream,
                  builder: (context, snapshot) {
                    return ListView.builder(
                      controller: chatProvider.listItemsScrollController,
                      itemCount: messages.entries.length,
                      itemBuilder: (context, index) {
                        final message = messages.entries.elementAt(index).value;
                        final dateTimeRaw =
                            messages.entries.elementAt(index).value['created'];

                        return MessageCard(
                          id: messages.entries.elementAt(index).key,
                          message: message,
                          dateTime: DateTime.tryParse(dateTimeRaw ?? ''),
                          selectionMode: chatProvider.selectionModeEnabled,
                          isError: message['error'] == 'true',
                          textSize: chatProvider.textSize,
                          isCompactMode: false,
                        );
                      },
                    );
                  }),
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

void displayCopiedToClipboard(BuildContext context) {
  displayInfoBar(
    context,
    builder: (context, close) => const InfoBar(
      title: Text('The result is copied to clipboard'),
      severity: InfoBarSeverity.info,
    ),
  );
}

void chooseCodeBlockDialog(BuildContext context, List<String> blocks) {
  showDialog(
    context: context,
    builder: (ctx) => ContentDialog(
      title: const Text('Choose code block'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final block in blocks) ...[
            ListTile(
              onPressed: () {},
              title: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(
                    dimension: 30,
                    child: ToggleButton(
                      onChanged: (_) {
                        Clipboard.setData(ClipboardData(text: block));
                        displayCopiedToClipboard(context);
                      },
                      checked: false,
                      child: const Icon(FluentIcons.copy, size: 10),
                    ),
                  ),
                  RunCodeButton(code: block),
                ],
              ),
              subtitle: Markdown(
                data: '```python\n$block\n```',
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
              ),
            ),
          ],
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

/// Extracts code snippets from a given assistant content.
///
/// The [assistantContent] parameter is the content provided by the assistant.
/// It searches for specific patterns using regular expressions and extracts the code snippets.
/// The extracted code snippets are returned as a list of strings.
List<String> getCodeFromMarkdown(String assistantContent) {
  List<String> codeList = [];

  final regexList = [
    shellCommandRegex,
    pythonCommandRegex,
    everythingSearchCommandRegex,
    copyToCliboardRegex,
  ];

  for (final regex in regexList) {
    final matches = regex.allMatches(assistantContent);
    for (final match in matches) {
      final command = match.group(1);
      if (command != null) {
        codeList.add(command);
      }
    }
  }
  if (codeList.isEmpty) {
    final unknownMatches = unknownCodeBlockRegex.allMatches(assistantContent);
    for (final match in unknownMatches) {
      final command = match.group(2);
      if (command != null) {
        codeList.add(command);
      }
    }
  }

  return codeList;
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
              final codeBlocks = getCodeFromMarkdown(code);
              if (codeBlocks.length > 1) {
                chooseCodeBlockDialog(context, codeBlocks);
                return;
              }

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
