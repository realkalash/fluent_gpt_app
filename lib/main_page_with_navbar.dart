import 'package:fluent_gpt/common/chat_room.dart';
import 'package:fluent_gpt/dialogs/chat_room_dialog.dart';
import 'package:fluent_gpt/dialogs/deleted_chats_dialog.dart';
import 'package:fluent_gpt/dialogs/search_all_messages_dialog.dart';
import 'package:fluent_gpt/dialogs/storage_usage.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/navigation_provider.dart';
import 'package:fluent_gpt/pages/home_page.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/link.dart';
import 'package:window_manager/window_manager.dart';

import 'pages/about_page.dart';
import 'pages/log_page.dart';
import 'pages/settings_page.dart';
import 'widgets/main_app_header_buttons.dart';

class MainPageWithNavigation extends StatelessWidget {
  const MainPageWithNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    final navigationProvider = context.read<NavigationProvider>();
    final theme = FluentTheme.of(context);
    final navTheme = FluentTheme.of(context).navigationPaneTheme;

    return StreamBuilder(
        stream: selectedChatRoomIdStream,
        builder: (context, _) {
          final groupedChatRooms = chatRoomsGrouped;
          return NavigationView(
            key: navigationProvider.viewKey,
            appBar: const NavigationAppBar(
              automaticallyImplyLeading: false,
              actions: MainAppHeaderButtons(),
            ),
            paneBodyBuilder: (item, child) {
              final name =
                  item?.key is ValueKey ? (item!.key as ValueKey).value : null;
              return FocusTraversalGroup(
                key: ValueKey('body$name'),
                child: child ?? const ChatRoomPage(),
              );
            },
            pane: NavigationPane(
              autoSuggestBox: Button(
                onPressed: () => SearchAllMessagesDialog.show(context),
                child: SizedBox(
                  height: 200,
                  child: Row(
                    children: [
                      Icon(FluentIcons.search_24_regular),
                      const SizedBox(width: 8),
                      Text('Search'),
                    ],
                  ),
                ),
              ),
              items: [
                PaneItemHeader(
                    header: Row(
                  children: [
                    const Expanded(child: Text('Chat rooms')),
                    Tooltip(
                      message: 'Create new chat',
                      child: IconButton(
                          icon: const Icon(FluentIcons.compose_24_regular,
                              size: 20),
                          onPressed: () {
                            final provider = context.read<ChatProvider>();
                            provider.createNewChatRoom();
                          }),
                    ),
                    Tooltip(
                      message: 'Deleted chats',
                      child: IconButton(
                        icon: const Icon(FluentIcons.bin_recycle_24_regular,
                            size: 20),
                        onPressed: () => DeletedChatsDialog.show(context),
                      ),
                    ),
                    Tooltip(
                      message: 'Storage usage',
                      child: IconButton(
                        icon: const Icon(FluentIcons.storage_24_regular,
                            size: 20),
                        onPressed: () => StorageUsage.show(context),
                      ),
                    ),
                    Tooltip(
                      message: 'Refresh from disk',
                      child: IconButton(
                        icon: const Icon(FluentIcons.arrow_clockwise_24_regular,
                            size: 20),
                        onPressed: () async {
                          await Provider.of<ChatProvider>(context,
                                  listen: false)
                              .initChatsFromDisk();
                          selectedChatRoomIdStream.add(selectedChatRoomId);
                        },
                      ),
                    ),
                  ],
                )),
                ...List.generate(
                  groupedChatRooms.length,
                  (i) {
                    final group = groupedChatRooms.entries.elementAt(i);
                    return PaneItemWidgetAdapter(
                      child: _PaneItemButton(
                        group: group,
                        navTheme: navTheme,
                        theme: theme,
                        // displayMode: mode,
                      ),
                    );
                  },
                ),
              ],
              autoSuggestBoxReplacement:
                  const Icon(FluentIcons.search_24_regular),
              footerItems: [
                PaneItem(
                  key: const ValueKey('/settings'),
                  icon: const Icon(FluentIcons.settings_24_regular),
                  title: const Text('Settings'),
                  body: const SettingsPage(),
                  onTap: () => Navigator.of(context).push(
                    FluentPageRoute(builder: (context) => const SettingsPage()),
                  ),
                ),
                PaneItem(
                  key: const ValueKey('/about'),
                  icon: const Icon(FluentIcons.info_24_regular),
                  title: const Text('About'),
                  body: const AboutPage(),
                  onTap: () => Navigator.of(context).push(
                    FluentPageRoute(builder: (context) => const AboutPage()),
                  ),
                ),
                PaneItem(
                  key: const ValueKey('/log'),
                  icon: const Icon(FluentIcons.bug_24_regular),
                  title: const Text('Log'),
                  body: const LogPage(),
                  onTap: () => Navigator.of(context).push(
                    FluentPageRoute(builder: (context) => const LogPage()),
                  ),
                ),
                LinkPaneItemAction(
                  icon: const Icon(FluentIcons.link_24_regular),
                  title: const Text('Source code'),
                  link: 'https://github.com/realkalash/fluent_gpt_app',
                  body: const SizedBox.shrink(),
                ),
              ],
            ),
            onOpenSearch: navigationProvider.searchFocusNode.requestFocus,
          );
        });
  }
}

