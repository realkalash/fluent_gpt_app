import 'dart:async';
import 'dart:math';

import 'package:entry/entry.dart';
import 'package:fluent_gpt/common/conversaton_style_enum.dart';
import 'package:fluent_gpt/common/custom_prompt.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/common/prompts_templates.dart';
import 'package:fluent_gpt/common/weather_data.dart';
import 'package:fluent_gpt/common/window_listener.dart';
import 'package:fluent_gpt/dialogs/chat_room_dialog.dart';
import 'package:fluent_gpt/dialogs/cost_dialog.dart';
import 'package:fluent_gpt/dialogs/edit_conv_length_dialog.dart';
import 'package:fluent_gpt/dialogs/search_chat_dialog.dart';
import 'package:fluent_gpt/features/screenshot_tool.dart';
import 'package:fluent_gpt/pages/prompts_settings_page.dart';
import 'package:fluent_gpt/pages/settings_page.dart';
import 'package:fluent_gpt/providers/weather_provider.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/custom_buttons.dart';
import 'package:fluent_gpt/widgets/custom_list_tile.dart';
import 'package:fluent_gpt/widgets/drop_region.dart';
import 'package:fluent_gpt/widgets/markdown_builders/code_wrapper.dart';
import 'package:fluent_gpt/widgets/markdown_builders/markdown_utils.dart';
import 'package:fluent_gpt/widgets/message_list_tile.dart';
import 'package:fluent_gpt/shell_driver.dart';
import 'package:fluent_gpt/system_messages.dart';
import 'package:fluent_gpt/widgets/input_field.dart';
import 'package:fluent_gpt/widgets/selectable_color_container.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as ic;
import 'package:scroll_to_index/scroll_to_index.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:widget_and_text_animator/widget_and_text_animator.dart';

import '../providers/chat_provider.dart';

