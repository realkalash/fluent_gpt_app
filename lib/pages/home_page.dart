import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:animate_do/animate_do.dart';
import 'package:entry/entry.dart';
import 'package:fluent_gpt/common/chat_model.dart';
import 'package:fluent_gpt/common/conversaton_style_enum.dart';
import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/common/custom_prompt.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/common/prompts_templates.dart';
import 'package:fluent_gpt/common/window_listener.dart';
import 'package:fluent_gpt/dialogs/ai_prompts_library_dialog.dart';
import 'package:fluent_gpt/dialogs/cost_dialog.dart';
import 'package:fluent_gpt/dialogs/edit_chat_drawer.dart';
import 'package:fluent_gpt/dialogs/edit_conv_length_dialog.dart';
import 'package:fluent_gpt/dialogs/search_chat_dialog.dart';
import 'package:fluent_gpt/features/screenshot_tool.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/pages/new_settings_page.dart';
import 'package:fluent_gpt/pages/settings_page.dart';
import 'package:fluent_gpt/theme.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/custom_buttons.dart';
import 'package:fluent_gpt/widgets/custom_list_tile.dart';
import 'package:fluent_gpt/widgets/drop_region.dart';
import 'package:fluent_gpt/widgets/home_widgets/src.dart';
import 'package:fluent_gpt/widgets/markdown_builders/markdown_utils.dart';
import 'package:fluent_gpt/widgets/message_list_tile.dart';
import 'package:fluent_gpt/shell_driver.dart';
import 'package:fluent_gpt/system_messages.dart';
import 'package:fluent_gpt/widgets/input_field.dart';
import 'package:fluent_gpt/widgets/selectable_color_container.dart';
import 'package:fluent_gpt/widgets/wiget_constants.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as ic;
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:widget_and_text_animator/widget_and_text_animator.dart';

import '../providers/chat_provider.dart';

final BehaviorSubject<bool> showEditChatDrawer =
    BehaviorSubject<bool>.seeded(false);

class ChatRoomPage extends StatelessWidget {
  const ChatRoomPage({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: AppWindowListener.windowVisibilityStream,
        builder: (context, snapshot) {
          if (snapshot.data != true) {
            return const SizedBox.shrink();
          }
          return StreamBuilder(
              stream: selectedChatRoomIdStream,
              builder: (context, snapshot) {
                return Entry(
                  duration: const Duration(milliseconds: 500),
                  key: ValueKey('chat_room_page_$selectedChatRoomId'),
                  yOffset: 500,
                  curve: Curves.linearToEaseOut,
                  opacity: 0.2,
                  scale: 0.5,
                  child: const ScaffoldPage(
                    header: PageHeader(title: PageHeaderText()),
                    content: Stack(
                      fit: StackFit.expand,
                      children: [
                        ChatGPTContent(),
                        HomeDropOverlay(),
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          child: Center(child: EditChatDrawer()),
                        ),
                        HomeDropRegion(showAiLens: true),
                      ],
                    ),
                  ),
                );
              });
        });
  }
}

class EditChatDrawer extends StatelessWidget {
  const EditChatDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: 800),
      child: StreamBuilder<bool>(
          stream: showEditChatDrawer,
          builder: (context, _) {
            final showDrawer = showEditChatDrawer.value;
            if (showDrawer == false) return const SizedBox.shrink();
            return ExcludeSemantics(
              excluding: !showDrawer,
              child: IgnorePointer(
                ignoring: !showDrawer,
                child: FadeInDownBig(
                  animate: showDrawer,
                  curve: Curves.linearToEaseOut,
                  duration: const Duration(milliseconds: 600),
                  child: Container(
                    margin: const EdgeInsets.only(left: 32, right: 32),
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      color: FluentTheme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(50),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                        BoxShadow(
                          color: Colors.white.withAlpha(50),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: SingleChildScrollView(
                        child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: EditChatDrawerContainer(),
                    )),
                  ),
                ),
              ),
            );
          }),
    );
  }
}

enum DropOverlayState {
  none,
  dropOver,
  dropInvalidFormat,
}

// isDropOverlayVisible is a BehaviorSubject that is used to show the overlay when a drag is over the drop region.
final BehaviorSubject<DropOverlayState> isDropOverlayVisible =
    BehaviorSubject<DropOverlayState>.seeded(DropOverlayState.none);

