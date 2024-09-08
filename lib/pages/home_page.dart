import 'package:fluent_gpt/common/conversaton_style_enum.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/dialogs/chat_room_dialog.dart';
import 'package:fluent_gpt/dialogs/cost_dialog.dart';
import 'package:fluent_gpt/dialogs/edit_conv_length_dialog.dart';
import 'package:fluent_gpt/dialogs/search_chat_dialog.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/pages/prompts_settings_page.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/drop_region.dart';
import 'package:fluent_gpt/widgets/markdown_builders/markdown_utils.dart';
import 'package:fluent_gpt/widgets/message_list_tile.dart';
import 'package:fluent_gpt/shell_driver.dart';
import 'package:fluent_gpt/system_messages.dart';
import 'package:fluent_gpt/widgets/input_field.dart';
import 'package:fluent_gpt/widgets/selectable_color_container.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as ic;
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:widget_and_text_animator/widget_and_text_animator.dart';

import '../providers/chat_provider.dart';

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

class ConversationStyleRow extends StatelessWidget {
  const ConversationStyleRow({super.key});

  @override
  Widget build(BuildContext context) {
    return Expander(
      contentPadding: EdgeInsets.zero,
      header: const Text(
        'Conversation style',
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
      ),
      content: StreamBuilder(
        stream: conversationLenghtStyleStream,
        builder: (_, __) => StreamBuilder<Object>(
            stream: conversationStyleStream,
            builder: (context, snapshot) {
              final lenghtStyle = conversationLenghtStyleStream.value;
              final style = conversationStyleStream.value;
              return Column(
                children: [
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ConversationStyleEnum.values
                          .map((e) => SelectableColorContainer(
                                selectedColor:
                                    FluentTheme.of(context).accentColor,
                                unselectedColor: FluentTheme.of(context)
                                    .accentColor
                                    .withOpacity(0.5),
                                isSelected: style == e,
                                onTap: () => conversationStyleStream.add(e),
                                child: Text(e.name,
                                    style: const TextStyle(fontSize: 12)),
                              ))
                          .toList(),
                    ),
                  ),
                  Text(
                    'Conversation length',
                    style: FluentTheme.of(context).typography.subtitle,
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: ConversationLengthStyleEnum.values.map((e) {
                        return SelectableColorContainer(
                          selectedColor: FluentTheme.of(context).accentColor,
                          unselectedColor: FluentTheme.of(context)
                              .accentColor
                              .withOpacity(0.5),
                          isSelected: lenghtStyle == e,
                          onTap: () => conversationLenghtStyleStream.add(e),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(e.name,
                                  style: const TextStyle(fontSize: 12)),
                              SizedBox.square(
                                dimension: 16,
                                child: Button(
                                  style: ButtonStyle(
                                    padding: WidgetStateProperty.all(
                                        EdgeInsets.zero),
                                  ),
                                  onPressed: () =>
                                      editConversationStyle(context, e),
                                  child: const Icon(
                                      ic.FluentIcons.edit_20_regular),
                                ),
                              )
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              );
            }),
      ),
    );
  }

  editConversationStyle(
      BuildContext context, ConversationLengthStyleEnum item) async {
    final ConversationLengthStyleEnum? newItem =
        await ConversationStyleDialog.show(context, item);
    if (newItem != null) {
      final indexOldItem = ConversationLengthStyleEnum.values.indexOf(item);
      ConversationLengthStyleEnum.values.remove(item);
      ConversationLengthStyleEnum.values.insert(indexOldItem, newItem);
      // to update the UI
      conversationLenghtStyleStream.add(conversationLenghtStyleStream.value);
    }
  }
}

class PageHeaderText extends StatelessWidget {
  const PageHeaderText({super.key});

  @override
  Widget build(BuildContext context) {
    var chatProvider = context.watch<ChatProvider>();
    return Focus(
      canRequestFocus: false,
      descendantsAreTraversable: false,
      child: Column(
        children: [
          StreamBuilder(
            stream: selectedChatRoomIdStream,
            builder: (_, __) {
              return GestureDetector(
                onTap: () => EditChatRoomDialog.show(
                  context: context,
                  room: selectedChatRoom,
                  onOkPressed: () {},
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                        child: TextAnimator(
                      selectedChatRoom.chatRoomName,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                    )),
                    if (AppCache.openAiApiKey.value == null ||
                        AppCache.openAiApiKey.value!.isEmpty)
                      Tooltip(
                        message: 'API token is empty!',
                        child: Icon(ic.FluentIcons.warning_24_filled,
                            color: Colors.red, size: 24),
                      ),
                  ],
                ),
              );
            },
          ),
          const ConversationStyleRow(),
          Row(
            children: [
              HyperlinkButton(
                style: ButtonStyle(
                  padding: WidgetStateProperty.all(EdgeInsets.zero),
                ),
                onPressed: () => showCostCalculatorDialog(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Tokens: ${(chatProvider.totalTokensForCurrentChat)}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: chatProvider.refreshTokensForCurrentChat,
                      child: const Icon(FluentIcons.refresh, size: 12),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(ic.FluentIcons.search_20_filled, size: 20),
                onPressed: () async {
                  final provider = context.read<ChatProvider>();
                  final String? elementkey = await showDialog(
                    context: context,
                    builder: (context) => const SearchChatDialog(query: ''),
                  );
                  if (elementkey == null) return;
                  provider.scrollToMessage(elementkey);
                },
              ),
              const IncludeConversationSwitcher(),
            ],
          ),
        ],
      ),
    );
  }

  void showCostCalculatorDialog(BuildContext context) {
    final provider = context.read<ChatProvider>();
    final tokens = provider.totalTokensForCurrentChat;
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
    final ChatProvider chatProvider = context.watch<ChatProvider>();
    return FlyoutListTile(
      text: const Icon(FluentIcons.full_history),
      tooltip: 'Include conversation',
      trailing: Checkbox(
        checked: chatProvider.includeConversationGlobal,
        onChanged: (value) {
          chatProvider.setIncludeWholeConversation(value ?? false);
        },
      ),
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
  Widget build(BuildContext context) {
    var chatProvider = context.watch<ChatProvider>();
    chatProvider.context = context;

    return GestureDetector(
      onTap: promptTextFocusNode.requestFocus,
      behavior: HitTestBehavior.translucent,
      excludeFromSemantics: true,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Column(
            children: <Widget>[
              Expanded(
                child: StreamBuilder(
                    stream: messages,
                    builder: (context, snapshot) {
                      return ListView.builder(
                        controller: chatProvider.listItemsScrollController,
                        itemCount: messages.value.entries.length,
                        itemBuilder: (context, index) {
                          final element =
                              messages.value.entries.elementAt(index);
                          final message = element.value;

                          return AutoScrollTag(
                            controller: chatProvider.listItemsScrollController,
                            key: ValueKey('message_$index'),
                            index: index,
                            child: MessageCard(
                              id: element.key,
                              message: message,
                              dateTime: null,
                              selectionMode: false,
                              isError: false,
                              textSize: chatProvider.textSize,
                              isCompactMode: false,
                            ),
                          );
                        },
                      );
                    }),
              ),
              SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: Wrap(
                    alignment: WrapAlignment.start,
                    spacing: 4,
                    children: [
                      Tooltip(
                        message: chatProvider.isWebSearchEnabled
                            ? 'Disable web search'
                            : 'Enable web search',
                        child: ToggleButton(
                            checked: chatProvider.isWebSearchEnabled,
                            child: const Icon(
                              ic.FluentIcons.globe_search_20_filled,
                              size: 20,
                            ),
                            onChanged: (_) {
                              chatProvider.toggleWebSearch();
                            }),
                      ),
                      Tooltip(
                        message: 'Include conversation',
                        child: ToggleButton(
                            checked: chatProvider.includeConversationGlobal,
                            child: const Icon(
                              ic.FluentIcons.history_20_filled,
                              size: 20,
                            ),
                            onChanged: (value) {
                              chatProvider.setIncludeWholeConversation(value);
                            }),
                      ),
                      Tooltip(
                        message: 'Customize custom promtps',
                        child: ToggleButton(
                            checked: false,
                            child: const Icon(
                              ic.FluentIcons.settings_20_regular,
                              size: 20,
                            ),
                            onChanged: (_) {
                              showDialog(
                                context: context,
                                builder: (ctx) =>
                                    const CustomPromptsSettingsDialog(),
                              );
                            }),
                      ),
                    ],
                  ),
                ),
              ),
              const HotShurtcutsWidget(),
              const InputField()
            ],
          ),
          const Positioned(
            bottom: 128,
            right: 16,
            width: 32,
            height: 32,
            child: _ScrollToBottomButton(),
          ),
        ],
      ),
    );
  }
}