final promptTextFocusNode = FocusNode();

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
                        HomeDropRegion(),
                      ],
                    ),
                  ),
                );
              });
        });
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
            color: Colors.black.withOpacity(0.2),
            child: Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.5),
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
        mainAxisSize: MainAxisSize.min,
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
                  children: [
                    Expanded(
                        child: TextAnimator(
                      selectedChatRoom.chatRoomName.trim(),
                      maxLines: 1,
                    )),
                    if (selectedModel.apiKey.isEmpty)
                      Tooltip(
                        message: 'API token is empty!',
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
              FlyoutButton(
                icon: ic.FluentIcons.text_font_size_24_regular,
                tooltip: 'Text size',
                shrinkWrapActions: true,
                contextItems: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Text size'),
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
                  ),
                ],
              ),
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
                ? FluentTheme.of(context).accentColor.withOpacity(0.1)
                : FluentTheme.of(context).cardColor,
          ),
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          alignment: Alignment.center,
          child: BasicListTile(
            color: Colors.transparent,
            title: const Center(
                child: Text('Add system message',
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
  List<CustomPrompt> getRandom3Prompts(BuildContext context) {
    final list = <CustomPrompt>[];
    final random = Random();
    for (var i = 0; i < 3; i++) {
      final index = random.nextInt(promptsLibrary.length);
      list.add(promptsLibrary[index]);
    }
    return list;
  }

  Color getColorBasedOnFirstLetter(String text) {
    final firstLetter = text[0].toLowerCase();
    final colors = {
      'a': Colors.blue.dark,
      'b': Colors.blue,
      'c': Colors.green,
      'd': Colors.orange,
      'e': Colors.purple,
      'f': Colors.teal.dark,
      'g': Colors.teal.darker,
      'h': Colors.yellow.dark,
      'i': Colors.yellow.darker,
      'j': Colors.yellow.light,
      'k': Colors.red.dark,
      'l': Colors.red.darker,
      'm': Colors.red.darkest,
      'n': Colors.blue.dark,
      'o': Colors.blue.darker,
      'p': Colors.blue.darkest,
      'q': Colors.yellow.darker,
      'r': Colors.grey,
      's': Colors.magenta,
      't': Colors.magenta.dark,
      'u': Colors.magenta.darker,
      'v': Colors.magenta.darkest,
      'w': Colors.orange.dark,
      'x': Colors.orange.darker,
      'y': Colors.orange.darkest,
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
    return StreamBuilder<Object>(
        stream: AppWindowListener.windowVisibilityStream,
        builder: (context, snapshot) {
          return Container(
            width: MediaQuery.of(context).size.width,
            height: 250,
            alignment: Alignment.center,
            child: ListView(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
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
                          padding: const EdgeInsets.all(8.0),
                          child: AnimatedHoverCard(
                            defHeight: 200,
                            defWidth: 160,
                            onTap: () {
                              context
                                  .read<ChatProvider>()
                                  .messageController
                                  .text = item.prompt;
                              promptTextFocusNode.requestFocus();
                            },
                            color: getColorBasedOnFirstLetter(item.title),
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                children: [
                                  Text(
                                    item.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Expanded(
                                      child: Text(item.prompt,
                                          overflow: TextOverflow.fade)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 32,
                          right: 16,
                          child: Button(
                            child: const Icon(ic.FluentIcons.send_24_filled),
                            onPressed: () {
                              context
                                  .read<ChatProvider>()
                                  .sendMessage(item.prompt);
                              promptTextFocusNode.requestFocus();
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              // children: prompts.map(
              //   (e) {
              //     return ;
              //   },
              // ).toList(),
            ),
          );
        });
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
                color: FluentTheme.of(context).shadowColor.withOpacity(0.2),
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

class WeatherCard extends StatelessWidget {
  const WeatherCard({super.key});

  @override
  Widget build(BuildContext context) {
    if (AppCache.userCityName.value?.isEmpty == true) {
      return const SizedBox.shrink();
    }
    final scrollController = ScrollController();
    return ChangeNotifierProvider(
      create: (BuildContext context) => WeatherProvider(context),
      builder: (ctx, _) {
        final provider = ctx.watch<WeatherProvider>();
        final isWeatherPresent = provider.filteredWeather.isNotEmpty;
        final weatherDays = provider.filteredWeather;
        return SizedBox(
          width: 200,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Card(
              borderRadius: BorderRadius.circular(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text('Weather in',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(' ${AppCache.userCityName.value}',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                      Spacer(),
                      GestureDetector(
                        onTap: () => launchUrlString('https://open-meteo.com/'),
                        child: Text(
                          'by Open-Meteo',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w100,
                            decoration: TextDecoration.underline,
                            color: Colors.blue.lighter,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (provider.isLoading) const Center(child: ProgressBar()),
                  SizedBox(
                    height: isWeatherPresent ? 130 : 0,
                    child: Scrollbar(
                      controller: scrollController,
                      child: ListView.builder(
                          controller: scrollController,
                          scrollDirection: Axis.horizontal,
                          itemCount: weatherDays.length,
                          itemBuilder: (ctx, i) {
                            final weather = weatherDays[i];
                            final weatherStatus = weather.weatherStatus;
                            final date = weather.date ?? DateTime(1970);

                            final formatter =
                                MediaQuery.of(context).alwaysUse24HourFormat
                                    ? DateFormat('yyyy-MM-dd\nHH:mm')
                                    : DateFormat('yyyy-MM-dd\nh:mm a');
                            final formattedDate = formatter.format(date);
                            return Card(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    formattedDate,
                                    textAlign: TextAlign.center,
                                  ),
                                  if (weatherStatus == WeatherCode.clearSky)
                                    Icon(
                                      ic.FluentIcons.weather_sunny_20_filled,
                                      color: Colors.yellow,
                                    ),
                                  if (weatherStatus == WeatherCode.partlyCloudy)
                                    Icon(
                                      ic.FluentIcons
                                          .weather_partly_cloudy_day_20_filled,
                                      color: Colors.blue,
                                    ),
                                  if (weatherStatus == WeatherCode.cloudy)
                                    Icon(
                                      ic.FluentIcons.weather_cloudy_20_filled,
                                      color: Colors.blue,
                                    ),
                                  if (weatherStatus == WeatherCode.foggy)
                                    Icon(
                                      ic.FluentIcons.weather_fog_20_filled,
                                      color: Colors.teal,
                                    ),
                                  if (weatherStatus == WeatherCode.partlyCloudy)
                                    Icon(
                                      ic.FluentIcons
                                          .weather_partly_cloudy_day_20_filled,
                                      color: Colors.yellow,
                                    ),
                                  if (weatherStatus == WeatherCode.rain)
                                    Icon(
                                      ic.FluentIcons.weather_rain_20_filled,
                                      color: Colors.blue,
                                    ),
                                  if (weatherStatus == WeatherCode.snow)
                                    Icon(
                                      ic.FluentIcons.weather_snow_20_filled,
                                      color: Colors.blue,
                                    ),
                                  Text('${weather.precipitation} mm'),
                                  Text(
                                      '${weather.temperature}${weather.units}'),
                                ],
                              ),
                            );
                          }),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      SqueareIconButton(
                        onTap: () {
                          provider.fetchWeather(AppCache.userCityName.value!);
                        },
                        icon: Icon(
                            ic.FluentIcons.arrow_counterclockwise_12_regular),
                        tooltip: 'Refresh',
                      ),
                      const SizedBox(width: 8),
                      Button(
                        onPressed: () =>
                            launchUrlString('https://weatherian.com/'),
                        child: const Text('More'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
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
              if (messages.value.entries.isEmpty)
                Expanded(
                  child: ListView(
                    children: [
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
                        return ListView.builder(
                          controller: chatProvider.listItemsScrollController,
                          itemCount: messages.value.entries.length,
                          itemBuilder: (context, index) {
                            final element =
                                messages.value.entries.elementAt(index);
                            final message = element.value;

                            return AutoScrollTag(
                              controller:
                                  chatProvider.listItemsScrollController,
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
                      // Because our screenshot tool is using fullscreen mode
                      // macos will hide everything, so we need to disable it
                      ToggleButtonAdvenced(
                        checked: false,
                        icon: ic.FluentIcons.eye_tracking_24_filled,
                        onChanged: (_) async {
                          String? base64Result;
                          base64Result = await ScreenshotTool
                              .takeScreenshotReturnBase64Native();

                          if (base64Result != null && base64Result.isNotEmpty)
                            chatProvider.addAttachemntAiLens(base64Result);
                        },
                        tooltip: 'Capture screenshot',
                      ),

                      ToggleButtonAdvenced(
                        checked: chatProvider.isWebSearchEnabled,
                        icon: ic.FluentIcons.globe_search_20_filled,
                        onChanged: (_) {
                          if (AppCache.braveSearchApiKey.value?.isNotEmpty ==
                              true) {
                            chatProvider.toggleWebSearch();
                          } else {
                            displayInfoBar(context, builder: (context, close) {
                              return InfoBar(
                                title: const Text(
                                    'You need to obtain Brave API key to use web search'),
                                severity: InfoBarSeverity.warning,
                                action: Button(
                                  onPressed: () {
                                    close();
                                    Navigator.of(context).push(
                                      FluentPageRoute(
                                          builder: (context) =>
                                              const SettingsPage()),
                                    );
                                  },
                                  child: const Text('Settings->API and URLs'),
                                ),
                              );
                            });
                          }
                        },
                        tooltip: chatProvider.isWebSearchEnabled
                            ? 'Disable web search'
                            : 'Enable web search',
                      ),
                      ToggleButtonAdvenced(
                        checked: chatProvider.includeConversationGlobal,
                        icon: ic.FluentIcons.history_20_filled,
                        onChanged: chatProvider.setIncludeWholeConversation,
                        tooltip: 'Include conversation',
                        maxWidthContextMenu: 300,
                        maxHeightContextMenu: 100,
                        contextItems: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Tooltip(
                                message:
                                    'To prevent token overflows unnecessary cost we propose to limit the conversation length',
                                child: Icon(
                                    ic.FluentIcons.question_circle_24_filled,
                                    size: 24),
                              ),
                              const SizedBox(width: 8),
                              const Expanded(
                                  child: Text('Max messages to include')),
                              Expanded(
                                child: Consumer<ChatProvider>(
                                  builder: (context, watch, child) {
                                    return NumberBox(
                                      value:
                                          watch.maxMessagesToIncludeInHistory,
                                      min: 1,
                                      clearButton: false,
                                      mode: SpinButtonPlacementMode.inline,
                                      onChanged: (v) {
                                        chatProvider
                                            .setMaxMessagesToIncludeInHistory(
                                                v);
                                      },
                                    );
                                  },
                                  child: NumberBox(
                                    value: chatProvider
                                        .maxMessagesToIncludeInHistory,
                                    min: 1,
                                    mode: SpinButtonPlacementMode.inline,
                                    onChanged: (v) {
                                      chatProvider
                                          .setMaxMessagesToIncludeInHistory(v);
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: Button(
                                  child: Text('Min'),
                                  onPressed: () {
                                    chatProvider
                                        .setMaxMessagesToIncludeInHistory(3);
                                  },
                                ),
                              ),
                              Expanded(
                                child: Button(
                                    child: Text('Medium'),
                                    onPressed: () {
                                      chatProvider
                                          .setMaxMessagesToIncludeInHistory(10);
                                    }),
                              ),
                              Expanded(
                                child: Button(
                                    child: Text('Max'),
                                    onPressed: () {
                                      chatProvider
                                          .setMaxMessagesToIncludeInHistory(30);
                                    }),
                              ),
                            ],
                          )
                        ],
                      ),
                      ToggleButtonAdvenced(
                        checked:
                            AppCache.learnAboutUserAfterCreateNewChat.value!,
                        icon: ic.FluentIcons.brain_circuit_20_regular,
                        onChanged: (v) {
                          setState(() {
                            AppCache.learnAboutUserAfterCreateNewChat.value = v;
                          });
                        },
                        tooltip:
                            'Summarize conversation and populate the knowlade about the user',
                      ),
                      ToggleButtonAdvenced(
                        checked: AppCache
                            .includeKnowledgeAboutUserToSysPrompt.value!,
                        icon: ic.FluentIcons.book_24_regular,
                        onChanged: (v) async {
                          setState(() {
                            AppCache
                                .includeKnowledgeAboutUserToSysPrompt.value = v;
                          });
                          final editedChatRoom = selectedChatRoom;
                          editedChatRoom.systemMessage =
                              await getFormattedSystemPrompt(basicPrompt: defaultGlobalSystemMessage);
                          chatRooms[selectedChatRoomId] = editedChatRoom;
                          chatProvider.notifyRoomsStream();
                        },
                        tooltip: 'Use memory about the user',
                      ),
                      ToggleButtonAdvenced(
                        icon: ic.FluentIcons.settings_20_regular,
                        onChanged: (_) => showDialog(
                          context: context,
                          builder: (ctx) => const CustomPromptsSettingsDialog(),
                        ),
                        tooltip: 'Customize custom promtps',
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
