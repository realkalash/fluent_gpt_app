import 'package:fluent_gpt/log.dart';

import 'package:fluent_gpt/common/chat_room.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/pages/about_page.dart';
import 'package:fluent_gpt/pages/home_page.dart';
import 'package:fluent_gpt/pages/log_page.dart';
import 'package:fluent_gpt/pages/settings_page.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:provider/provider.dart';

import 'providers/chat_gpt_provider.dart';

class NavigationProvider with ChangeNotifier {
  bool value = false;

  /// The index of the selected item
  /// THE LAST ITEM IS A LINK THAT SHOULD NOT BE USED AS A NAVIGATION ITEM
  int index = 0;

  final viewKey = GlobalKey(debugLabel: 'Navigation View Key');
  final searchKey = GlobalKey(debugLabel: 'Search Bar Key');
  final searchFocusNode = FocusNode();
  final searchController = TextEditingController();
  // it's bad practice to use context in a provider
  late BuildContext context;
  List<NavigationPaneItem> originalItems = [];

  NavigationProvider() {
    listenChatRooms();
  }
  listenChatRooms() {
    chatRoomsStream.listen((event) {
      refreshNavItems();
    });
  }

  /// onTap will be overridden for each item
  late final originalTopItems = [
    PaneItemHeader(
        header: Row(
      children: [
        const Expanded(child: Text('Chat rooms')),
        IconButton(
            icon: const Icon(FluentIcons.compose_24_regular, size: 20),
            onPressed: () {
              final provider = context.read<ChatGPTProvider>();
              provider.createNewChatRoom();
              refreshNavItems();
            }),
        IconButton(
            icon: const Icon(FluentIcons.arrow_clockwise_24_regular, size: 20),
            onPressed: () {
              refreshNavItems();
            })
      ],
    )),
  ];

  /// onTap will be overridden for each item
  late final List<PaneItem> footerItems = [
    PaneItem(
      key: const ValueKey('/settings'),
      icon: const Icon(FluentIcons.settings_24_regular),
      title: const Text('Settings'),
      body: const SettingsPage(),
      onTap: () => _openSubRoute('/settings'),
    ),
    PaneItem(
      key: const ValueKey('/about'),
      icon: const Icon(FluentIcons.info_24_regular),
      title: const Text('About'),
      body: const AboutPage(),
      onTap: () => _openSubRoute('/about'),
    ),
    PaneItem(
      key: const ValueKey('/log'),
      icon: const Icon(FluentIcons.bug_24_regular),
      title: const Text('Log'),
      body: const LogPage(),
      onTap: () => _openSubRoute('/log'),
    ),
    LinkPaneItemAction(
      icon: const Icon(FluentIcons.link_24_regular),
      title: const Text('Source code'),
      link: 'https://github.com/realkalash/fluent_gpt',
      body: const SizedBox.shrink(),
    ),
  ];

  int getIndexPage(String page) {
    final listAllPages = [...originalItems, ...footerItems];
    final index = listAllPages.indexWhere((element) {
      if (element.key is ValueKey) {
        return (element.key as ValueKey).value == page;
      }
      return element.key == ValueKey(page);
    });
    if (index == -1) {
      log('Could not find page $page');
      return -1;
    }
    return index - 1;
  }

  void _openSubRoute(String route) {
    final newIndex = getIndexPage(route);
    if (index == -1) {
      log('Could not find route $route');
      return;
    }
    index = newIndex;
    notifyListeners();
  }

  int calculateSelectedIndex() => index;

  void addPaneItem(PaneItem item) {
    originalItems.add(item);
    notifyListeners();
  }

  void refreshNavItems() {
    originalItems.clear();
    originalItems.addAll(originalTopItems);
    for (var room in chatRooms.values) {
      addPaneItem(PaneItem(
        key: ValueKey(room.id),
        icon: const Icon(FluentIcons.chat_24_filled, size: 24),
        title: Text(room.chatRoomName),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                icon:
                    const Icon(FluentIcons.chat_settings_24_regular, size: 18),
                onPressed: () {
                  editChatRoomDialog(context, room);
                }),
            IconButton(
                icon: Icon(FluentIcons.delete_24_filled,
                    color: Colors.red, size: 18),
                onPressed: () {
                  final provider = context.read<ChatGPTProvider>();
                  // check shift key is pressed
                  if (shiftPressedStream.value) {
                    provider.deleteChatRoomHard(room.chatRoomName);
                  } else {
                    provider.deleteChatRoom(room.chatRoomName);
                  }
                  originalItems.removeWhere(
                      (element) => element.key == ValueKey(room.id));
                  if (chatRooms.length == 1) {
                    refreshNavItems();
                  } else {
                    notifyListeners();
                  }
                }),
          ],
        ),
        body: const ChatRoomPage(),
        onTap: () {
          final provider = context.read<ChatGPTProvider>();
          var index = originalItems
              .indexWhere((element) => element.key == ValueKey(room.id));
          if (index == -1) {
            log('Could not find chat room ${room.chatRoomName}');
            return;
          }
          provider.selectChatRoom(room);

          /// because we have 1 items at the bottom
          this.index = index - 1;
          notifyListeners();
        },
      ));
    }
  }

  Future<void> editChatRoomDialog(BuildContext context, ChatRoom room) async {
    await showDialog(
      context: context,
      builder: (ctx) => EditChatRoomDialog(
        room: room,
        onOkPressed: () {
          refreshNavItems();
        },
      ),
    );
  }
}

class EditChatRoomDialog extends StatelessWidget {
  const EditChatRoomDialog(
      {super.key, required this.room, required this.onOkPressed});
  final ChatRoom room;
  final VoidCallback onOkPressed;

  @override
  Widget build(BuildContext ctx) {
    final provider = ctx.read<ChatGPTProvider>();
    var roomName = room.chatRoomName;
    var systemMessage = room.systemMessage;
    var maxLength = room.maxTokenLength;
    var token = room.token;
    var orgID = room.orgID;
    return ContentDialog(
      title: const Text('Edit chat room'),
      constraints: const BoxConstraints(maxWidth: 800),
      actions: [
        Button(
          onPressed: () {
            provider.editChatRoom(
                room.chatRoomName,
                room.copyWith(
                  chatRoomName: roomName,
                  commandPrefix: systemMessage,
                  maxLength: maxLength,
                  token: token,
                  orgID: orgID,
                ));
            Navigator.of(ctx).pop();
            onOkPressed();
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
        children: [
          const Text('Chat room name'),
          TextBox(
            controller: TextEditingController(text: room.chatRoomName),
            onChanged: (value) {
              roomName = value;
            },
          ),
          const Text('System message'),
          TextBox(
            controller: TextEditingController(text: room.systemMessage),
            maxLines: 30,
            minLines: 3,
            onChanged: (value) {
              systemMessage = value;
            },
          ),
          const Text('Model'),
          GptModelChooser(
            onChanged: (model) {
              provider.selectModelForChat(room.chatRoomName, model);
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
    );
  }
}
