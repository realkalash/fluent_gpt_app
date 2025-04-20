import 'package:fluent_gpt/common/chat_room.dart';
import 'package:fluent_gpt/dialogs/chat_room_dialog.dart';
import 'package:fluent_gpt/dialogs/deleted_chats_dialog.dart';
import 'package:fluent_gpt/dialogs/search_all_messages_dialog.dart';
import 'package:fluent_gpt/dialogs/storage_usage.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/navigation_provider.dart';
import 'package:fluent_gpt/pages/home_page.dart';
import 'package:fluent_gpt/pages/new_settings_page.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/link.dart';
import 'package:window_manager/window_manager.dart';

import 'pages/about_page.dart';
import 'pages/log_page.dart';
import 'widgets/main_app_header_buttons.dart';

class MainPageWithNavigation extends StatefulWidget {
  const MainPageWithNavigation({super.key});

  @override
  State<MainPageWithNavigation> createState() => _MainPageWithNavigationState();
}

class _MainPageWithNavigationState extends State<MainPageWithNavigation> {
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
                      Text('Search'.tr),
                    ],
                  ),
                ),
              ),
              items: [
                PaneItemHeader(
                    header: Row(
                  children: [
                    Expanded(child: Text('Chat rooms'.tr)),
                    Tooltip(
                      message: 'Create new chat'.tr,
                      child: IconButton(
                          icon: const Icon(FluentIcons.compose_24_regular,
                              size: 20),
                          onPressed: () {
                            final provider = context.read<ChatProvider>();
                            provider.createNewChatRoom();
                          }),
                    ),
                    Tooltip(
                      message: 'Create folder'.tr,
                      child: IconButton(
                        icon: const Icon(FluentIcons.folder_add_24_regular,
                            size: 20),
                        onPressed: () {
                          final provider = context.read<ChatProvider>();
                          provider.createChatRoomFolder();
                          setState(() {});
                        },
                      ),
                    ),
                    Tooltip(
                      message: 'Deleted chats'.tr,
                      child: IconButton(
                        icon: const Icon(FluentIcons.bin_recycle_24_regular,
                            size: 20),
                        onPressed: () => DeletedChatsDialog.show(context),
                      ),
                    ),
                    Tooltip(
                      message: 'Storage usage'.tr,
                      child: IconButton(
                        icon: const Icon(FluentIcons.storage_24_regular,
                            size: 20),
                        onPressed: () => StorageUsage.show(context),
                      ),
                    ),
                    Tooltip(
                      message: 'Refresh from disk'.tr,
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
                      applyPadding: false,
                      child: _PaneItemButton(
                        key: ValueKey(group.key),
                        group: group,
                        navTheme: navTheme,
                        theme: theme,
                        parentFolderId: null,
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
                  title: Text('Settings'.tr),
                  body: const NewSettingsPage(),
                  onTap: () => Navigator.of(context).push(
                    FluentPageRoute(
                        builder: (context) => const NewSettingsPage()),
                  ),
                ),
                PaneItem(
                  key: const ValueKey('/about'),
                  icon: const Icon(FluentIcons.info_24_regular),
                  title: Text('About'.tr),
                  body: const AboutPage(),
                  onTap: () => Navigator.of(context).push(
                    FluentPageRoute(builder: (context) => const AboutPage()),
                  ),
                ),
                // if (kDebugMode)
                //   PaneItem(
                //     key: const ValueKey('/local'),
                //     icon: const Icon(FluentIcons.developer_board_16_filled),
                //     title: Text('Local'.tr),
                //     body: const AboutPage(),
                //     onTap: () => Navigator.of(context).push(
                //       FluentPageRoute(builder: (context) => const AboutPage()),
                //     ),
                //   ),
                PaneItem(
                  key: const ValueKey('/log'),
                  icon: const Icon(FluentIcons.bug_24_regular),
                  title: Text('Log'.tr),
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
    required this.parentFolderId,
  });

  final MapEntry<String, List<ChatRoom>> group;
  final NavigationPaneThemeData navTheme;
  final FluentThemeData theme;
  final String? parentFolderId;

  @override
  State<_PaneItemButton> createState() => _PaneItemButtonState();
}

class _PaneItemButtonState extends State<_PaneItemButton> {
  final FlyoutController flyoutController = FlyoutController();
  String? openedFolderId;

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
        if (mode != PaneDisplayMode.compact && widget.group.key != '')
          Padding(
            padding: const EdgeInsets.only(top: 8.0, left: 8.0),
            child:
                Text(widget.group.key, style: widget.theme.typography.subtitle),
          ),
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
                          ? Border.all(color: Colors.white.withAlpha(25))
                          : null,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    margin:
                        const EdgeInsets.symmetric(vertical: 2, horizontal: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (mode == PaneDisplayMode.compact) ...[
                              SizedBox(
                                width: 30,
                                height: 40,
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    if (chatRoom.isFolder)
                                      Icon(
                                        openedFolderId == chatRoom.id
                                            ? FluentIcons.folder_open_24_regular
                                            : FluentIcons.folder_24_regular,
                                        size: 30,
                                      ),
                                    Center(
                                      child: Text(
                                        chatRoom.chatRoomName,
                                        overflow: TextOverflow.clip,
                                        maxLines: 1,
                                        textAlign: TextAlign.center,
                                      ),
                                    )
                                  ],
                                ),
                              ),
                            ],
                            if (mode != PaneDisplayMode.compact) ...[
                              if (chatRoom.isFolder)
                                SizedBox(
                                  width: 24,
                                  height: 40,
                                  child: Icon(openedFolderId == chatRoom.id
                                      ? FluentIcons.folder_open_24_filled
                                      : FluentIcons.folder_24_filled),
                                ),
                              Expanded(
                                child: Text(
                                  chatRoom.chatRoomName,
                                  style: TextStyle(
                                      overflow: TextOverflow.ellipsis),
                                  maxLines: 2,
                                ),
                              ),
                              Tooltip(
                                message: 'Pin/unpin chat'.tr,
                                child: IconButton(
                                    icon: chatRoom.isPinned
                                        ? const Icon(FluentIcons.pin_24_filled,
                                            size: 18)
                                        : const Icon(FluentIcons.pin_24_regular,
                                            size: 18),
                                    onPressed: () {
                                      final provider =
                                          context.read<ChatProvider>();
                                      if (chatRoom.isPinned)
                                        provider.unpinChatRoom(chatRoom);
                                      else
                                        provider.pinChatRoom(chatRoom);
                                      _updateUI();
                                    }),
                              ),
                              if (!chatRoom.isFolder)
                                Tooltip(
                                  message: 'Edit chat'.tr,
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
                                message: 'Delete chat'.tr,
                                child: IconButton(
                                    icon: Icon(FluentIcons.delete_24_filled,
                                        color: Colors.red, size: 18),
                                    onPressed: () {
                                      final provider =
                                          context.read<ChatProvider>();
                                      if (widget.parentFolderId != null) {
                                        provider.moveChatRoomToParentFolder(
                                            chatRoom);
                                      } else {
                                        provider.archiveChatRoom(chatRoom);
                                      }

                                      _updateUI();
                                    }),
                              ),
                            ]
                          ],
                        ),
                        if (chatRoom.isFolder && openedFolderId == chatRoom.id)
                          Padding(
                            padding: const EdgeInsets.only(left: 8.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: List.generate(
                                chatRoom.children!.length,
                                (i) {
                                  final item = chatRoom.children![i];
                                  return _PaneItemButton(
                                    group: MapEntry('', [item]),
                                    navTheme: widget.navTheme,
                                    theme: widget.theme,
                                    parentFolderId: chatRoom.id,
                                  );
                                },
                              ),
                            ),
                          )
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
                            Text(
                              chatRoom.chatRoomName,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Divider(),
                            FlyoutListTile(
                              text: Text('Pin/unpin chat'.tr, style: TextStyle()),
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
                            Divider(),
                            if (chatRoom.isFolder)
                              FlyoutListTile(
                                text: Text('Ungroup'.tr, style: TextStyle()),
                                icon: Icon(FluentIcons.group_20_regular),
                                onPressed: () {
                                  final provider = context.read<ChatProvider>();
                                  provider.ungroupByFolder(chatRoom);
                                  _updateUI();
                                  Navigator.of(context).pop();
                                },
                              ),
                            // if root we can create folder
                            if (widget.parentFolderId == null)
                              FlyoutListTile(
                                text: Text('Create folder'.tr, style: TextStyle()),
                                icon: Icon(FluentIcons.folder_24_filled),
                                onPressed: () {
                                  final provider = context.read<ChatProvider>();
                                  provider.createChatRoomFolder(
                                    chatRoomsForFolder: [chatRoom],
                                    parentFolderId: widget.parentFolderId,
                                  );
                                  _updateUI();
                                  Navigator.of(context).pop();
                                },
                              ),
                            FlyoutListTile(
                              text: Text('Move to Folder'.tr, style: TextStyle()),
                              icon: Icon(FluentIcons.folder_24_filled),
                              onPressed: () {
                                Navigator.of(context).pop();
                                _showMoveToFolderMenu(
                                  context,
                                  chatRoom,
                                  parentFolderId: widget.parentFolderId,
                                );
                              },
                            ),
                            Divider(),
                            FlyoutListTile(
                              text: Text('Edit chat'.tr, style: TextStyle()),
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
                              text: Text('Duplicate chat'.tr, style: TextStyle()),
                              icon: Icon(FluentIcons.document_copy_20_regular),
                              onPressed: () async {
                                final provider = context.read<ChatProvider>();
                                await provider.duplicateChatRoom(chatRoom);
                                // ignore: use_build_context_synchronously
                                Navigator.of(context).pop();
                                _updateUI();
                              },
                            ),
                            FlyoutListTile(
                              text: Text('Delete chat'.tr,
                                  style: TextStyle(color: Colors.red)),
                              icon: Icon(FluentIcons.delete_20_filled,
                                  color: Colors.red),
                              onPressed: () {
                                final provider = context.read<ChatProvider>();
                                Navigator.of(context).pop();
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
                    if (chatRoom.isFolder) {
                      if (mode != PaneDisplayMode.compact) {
                        setState(() {
                          openedFolderId = openedFolderId == chatRoom.id
                              ? null
                              : chatRoom.id;
                        });
                      } else {
                        // if compact we should show overlay flyout
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
                                Divider(),
                                ...List.generate(
                                  chatRoom.children!.length,
                                  (i) {
                                    final child = chatRoom.children![i];
                                    return FlyoutListTile(
                                      text: Text(child.chatRoomName,
                                          style: TextStyle()),
                                      icon: Icon(FluentIcons.chat_20_regular),
                                      onPressed: () {
                                        provider.selectChatRoom(child);
                                        Navigator.of(context).pop();
                                      },
                                    );
                                  },
                                ),
                              ],
                            ),
                          );
                        });
                      }
                      return;
                    }
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

  List<ChatRoom> getChatRoomsFoldersRecursive(List<ChatRoom> chatRooms) {
    final folders = chatRooms.where((element) => element.isFolder).toList();
    final List<ChatRoom> allFolders = [];
    for (final folder in folders) {
      final children = getChatRoomsFoldersRecursive(folder.children!);
      allFolders.addAll(children);
    }
    allFolders.addAll(folders);
    return allFolders;
  }

  void _showMoveToFolderMenu(BuildContext context, ChatRoom chatRoom,
      {String? parentFolderId}) {
    final provider = context.read<ChatProvider>();
    // provider.createChatRoomFolder([chatRoom]);
    // _updateUI();
    final chatRoomFolders =
        getChatRoomsFoldersRecursive(chatRooms.values.toList());
    flyoutController.showFlyout(builder: (ctx) {
      return FlyoutContent(
        constraints: BoxConstraints(maxWidth: 200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Move to Folder',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Divider(),
            if (parentFolderId != null)
              FlyoutListTile(
                text: Text('Move out', style: TextStyle()),
                icon: Icon(FluentIcons.folder_arrow_up_24_regular),
                onPressed: () {
                  provider.moveChatRoomToParentFolder(chatRoom);
                  Navigator.of(context).pop();
                  _updateUI();
                },
              ),
            ...List.generate(
              chatRoomFolders.length,
              (i) {
                final folder = chatRoomFolders[i];
                if (folder.id == parentFolderId) return const SizedBox.shrink();
                return FlyoutListTile(
                  text: Text(folder.chatRoomName, style: TextStyle()),
                  icon: Icon(FluentIcons.folder_24_filled),
                  onPressed: () {
                    provider.moveChatRoomToFolder(
                      chatRoom,
                      folder,
                      parentFolder: widget.parentFolderId,
                    );
                    Navigator.of(context).pop();
                    _updateUI();
                  },
                );
              },
            ),
          ],
        ),
      );
    });
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