class _ScrollToBottomButton extends StatelessWidget {
  const _ScrollToBottomButton({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    return ToggleButton(
      checked: provider.scrollToBottomOnAnswer,
      style: ToggleButtonThemeData(
        checkedButtonStyle: ButtonStyle(
          padding: WidgetStateProperty.all(EdgeInsets.zero),
          backgroundColor: WidgetStateProperty.all(
              context.theme.accentColor.withOpacity(0.5)),
        ),
        uncheckedButtonStyle: ButtonStyle(
          padding: WidgetStateProperty.all(EdgeInsets.zero),
        ),
      ),
      onChanged: (value) {
        provider.toggleScrollToBottomOnAnswer();
        if (value) {
          provider.scrollToEnd();
        }
      },
      child: const Icon(FluentIcons.down, size: 16),
    );
  }
}

Future<void> displayCopiedToClipboard() {
  return displayInfoBar(
    appContext!,
    builder: (context, close) => InfoBar(
      title: const Text('Copied'),
      severity: InfoBarSeverity.info,
      style: InfoBarThemeData(icon: (_) => ic.FluentIcons.clipboard_24_filled),
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
                        displayCopiedToClipboard();
                      },
                      checked: false,
                      child: const Icon(FluentIcons.copy, size: 10),
                    ),
                  ),
                ],
              ),
              subtitle: buildMarkdown(
                context,
                '```python\n$block\n```',
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
  const RunCodeButton({
    super.key,
    required this.code,
    required this.language,
  });
  final String code;
  final String language;

  @override
  Widget build(BuildContext context) {
    final isSupported = language == 'shell' || language == 'python';
    if (!isSupported) {
      return const SizedBox.shrink();
    }
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: SizedBox.square(
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
                    Provider.of<ChatProvider>(context, listen: false);

                if (language == 'shell') {
                  final result = await ShellDriver.runShellCommand(code);
                  provider.addMessageSystem('result: $result');
                } else if (language == 'python') {
                  final result = await ShellDriver.runPythonCode(code);
                  provider.addMessageSystem('result: $result');
                }
              },
              checked: snap.data == true,
              style: ToggleButtonThemeData(
                uncheckedButtonStyle: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.green),
                  padding: WidgetStateProperty.all(EdgeInsets.zero),
                ),
              ),
              child: child,
            );
          },
        ),
      ),
    );
  }
}