class _PaneItemButton extends StatefulWidget {
  const _PaneItemButton({
    super.key,
    required this.group,
    required this.navTheme,
    required this.theme,
  });

  final MapEntry<String, List<ChatRoom>> group;
  final NavigationPaneThemeData navTheme;
  final FluentThemeData theme;

  @override
  State<_PaneItemButton> createState() => _PaneItemButtonState();
}

class _PaneItemButtonState extends State<_PaneItemButton> {
  final FlyoutController flyoutController = FlyoutController();

  void _updateUI() {
    selectedChatRoomIdStream.add(selectedChatRoomId);
  }

  @override
  Widget build(BuildContext context) {
    final maybeBody = InheritedNavigationView.maybeOf(context);
    final mode = maybeBody?.displayMode ??
        maybeBody?.pane?.displayMode ??
        PaneDisplayMode.minimal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (mode != PaneDisplayMode.compact) Text(widget.group.key),
        ...List.generate(widget.group.value.length, (i) {
          final chatRoom = widget.group.value[i];
          final selected = chatRoom.id == selectedChatRoomId;

          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: FlyoutTarget(
              controller: flyoutController,
              child: Tooltip(
                message: chatRoom.chatRoomName,
                child: GestureDetector(
                  child: Container(
                    decoration: BoxDecoration(
                      color: selected
                          ? widget.theme.accentColor
                          : widget.theme.cardColor,
                      border: mode != PaneDisplayMode.open
                          ? Border.all(color: Colors.white.withOpacity(0.1))
                          : null,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        margin: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        if (mode == PaneDisplayMode.compact)
                          SizedBox(
                            width: 18,
                            height: 40,
                            child: Center(
                              child: Text(
                                chatRoom.chatRoomName,
                                overflow: TextOverflow.clip,
                                maxLines: 1,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        if (mode != PaneDisplayMode.compact) ...[
                          Expanded(
                            child: Text(
                              chatRoom.chatRoomName,
                              style: TextStyle(overflow: TextOverflow.ellipsis),
                              maxLines: 2,
                            ),
                          ),
                          Tooltip(
                            message: 'Pin/unpin chat',
                            child: IconButton(
                                icon: chatRoom.isPinned
                                    ? const Icon(FluentIcons.pin_24_filled,
                                        size: 18)
                                    : const Icon(FluentIcons.pin_24_regular,
                                        size: 18),
                                onPressed: () {
                                  final provider = context.read<ChatProvider>();
                                  if (chatRoom.isPinned)
                                    provider.unpinChatRoom(chatRoom);
                                  else
                                    provider.pinChatRoom(chatRoom);
                                  _updateUI();
                                }),
                          ),
                          Tooltip(
                            message: 'Edit chat',
                            child: IconButton(
                                icon: const Icon(
                                  FluentIcons.chat_settings_24_regular,
                                  size: 18,
                                ),
                                onPressed: () {
                                  EditChatRoomDialog.show(
                                    context: context,
                                    room: chatRoom,
                                    onOkPressed: _updateUI,
                                  );
                                }),
                          ),
                          Tooltip(
                            message: 'Delete chat',
                            child: IconButton(
                                icon: Icon(FluentIcons.delete_24_filled,
                                    color: Colors.red, size: 18),
                                onPressed: () {
                                  final provider = context.read<ChatProvider>();
                                  if (shiftPressedStream.value) {
                                    provider.deleteChatRoomHard(chatRoom.id);
                                  } else {
                                    provider.archiveChatRoom(chatRoom);
                                  }
                                  _updateUI();
                                }),
                          ),
                        ]
                      ],
                    ),
                  ),
                  onSecondaryTap: () {
                    flyoutController.showFlyout(builder: (ctx) {
                      return FlyoutContent(
                        constraints: BoxConstraints(maxWidth: 200),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(chatRoom.chatRoomName,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                )),
                            const SizedBox(height: 4),
                            FlyoutListTile(
                              text: Text('Pin/unpin chat', style: TextStyle()),
                              icon: Icon(FluentIcons.pin_24_regular),
                              onPressed: () async {
                                final provider = context.read<ChatProvider>();
                                if (chatRoom.isPinned)
                                  provider.unpinChatRoom(chatRoom);
                                else
                                  provider.pinChatRoom(chatRoom);
                                _updateUI();
                              },
                            ),
                            FlyoutListTile(
                              text: Text('Edit chat', style: TextStyle()),
                              icon: Icon(FluentIcons.chat_settings_20_regular),
                              onPressed: () async {
                                Navigator.of(context).pop();
                                EditChatRoomDialog.show(
                                  context: context,
                                  room: chatRoom,
                                  onOkPressed: _updateUI,
                                );
                              },
                            ),
                            FlyoutListTile(
                              text: Text('Delete chat',
                                  style: TextStyle(color: Colors.red)),
                              icon: Icon(FluentIcons.delete_20_filled,
                                  color: Colors.red),
                              onPressed: () {
                                final provider = context.read<ChatProvider>();
                                Navigator.of(context).pop();
                                if (shiftPressedStream.value)
                                  provider.deleteChatRoomHard(chatRoom.id);
                                else
                                  provider.archiveChatRoom(chatRoom);
                                _updateUI();
                              },
                            ),
                          ],
                        ),
                      );
                    });
                  },
                  onTap: () {
                    final provider = context.read<ChatProvider>();
                    provider.selectChatRoom(chatRoom);
                  },
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class WindowButtons extends StatelessWidget {
  const WindowButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final FluentThemeData theme = FluentTheme.of(context);

    return SizedBox(
      width: 138,
      height: 50,
      child: WindowCaption(
        brightness: theme.brightness,
        backgroundColor: Colors.transparent,
      ),
    );
  }
}

class LinkPaneItemAction extends PaneItem {
  LinkPaneItemAction({
    required super.icon,
    required this.link,
    required super.body,
    super.title,
  });

  final String link;

  @override
  Widget build(
    BuildContext context,
    bool selected,
    VoidCallback? onPressed, {
    PaneDisplayMode? displayMode,
    bool showTextOnTop = true,
    bool? autofocus,
    int? itemIndex,
  }) {
    return Link(
      uri: Uri.parse(link),
      builder: (context, followLink) => Semantics(
        link: true,
        child: super.build(
          context,
          selected,
          followLink,
          displayMode: displayMode,
          showTextOnTop: showTextOnTop,
          itemIndex: itemIndex,
          autofocus: autofocus,
        ),
      ),
    );
  }
}