class HomeDropOverlay extends StatelessWidget {
  const HomeDropOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DropOverlayState>(
      stream: isDropOverlayVisible,
      builder: (context, snapshot) {
        if (snapshot.data == DropOverlayState.dropOver) {
          return Container(
            color: Colors.black.withAlpha(51),
            child: Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: FluentTheme.of(context).accentColor.withAlpha(127),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: const Center(
                  child: Icon(
                    ic.FluentIcons.attach_24_filled,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
        }
        if (snapshot.data == DropOverlayState.dropInvalidFormat) {
          return Container(
            color: Colors.black.withAlpha(51),
            child: Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(128),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: const Center(
                  child: Icon(
                    ic.FluentIcons.warning_24_filled,
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

class ConversationStyleRow extends StatefulWidget {
  const ConversationStyleRow({super.key});

  @override
  State<ConversationStyleRow> createState() => _ConversationStyleRowState();
}

class _ConversationStyleRowState extends State<ConversationStyleRow> {
  final scrollContr = ScrollController();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: conversationLenghtStyleStream,
      builder: (_, __) => StreamBuilder<Object>(
          stream: conversationStyleStream,
          builder: (context, snapshot) {
            final lenghtStyle = conversationLenghtStyleStream.value;
            final style = conversationStyleStream.value;
            return Stack(
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: scrollContr,
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Row(
                    spacing: 8,
                    // runSpacing: 8,
                    // crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Conversation length'.tr,
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      ...ConversationLengthStyleEnum.values.map((e) {
                        return SelectableColorContainer(
                          selectedColor: FluentTheme.of(context).accentColor,
                          unselectedColor: FluentTheme.of(context)
                              .accentColor
                              .withAlpha(128),
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
                      }),
                      Text(
                        'Style'.tr,
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      ...ConversationStyleEnum.values
                          .map((e) => SelectableColorContainer(
                                selectedColor:
                                    FluentTheme.of(context).accentColor,
                                unselectedColor: FluentTheme.of(context)
                                    .accentColor
                                    .withAlpha(128),
                                isSelected: style == e,
                                onTap: () => conversationStyleStream.add(e),
                                child: Text(e.name,
                                    style: const TextStyle(fontSize: 12)),
                              )),
                    ],
                  ),
                ),
                Positioned(
                  left: 0,
                  top: 4,
                  child: GestureDetector(
                    onTap: () {
                      scrollContr.animateTo(
                        scrollContr.position.minScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ColoredBox(
                        color: Colors.black.withAlpha(191),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(ic.FluentIcons.arrow_left_24_filled,
                              size: 24),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  top: 4,
                  child: GestureDetector(
                    onTap: () {
                      scrollContr.animateTo(
                        scrollContr.position.maxScrollExtent,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: ColoredBox(
                        color: Colors.black.withAlpha(191),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Icon(ic.FluentIcons.arrow_right_24_filled,
                              size: 24),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
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
    var chatProvider = context.read<ChatProvider>();
    return Focus(
      canRequestFocus: false,
      descendantsAreTraversable: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          StreamBuilder(
            stream: selectedChatRoomIdStream,
            builder: (_, __) {
              return GestureDetector(
                onTap: () {
                  showEditChatDrawer.add(!showEditChatDrawer.value);
                  // EditChatRoomDialog.show(
                  //   context: context,
                  //   room: selectedChatRoom,
                  //   onOkPressed: () {},
                  // );
                },
                child: Row(
                  children: [
                    Expanded(
                        child: TextAnimator(
                      selectedChatRoom.chatRoomName.trim(),
                      maxLines: 1,
                    )),
                    if (selectedModel.apiKey.isEmpty)
                      Tooltip(
                        message: 'API token is empty!'.tr,
                        child: Icon(ic.FluentIcons.lock_open_20_regular,
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
              Tooltip(
                message:
                    'When you send a message, the app will use the system message along with your prompt. This value may differ from your own calculations because some additional information can be sent with each of your prompts.\nTotal is the total tokens that exists in current chat\nSent is the total tokens that you have sent\nReceived is the total tokens that you have received'
                        .tr,
                style: TooltipThemeData(maxWidth: 400),
                child: HyperlinkButton(
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(EdgeInsets.zero),
                  ),
                  onPressed: () => showCostCalculatorDialog(context),
                  child: Row(
                    children: [
                      StreamBuilder<int>(
                          stream:
                              // ignore: deprecated_member_use_from_same_package
                              chatProvider.totalTokensForCurrentChatByMessages,
                          builder: (context, snapshot) {
                            return Text(
                              '${'Tokens total:'.tr} ${(chatProvider.totalTokensByMessages)} '
                                  .tr,
                              style: const TextStyle(fontSize: 12),
                            );
                          }),
                      StreamBuilder<int>(
                          // ignore: deprecated_member_use_from_same_package
                          stream: chatProvider.totalSentForCurrentChat,
                          builder: (context, snapshot) {
                            return Text(
                              '${'sent:'.tr} ${(chatProvider.totalSentTokens)} '
                                  .tr,
                              style: const TextStyle(fontSize: 12),
                            );
                          }),
                      StreamBuilder<int>(
                          stream: chatProvider.totalReceivedForCurrentChat,
                          builder: (context, snapshot) {
                            return Text(
                              '${'received:'.tr} ${(chatProvider.totalReceivedTokens)}'
                                  .tr,
                              style: const TextStyle(fontSize: 12),
                            );
                          }),
                    ],
                  ),
                ),
              ),
              GestureDetector(
                  onTap: () =>
                      chatProvider.recalculateTokensFromLocalMessages(),
                  child: const Icon(
                      ic.FluentIcons.arrow_counterclockwise_20_filled)),
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
              IconButton(
                icon: const Icon(ic.FluentIcons.image_20_regular, size: 20),
                onPressed: () {
                  ImagesDialog.show(context);
                },
              ),
              FlyoutButton(
                icon: ic.FluentIcons.text_font_size_24_regular,
                tooltip: 'Text size'.tr,
                shrinkWrapActions: true,
                contextItems: [
                  Consumer<ChatProvider>(builder: (context, value, child) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Text size'.tr),
                        NumberBox(
                          value: chatProvider.textSize,
                          min: 8,
                          clearButton: false,
                          autofocus: true,
                          mode: SpinButtonPlacementMode.inline,
                          onChanged: (v) {
                            chatProvider.textSize = v ?? 14;
                          },
                        ),
                      ],
                    );
                  }),
                ],
              ),
              SizedBox(
                width: 24,
                height: 36,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Expanded(
                      child: HoverButton(
                        onPressed: () {
                          chatProvider.textSize = chatProvider.textSize + 2;
                        },
                        builder: (p0, state) {
                          return Container(
                              color: state.contains(WidgetState.hovered)
                                  ? Colors.white.withAlpha(51)
                                  : Colors.transparent,
                              padding: const EdgeInsets.all(4),
                              child: Icon(ic.FluentIcons.arrow_up_16_filled,
                                  size: 10));
                        },
                      ),
                    ),
                    // const SizedBox(height: 2),
                    Expanded(
                      child: HoverButton(
                        onPressed: () {
                          chatProvider.textSize = chatProvider.textSize - 2;
                        },
                        builder: (p0, state) {
                          return Container(
                            color: state.contains(WidgetState.hovered)
                                ? Colors.white.withAlpha(51)
                                : Colors.transparent,
                            padding: const EdgeInsets.all(4),
                            child: Icon(
                              ic.FluentIcons.arrow_down_16_filled,
                              size: 10,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void showCostCalculatorDialog(BuildContext context) {
    final provider = context.read<ChatProvider>();

    showDialog(
      context: context,
      builder: (context) => CostCalcDialog(
        sentTokens: provider.totalSentTokens,
        receivedTokens: provider.totalReceivedTokens,
      ),
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
      tooltip:
          '${'Include conversation'.tr} ${Platform.isWindows ? '(Ctrl+H)' : '(⌘+H)'}',
      trailing: Checkbox(
        checked: chatProvider.includeConversationGlobal,
        onChanged: (value) {
          chatProvider.setIncludeWholeConversation(value ?? false);
        },
      ),
    );
  }
}

class AddSystemMessageField extends StatefulWidget {
  const AddSystemMessageField({super.key});

  @override
  State<AddSystemMessageField> createState() => _AddSystemMessageFieldState();
}

class _AddSystemMessageFieldState extends State<AddSystemMessageField> {
  bool isExpanded = false;
  bool isHovered = false;
  final controller = TextEditingController();
  String systemMessage = '';
  StreamSubscription? subscription;
  @override
  void initState() {
    controller.text = selectedChatRoom.systemMessage ?? '';
    systemMessage = selectedChatRoom.systemMessage ?? '';
    super.initState();
    subscription = chatRoomsStream.listen((onData) {
      if (selectedChatRoom.systemMessage != systemMessage) {
        controller.text = selectedChatRoom.systemMessage ?? '';
        systemMessage = selectedChatRoom.systemMessage ?? '';
        if (mounted) setState(() {});
      }
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  void submit() {
    setState(() {
      isExpanded = false;
      systemMessage = controller.text;
    });
    context.read<ChatProvider>()
      ..editChatRoom(
        selectedChatRoomId,
        selectedChatRoom.copyWith(systemMessage: systemMessage),
      )
      ..updateUI();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      height: isExpanded ? 300 : 100,
      margin: isExpanded ? const EdgeInsets.all(8) : const EdgeInsets.all(16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: FluentTheme.of(context).cardColor,
      ),
      child: getWidget(),
    );
  }

  Widget getWidget() {
    if (isExpanded) {
      return TextBox(
        controller: controller,
        autofocus: true,
        minLines: 1,
        maxLines: 20,
        textAlignVertical: TextAlignVertical.center,
        prefix: IconButton(
          icon: const Icon(ic.FluentIcons.dismiss_square_20_regular, size: 24),
          onPressed: () {
            setState(() {
              isExpanded = false;
            });
          },
        ),
        suffix: Column(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 16),
              child: ImproveTextSparkleButton(
                input: () => controller.text,
                onTextImproved: (improvedText) {
                  controller.text = improvedText;
                  systemMessage = improvedText;
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: IconButton(
                icon: const Icon(ic.FluentIcons.checkmark_16_filled, size: 24),
                onPressed: () => submit(),
              ),
            ),
          ],
        ),
        onSubmitted: (value) => submit(),
      );
    }
    return GestureDetector(
      onTap: () {
        setState(() => isExpanded = true);
      },
      child: MouseRegion(
        onHover: (_) => setState(() => isHovered = true),
        onExit: (_) => setState(() => isHovered = false),
        cursor: SystemMouseCursors.click,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: isHovered
                ? FluentTheme.of(context).accentColor.withAlpha(26)
                : FluentTheme.of(context).cardColor,
          ),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          alignment: Alignment.center,
          child: BasicListTile(
            color: Colors.transparent,
            title: Center(
                child: Text('Add system message'.tr,
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w500))),
            trailing: const PromptLibraryButton(),
            subtitle: systemMessage.isEmpty
                ? null
                : Expanded(
                    child: Center(
                      child: Text(systemMessage, overflow: TextOverflow.fade),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class HomePagePlaceholdersCards extends StatefulWidget {
  const HomePagePlaceholdersCards({super.key});

  @override
  State<HomePagePlaceholdersCards> createState() =>
      _HomePagePlaceholdersCardsState();
}

class _HomePagePlaceholdersCardsState extends State<HomePagePlaceholdersCards> {
  static const maxItems = 6;
  List<CustomPrompt> getRandom3Prompts(BuildContext context) {
    final list = <CustomPrompt>[];
    for (var i = 0; i < maxItems; i++) {
      final randomPrompt = getRandomPrompt(context);
      list.add(randomPrompt);
    }
    return list;
  }

  CustomPrompt getRandomPrompt(BuildContext context) {
    final random = Random();
    final index = random.nextInt(promptsLibrary.length);
    final prompt = promptsLibrary[index];
    if (prompt.showInHomePage == false) return getRandomPrompt(context);
    return prompt;
  }

  Color getColorBasedOnFirstLetter(String text) {
    final firstLetter = text[0].toLowerCase();
    final colors = {
      'a': Colors.red.dark,
      'b': Colors.green,
      'c': Colors.blue,
      'd': Colors.yellow.dark,
      'e': Colors.orange,
      'f': Colors.purple,
      'g': Colors.teal.darker,
      'h': Colors.magenta,
      'i': Colors.yellow.darker,
      'j': Colors.blue.dark,
      'k': Colors.red.darker,
      'l': Colors.teal.dark,
      'm': Colors.orange.dark,
      'n': Colors.green.dark,
      'o': Colors.blue.darker,
      'p': Colors.yellow.darkest,
      'q': Colors.magenta.dark,
      'r': Colors.grey,
      's': Colors.yellow.darkest,
      't': Colors.magenta.darker,
      'u': Colors.blue.darkest,
      'v': Colors.magenta.darkest,
      'w': Colors.orange.darker,
      'x': Colors.red.darkest,
      'y': Colors.teal.darker,
      'z': Colors.green.dark,
    };
    return colors[firstLetter] ?? Colors.grey;
  }

  List<CustomPrompt> prompts = [];

  @override
  void initState() {
    prompts = getRandom3Prompts(context);
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<AppTheme>();
    if (provider.hideSuggestionsOnHomePage) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: const Icon(
                      ic.FluentIcons.arrow_counterclockwise_20_filled),
                  onPressed: () {
                    setState(() {
                      prompts = getRandom3Prompts(context);
                    });
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: IconButton(
                  icon: const Icon(FluentIcons.chrome_close, size: 10),
                  onPressed: () {
                    setState(() {
                      provider.hideSuggestionsOnHomePage =
                          !provider.hideSuggestionsOnHomePage;
                    });
                  },
                ),
              ),
            ],
          ),
          StreamBuilder<Object>(
              stream: AppWindowListener.windowVisibilityStream,
              builder: (context, snapshot) {
                return Wrap(
                  alignment: WrapAlignment.center,
                  children: List.generate(
                    prompts.length,
                    (index) {
                      final item = prompts[index];
                      return Entry(
                        curve: Curves.easeInOutBack,
                        scale: 0.1,
                        duration: const Duration(milliseconds: 800),
                        delay: Duration(milliseconds: (index * 300)),
                        key: ValueKey('home_place_holder_$index'),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                  left: 8.0, right: 8, top: 8, bottom: 8),
                              child: AnimatedHoverCard(
                                defHeight: 60,
                                defWidth: 150,
                                onTap: () async {
                                  final promptText = item.getPromptText(
                                      (await Clipboard.getData(
                                              Clipboard.kTextPlain))
                                          ?.text);
                                  final isContainsPlaceHolder =
                                      placeholdersRegex.hasMatch(promptText);
                                  String? newText = promptText;
                                  if (isContainsPlaceHolder) {
                                    newText = await showDialog<String>(
                                      // ignore: use_build_context_synchronously
                                      context: context,
                                      builder: (context) =>
                                          ReplaceAllPlaceHoldersDialog(
                                        originalText: promptText,
                                      ),
                                    );
                                    if (newText == null) return;
                                  }
                                  ChatProvider.messageControllerGlobal.text =
                                      newText;

                                  promptTextFocusNode.requestFocus();
                                },
                                color: getColorBasedOnFirstLetter(item.title),
                                child: Padding(
                                  padding: const EdgeInsets.only(
                                      left: 6, right: 0, top: 4, bottom: 0),
                                  child: Text(
                                    item.title.tr,
                                    maxLines: 2,
                                    overflow: TextOverflow.clip,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 8,
                              right: 16,
                              child: Button(
                                child:
                                    const Icon(ic.FluentIcons.send_24_filled),
                                onPressed: () async {
                                  final chatProvider =
                                      context.read<ChatProvider>();
                                  final promptText = item.getPromptText(
                                      (await Clipboard.getData(
                                              Clipboard.kTextPlain))
                                          ?.text);

                                  final isContainsPlaceHolder =
                                      placeholdersRegex.hasMatch(promptText);
                                  String? newText = promptText;
                                  if (isContainsPlaceHolder) {
                                    newText = await showDialog<String>(
                                      // ignore: use_build_context_synchronously
                                      context: context,
                                      builder: (context) =>
                                          ReplaceAllPlaceHoldersDialog(
                                        originalText: promptText,
                                      ),
                                    );
                                    if (newText == null) return;
                                  }
                                  chatProvider.editChatRoom(
                                    selectedChatRoomId,
                                    selectedChatRoom.copyWith(
                                      systemMessage: newText,
                                    ),
                                    switchToForeground: true,
                                  );
                                  // wait for the chat room to be updated
                                  await Future.delayed(
                                      const Duration(milliseconds: 50));
                                  chatProvider.sendMessage(newText);
                                  promptTextFocusNode.requestFocus();
                                },
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );
              }),
        ],
      ),
    );
  }
}

class AnimatedHoverCard extends StatefulWidget {
  const AnimatedHoverCard({
    super.key,
    this.onTap,
    required this.child,
    required this.defWidth,
    required this.defHeight,
    this.color,
    this.onLongPress,
  });
  final void Function()? onTap;
  final void Function()? onLongPress;
  final Widget child;
  final double defWidth;
  final double defHeight;
  final Color? color;

  @override
  State<AnimatedHoverCard> createState() => _AnimatedHoverCardState();
}

class _AnimatedHoverCardState extends State<AnimatedHoverCard> {
  bool isHovered = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() {
          isHovered = true;
        }),
        onExit: (_) => setState(() {
          isHovered = false;
        }),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: isHovered ? widget.defWidth * 1.15 : widget.defWidth,
          height: isHovered ? widget.defHeight * 1.15 : widget.defHeight,
          curve: Curves.easeInOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: widget.color ?? FluentTheme.of(context).cardColor,
            boxShadow: [
              BoxShadow(
                color: FluentTheme.of(context).shadowColor.withAlpha(51),
                blurRadius: isHovered ? 16 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: widget.child,
        ),
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
    final chatProvider = context.watch<ChatProvider>();
    chatProvider.context = context;

    return GestureDetector(
      onTap: promptTextFocusNode.requestFocus,
      behavior: HitTestBehavior.translucent,
      excludeFromSemantics: true,
      child: Column(
        children: <Widget>[
          if (messages.value.entries.isEmpty)
            Expanded(
              child: ListView(
                children: const [
                  AddSystemMessageField(),
                  HomePagePlaceholdersCards(),
                  WeatherCard(),
                ],
              ),
            )
          else
            Expanded(
              child: StreamBuilder(
                stream: messages,
                builder: (context, snapshot) {
                  final reverseList = messagesReversedList;
                  return ListView.builder(
                    controller: chatProvider.listItemsScrollController,
                    itemCount: messages.value.entries.length,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    reverse: true,
                    itemBuilder: (context, index) {
                      final FluentChatMessage message =
                          reverseList.elementAt(index);

                      return AutoScrollTag(
                        controller: chatProvider.listItemsScrollController,
                        key: ValueKey('message_$index'),
                        index: index,
                        child: MessageCard(
                          message: message,
                          selectionMode: false,
                          textSize: chatProvider.textSize,
                          isCompactMode: false,
                          shouldBlink:
                              chatProvider.blinkMessageId == message.id,
                          indexMessage: index,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          SizedBox(
            width: double.infinity,
            child: AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              firstChild: const SizedBox.shrink(),
              secondChild: const SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: EdgeInsets.all(4.0),
                  child: ProgressBar(strokeWidth: 8),
                ),
              ),
              crossFadeState: !chatProvider.isAnswering
                  ? CrossFadeState.showFirst
                  : CrossFadeState.showSecond,
            ),
          ),
          const GeneratingImagesCard(),
          const QuickHelperButtonsFromLLMRow(),
          const ToggleButtonsRow(),
          const HotShurtcutsWidget(),
          const InputField()
        ],
      ),
    );
  }
}

class ToggleButtonsRow extends StatefulWidget {
  const ToggleButtonsRow({super.key});

  @override
  State<ToggleButtonsRow> createState() => _ToggleButtonsRowState();
}

class _ToggleButtonsRowState extends State<ToggleButtonsRow> {
  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: Row(
          // alignment: WrapAlignment.start,
          spacing: 4,
          children: [
            if (selectedModel.imageSupported)
              ToggleButtonAdvenced(
                checked: false,
                icon: ic.FluentIcons.eye_tracking_24_filled,
                onChanged: (_) async {
                  String? base64Result;
                  base64Result =
                      await ScreenshotTool.takeScreenshotReturnBase64Native();

                  if (base64Result != null && base64Result.isNotEmpty) {
                    final bytes = base64Decode(base64Result);
                    chatProvider.addAttachmentAiLens(bytes);
                  }
                },
                tooltip: 'Capture screenshot'.tr,
              ),
            ToggleButtonAdvenced(
              checked: chatProvider.isWebSearchEnabled,
              icon: selectedModel.ownedBy == OwnedByEnum.openai.name
                  ? ic.FluentIcons.search_sparkle_20_filled
                  : ic.FluentIcons.globe_search_20_filled,
              onChanged: (_) {
                if (AppCache.braveSearchApiKey.value?.isNotEmpty == true) {
                  chatProvider.toggleWebSearch();
                } else {
                  displayInfoBar(context, builder: (context, close) {
                    return InfoBar(
                      title: Text(
                          'You need to obtain Brave API key to use web search'
                              .tr),
                      severity: InfoBarSeverity.warning,
                      action: Button(
                        onPressed: () {
                          close();
                          Navigator.of(context).push(
                            FluentPageRoute(
                                builder: (context) => const NewSettingsPage()),
                          );
                        },
                        child: Text('Settings->API and URLs'.tr),
                      ),
                    );
                  });
                }
              },
              tooltip: chatProvider.isWebSearchEnabled
                  ? 'Disable web search'.tr
                  : 'Enable web search'.tr,
            ),
            ToggleButtonAdvenced(
              checked: chatProvider.includeConversationGlobal,
              icon: ic.FluentIcons.history_20_filled,
              onChanged: chatProvider.setIncludeWholeConversation,
              tooltip: 'Include conversation'.tr +
                  ' ${Platform.isWindows ? '(Ctrl+H)' : '(⌘+H)'}'.tr,
              maxWidthContextMenu: 350,
              maxHeightContextMenu: 96,
              contextItems: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Tooltip(
                      message:
                          'To prevent token overflows unnecessary cost we propose to limit the conversation length'
                              .tr,
                      child: Icon(ic.FluentIcons.question_circle_24_filled,
                          size: 24),
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Max tokens to include'.tr)),
                    Expanded(
                      child: Consumer<ChatProvider>(
                        builder: (context, watch, child) {
                          return NumberBox(
                            value: selectedChatRoom.maxTokenLength,
                            min: 1,
                            smallChange: 64,
                            clearButton: false,
                            mode: SpinButtonPlacementMode.inline,
                            onChanged: (v) {
                              chatProvider.setMaxTokensForChat(v);
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
                spacer,
                StatefulBuilder(builder: (context, updateSlider) {
                  return Slider(
                    value: selectedChatRoom.maxTokenLength < 0.0
                        ? 0.0
                        : selectedChatRoom.maxTokenLength.toDouble(),
                    onChanged: (value) {
                      updateSlider(() {
                        chatProvider.setMaxTokensForChat(value.toInt());
                      });
                    },
                    min: 0.0,
                    max: 16384,
                    divisions: 16,
                  );
                }),
              ],
            ),
            ToggleButtonAdvenced(
              checked: AppCache.gptToolRememberInfo.value!,
              icon: ic.FluentIcons.brain_circuit_20_regular,
              onChanged: (v) {
                setState(() {
                  AppCache.gptToolRememberInfo.value = v;
                });
                if (v) {
                  displayTextInfoBar(
                    'AI will be able to remember things about you'.tr,
                    alignment: Alignment.topCenter,
                  );
                }
              },
              tooltip: 'AI will be able to remember things about you'.tr,
            ),
            ToggleButtonAdvenced(
              checked: AppCache.includeKnowledgeAboutUserToSysPrompt.value!,
              shrinkWrapActions: true,
              maxWidthContextMenu: 300,
              contextItems: [
                Text('Select items to include in system prompt'.tr),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Divider(),
                ),
                CheckBoxTile(
                  isChecked:
                      AppCache.includeKnowledgeAboutUserToSysPrompt.value!,
                  child: Text('Knowledge about user'.tr),
                  onChanged: (p0) {
                    setState(() {
                      AppCache.includeKnowledgeAboutUserToSysPrompt.value = p0;
                    });
                  },
                ),
                CheckBoxTile(
                  isChecked: AppCache.includeUserCityNamePrompt.value!,
                  child: Text('City name'.tr),
                  onChanged: (p0) {
                    setState(() {
                      AppCache.includeUserCityNamePrompt.value = p0;
                    });
                  },
                ),
                CheckBoxTile(
                  isChecked: AppCache.includeWeatherPrompt.value!,
                  child: Text('Weather'.tr),
                  onChanged: (p0) {
                    setState(() {
                      AppCache.includeWeatherPrompt.value = p0;
                    });
                  },
                ),
                CheckBoxTile(
                  isChecked: AppCache.includeUserNameToSysPrompt.value!,
                  child: Text('User name'.tr),
                  onChanged: (p0) {
                    setState(() {
                      AppCache.includeUserNameToSysPrompt.value = p0;
                    });
                  },
                ),
                CheckBoxTile(
                  isChecked: AppCache.includeTimeToSystemPrompt.value!,
                  child: Text('Current timestamp'.tr),
                  onChanged: (p0) {
                    setState(() {
                      AppCache.includeUserNameToSysPrompt.value = p0;
                    });
                  },
                ),
                CheckBoxTile(
                  isChecked: AppCache.includeSysInfoToSysPrompt.value!,
                  child: Text('OS info'.tr),
                  onChanged: (p0) {
                    setState(() {
                      AppCache.includeSysInfoToSysPrompt.value = p0;
                    });
                  },
                ),
              ],
              icon: ic.FluentIcons.person_info_20_regular,
              onChanged: (v) async {
                setState(() {
                  AppCache.includeKnowledgeAboutUserToSysPrompt.value = v;
                });
                final editedChatRoom = selectedChatRoom;
                editedChatRoom.systemMessage = await getFormattedSystemPrompt(
                  basicPrompt: (editedChatRoom.systemMessage ?? '').isEmpty
                      ? defaultGlobalSystemMessage
                      : editedChatRoom.systemMessage!
                          .split(contextualInfoDelimeter)
                          .first,
                );
                chatRooms[selectedChatRoomId] = editedChatRoom;
                chatProvider.notifyRoomsStream();
              },
              tooltip: 'Use memory about the user'.tr,
            ),
            if (kDebugMode)
              ToggleButtonAdvenced(
                checked: AppCache.useRAG.value!,
                icon: ic.FluentIcons.book_24_regular,
                onChanged: (v) {
                  setState(() {
                    AppCache.useRAG.value = v;
                  });
                },
                tooltip: 'Use RAG'.tr,
              ),
            ToggleButtonAdvenced(
              checked: AppCache.autoPlayMessagesFromAi.value!,
              icon: ic.FluentIcons.play_circle_16_filled,
              onChanged: (v) {
                setState(() {
                  AppCache.autoPlayMessagesFromAi.value = v;
                });
              },
              tooltip: 'Auto play messages from ai'.tr,
            ),
            Spacer(),
            _ScrollToBottomButton(),
          ],
        ),
      ),
    );
  }
}

class QuickHelperButtonsFromLLMRow extends StatelessWidget {
  const QuickHelperButtonsFromLLMRow({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Wrap(
          spacing: 4,
          runSpacing: 2,
          children: [
            if (provider.isGeneratingQuestionHelpers)
              Shimmer(
                color: context.theme.accentColor,
                duration: const Duration(milliseconds: 500),
                child: SizedBox(
                  width: MediaQuery.sizeOf(context).width,
                  height: 32,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Container(
                        width: 100,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color.fromARGB(255, 197, 197, 197),
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        margin: const EdgeInsets.only(right: 8),
                      ),
                      Container(
                        width: 100,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color.fromARGB(255, 197, 197, 197),
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        margin: const EdgeInsets.only(right: 8),
                      ),
                      Container(
                        width: 100,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color.fromARGB(255, 197, 197, 197),
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        margin: const EdgeInsets.only(right: 8),
                      ),
                      Container(
                        width: 100,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color.fromARGB(255, 197, 197, 197),
                          borderRadius: BorderRadius.all(Radius.circular(8)),
                        ),
                        margin: const EdgeInsets.only(right: 8),
                      ),
                    ],
                  ),
                ),
                // child: Container(
                //   height: 32,
                //   width: MediaQuery.sizeOf(context).width,
                //   color: Colors.blue,
                // ),
              ),
            if (AppCache.enableQuestionHelpers.value == null)
              Tooltip(
                style: TooltipThemeData(
                    waitDuration: const Duration(milliseconds: 200)),
                richMessage: WidgetSpan(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          'Will ask AI to produce buttons for each response. It will consume additional tokens in order to generate suggestions'
                              .tr),
                      spacer,
                      Image.asset('assets/im_suggestions_tip.png'),
                    ],
                  ),
                ),
                child: SizedBox(
                  width: MediaQuery.sizeOf(context).width,
                  child: InfoBar(
                    title: Row(
                      children: [
                        Expanded(
                            child: Text(
                                'Do you want to enable suggestion helpers?'
                                    .tr)),
                        FilledButton(
                          onPressed: () {
                            AppCache.enableQuestionHelpers.value = true;
                            provider.updateUI();
                          },
                          child: Text('Enable'.tr),
                        ),
                        Button(
                          onPressed: () {
                            AppCache.enableQuestionHelpers.value = false;
                            provider.updateUI();
                          },
                          child: Text('No. Don\'t show again'.tr),
                        )
                      ],
                    ),
                  ),
                ),
              ),
            for (final item in provider.questionHelpers)
              Entry.all(
                curve: Curves.decelerate,
                xOffset: 100,
                child: Button(
                  style: ButtonStyle(
                    padding: WidgetStateProperty.all(
                      EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    ),
                  ),
                  onPressed: () async {
                    final clipboard =
                        await Clipboard.getData(Clipboard.kTextPlain);
                    provider.sendMessage(item.getPromptText(clipboard?.text));
                  },
                  child: Text(item.title.tr,
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GeneratingImagesCard extends StatelessWidget {
  const GeneratingImagesCard({super.key});
  static final botMessageStyle = TextStyle(color: Colors.green, fontSize: 14);

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    if (chatProvider.isGeneratingImage == false) return const SizedBox.shrink();
    return Card(
      margin: const EdgeInsets.all(4),
      borderRadius: BorderRadius.circular(8.0),
      borderColor: Colors.transparent,
      child: MessageListTile(
        title: Text('AI', style: botMessageStyle),
        subtitle: Shimmer(
          color: context.theme.accentColor,
          duration: const Duration(milliseconds: 1000),
          child: Container(
            width: 200,
            height: 200,
            color: context.theme.cardColor,
          ),
        ),
      ),
    );
  }
}

class _ScrollToBottomButton extends StatefulWidget {
  const _ScrollToBottomButton();

  @override
  State<_ScrollToBottomButton> createState() => _ScrollToBottomButtonState();
}

class _ScrollToBottomButtonState extends State<_ScrollToBottomButton> {
  @override
  Widget build(BuildContext context) {
    final provider = context.read<ChatProvider>();
    return Tooltip(
      message: 'Scroll to bottom on new message'.tr,
      child: ToggleButton(
        checked: provider.scrollToBottomOnAnswer,
        style: ToggleButtonThemeData(
          checkedButtonStyle: ButtonStyle(
            backgroundColor: WidgetStateProperty.all(
                context.theme.accentColor.withAlpha(128)),
          ),
          uncheckedButtonStyle: ButtonStyle(
              // padding: WidgetStateProperty.all(EdgeInsets.zero),
              ),
        ),
        onChanged: (value) {
          // if not at the bottom we should just scroll to the bottom
          // The list is reversed so the bottom is the top
          if (provider.listItemsScrollController.position.pixels !=
              provider.listItemsScrollController.position.minScrollExtent) {
            provider.scrollToEnd();
            return;
          }
          provider.toggleScrollToBottomOnAnswer();
          if (value) {
            provider.scrollToEnd();
          }
          setState(() {});
        },
        child: const Icon(FluentIcons.down, size: 16),
      ),
    );
  }
}

void chooseCodeBlockDialog(BuildContext context, List<String> blocks) {
  showDialog(
    context: context,
    builder: (ctx) => ContentDialog(
      title: Text('Choose code block'.tr),
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
          child: Text('Dismiss'.tr.tr),
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
    runShellRegex,
    pythonCommandRegex,
    // everythingSearchCommandRegex,
    copyToCliboardRegex,
    openUrlRegex,
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
    final isSupported =
        language == 'shell' || language == 'python' || language == 'run-shell';
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
