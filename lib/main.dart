import 'dart:io';

import 'package:fluent_gpt/dialogs/chat_room_dialog.dart';
import 'package:fluent_gpt/dialogs/deleted_chats_dialog.dart';
import 'package:fluent_gpt/dialogs/storage_usage.dart';
import 'package:fluent_gpt/features/additional_features.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/common/window_listener.dart';
import 'package:fluent_gpt/native_channels.dart';
import 'package:fluent_gpt/notification_util.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/pages/home_page.dart';
import 'package:fluent_gpt/pages/settings_page.dart';
import 'package:fluent_gpt/pages/welcome/welcome_tab.dart';
import 'package:fluent_gpt/system_messages.dart';
import 'package:fluent_gpt/theme.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:fluent_gpt/widgets/main_app_header_buttons.dart';
import 'package:fluent_ui/fluent_ui.dart' hide Page, FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as flutter_acrylic;
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:protocol_handler/protocol_handler.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_theme/system_theme.dart';
import 'package:url_launcher/link.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_single_instance/windows_single_instance.dart';
import 'navigation_provider.dart';
import 'overlay/overlay_ui.dart';
import 'overlay/sidebar_overlay_ui.dart';
import 'providers/chat_provider.dart';
import 'providers/server_provider.dart';

SharedPreferences? prefs;

const defaultMinimumWindowSize = Size(500, 600);
Future<void> initWindow() async {
  if (AppCache.frameless.value!) {
    await windowManager.setAsFrameless();
  }
  if (AppCache.hideTitleBar.value!) {
    windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
  }

  await windowManager.setTitle('fluent_gpt');
  await windowManager.setMinimumSize(defaultMinimumWindowSize);
  await windowManager.show();
  windowManager.removeListener(AppWindowListener());
  windowManager.addListener(AppWindowListener());
  await windowManager.setAlwaysOnTop(AppCache.alwaysOnTop.value!);
  final lastWindowWidth = AppCache.windowWidth.value;
  final lastWindowHeight = AppCache.windowHeight.value;
  if (lastWindowWidth != null && lastWindowHeight != null) {
    await windowManager.setSize(
      Size(lastWindowWidth.toDouble(), lastWindowHeight.toDouble()),
    );
  }
  final lastWindowX = AppCache.windowX.value;
  final lastWindowY = AppCache.windowY.value;
  if (lastWindowX != null && lastWindowY != null) {
    await windowManager.setPosition(
      Offset(lastWindowX.toDouble(), lastWindowY.toDouble()),
    );
  }
  if (Platform.isMacOS) {
    await windowManager.setSkipTaskbar(AppCache.showAppInDock.value == false);
  }
}

String appVersion = '-';
PackageInfo? packageInfo;
BehaviorSubject<bool> shiftPressedStream = BehaviorSubject<bool>.seeded(false);
final navigatorKey = GlobalKey<NavigatorState>();

void setupMethodChannel() {
  overlayChannel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'onTextSelected':
      // TODO: enable when ready
      case 'onMouseUp':
        break;
      case 'onTimerFired':
        break;
      case 'showOverlay':
        break;
      default:
        throw PlatformException(
            code: 'Unimplemented',
            details: '${call.method} is not implemented');
    }
  });
}

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    if (kDebugMode) {
      logError(details.exceptionAsString(), details.stack);
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    logError('[Platform] $error', stack);
    return true;
  };
  initializeNotifications();
  await protocolHandler.register('fluentgpt');
  setupMethodChannel();
  if (Platform.isMacOS || Platform.isWindows) {
    SystemTheme.accentColor.load();
  }
  await WindowsSingleInstance.ensureSingleInstance(args, "fluent_gpt",
      onSecondWindow: (secondWindowArgs) {
    windowManager.show();

    log('onSecondWindow. args: $args');
  });
  prefs = await SharedPreferences.getInstance();
  if (AppCache.isWelcomeShown.value == true) {
    await FileUtils.init();
  }
  defaultSystemMessage = AppCache.globalSystemPrompt.value!;
  infoAboutUser = (await AppCache.userInfo.value());
  if (Platform.isMacOS || Platform.isWindows) {
    await flutter_acrylic.Window.initialize();
    await flutter_acrylic.Window.hideWindowControls();
  }
  await WindowManager.instance.ensureInitialized();
  windowManager.waitUntilReadyToShow().then((_) {
    initWindow();
  });
  // For hot reload, `unregisterAll()` needs to be called.
  await hotKeyManager.unregisterAll();
  OverlayManager.init();
  AdditionalFeatures.initAdditionalFeatures(
      isStorageAccessGranted: AppCache.isStorageAccessGranted.value!);
  packageInfo = await PackageInfo.fromPlatform();
  launchAtStartup.setup(
    appName: packageInfo!.appName,
    appPath: Platform.resolvedExecutable,
    // Set packageName parameter to support MSIX.
    packageName: packageInfo!.packageName,
  );
  
  launchAtStartup.isEnabled().then((value) {
    isLaunchAtStartupEnabled = value;
  });

  runApp(const MyApp());
}

final _appTheme = AppTheme();

/// The context of the app. Use with caution.
BuildContext? appContext;

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with ProtocolListener {
  @override
  void initState() {
    super.initState();
    protocolHandler.addListener(this);
    _appTheme.init();
    initSystemTray();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      final size = _appTheme.resolution;
      if (size == null && (Platform.isMacOS || Platform.isWindows)) {
        final result = await NativeChannelUtils.getScreenSize();
        if (result != null) {
          final screenSize =
              Size(result['width']!.toDouble(), result['height']!.toDouble());

          _appTheme.setResolution(screenSize, notify: false);
        }
      }
      if (mounted) {
        _appTheme.postInit();
      }
    });
  }

  @override
  void dispose() {
    protocolHandler.removeListener(this);
    super.dispose();
  }

  @override
  void onProtocolUrlReceived(String url) {
    super.onProtocolUrlReceived(url);
    log('Url received: $url');
    trayButtonStream.add(url);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => NavigationProvider(),
      child: ChangeNotifierProvider(
        create: (context) => ChatProvider(),
        child: ChangeNotifierProvider(
          create: (context) => ServerProvider(),
          child: ChangeNotifierProvider.value(
            value: _appTheme,
            builder: (ctx, child) {
              final appTheme = ctx.watch<AppTheme>();
              return FluentApp(
                title: '',
                navigatorKey: navigatorKey,
                onGenerateTitle: (context) => 'ChatGPT',
                themeMode: appTheme.mode,
                debugShowCheckedModeBanner: false,
                home: const GlobalPage(),
                color: appTheme.color,
                supportedLocales: const [Locale('en')],
                darkTheme: FluentThemeData(
                  brightness: Brightness.dark,
                  scaffoldBackgroundColor: _appTheme.darkBackgroundColor,
                  infoBarTheme: InfoBarThemeData(
                      decoration: (severity) =>
                          appTheme.buildInfoBarDecoration(severity)),
                  accentColor: appTheme.color,
                  iconTheme: const IconThemeData(size: 20, color: Colors.white),
                  cardColor: _appTheme.darkCardColor,
                ),
                theme: FluentThemeData(
                  accentColor: appTheme.color,
                  scaffoldBackgroundColor: _appTheme.lightBackgroundColor,
                  infoBarTheme: InfoBarThemeData(
                      decoration: (severity) =>
                          appTheme.buildInfoBarDecoration(severity)),
                  iconTheme: const IconThemeData(size: 20),
                  cardColor: _appTheme.lightCardColor,
                ),
                locale: appTheme.locale,
                builder: (ctx, child) {
                  return NavigationPaneTheme(
                    data: NavigationPaneThemeData(
                      backgroundColor: appTheme.isDark
                          ? _appTheme.darkBackgroundColor
                          : _appTheme.lightBackgroundColor,
                    ),
                    child: child!,
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class GlobalPage extends StatefulWidget {
  const GlobalPage({
    super.key,
  });

  @override
  State<GlobalPage> createState() => _GlobalPageState();
}

class _GlobalPageState extends State<GlobalPage> with WindowListener {
  @override
  void initState() {
    windowManager.addListener(this);
    super.initState();
  }

  @override
  void dispose() {
    // final navigationProvider = context.read<NavigationProvider>();
    windowManager.removeListener(this);
    // navigationProvider.searchController.dispose();
    // navigationProvider.searchFocusNode.dispose();
    super.dispose();
  }

  final FocusNode _focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    context.watch<NavigationProvider>();
    if (AppCache.isWelcomeShown.value! == false) return const WelcomeTab();
    appContext = context;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10.0),
      child: GestureDetector(
        onPanStart: (v) => WindowManager.instance.startDragging(),
        dragStartBehavior: DragStartBehavior.start,
        behavior: HitTestBehavior.translucent,
        child: KeyboardListener(
          focusNode: _focusNode,
          onKeyEvent: (event) {
            if (event is KeyRepeatEvent) return;
            if (!mounted) return;
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.shiftLeft) {
              shiftPressedStream.add(true);
            }
            if (event is KeyUpEvent &&
                event.logicalKey == LogicalKeyboardKey.shiftLeft) {
              shiftPressedStream.add(false);
            }
          },
          child: StreamBuilder<OverlayStatus>(
              stream: overlayVisibility,
              builder: (context, snapshot) {
                if (snapshot.data?.isShowingOverlay == true) {
                  return const OverlayUI();
                }
                if (snapshot.data?.isShowingSidebarOverlay == true) {
                  return const SidebarOverlayUI();
                }
                return const MainPageWithNavigation();
              }),
        ),
      ),
    );
  }

  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose && mounted) {
      showDialog(
        context: context,
        builder: (_) {
          return ContentDialog(
            title: const Text('Confirm close'),
            content: const Text('Are you sure you want to close this window?'),
            actions: [
              FilledButton(
                child: const Text('Yes'),
                onPressed: () {
                  Navigator.pop(context);
                  windowManager.destroy();
                },
              ),
              Button(
                child: const Text('No'),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      );
    }
  }
}

class MainPageWithNavigation extends StatelessWidget {
  const MainPageWithNavigation({super.key});

  @override
  Widget build(BuildContext context) {
    final navigationProvider = context.read<NavigationProvider>();
    return StreamBuilder(
        stream: selectedChatRoomIdStream,
        builder: (context, _) {
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
              autoSuggestBox: AutoSuggestBox(
                placeholder: 'Search by name',
                itemBuilder: (context, item) {
                  return ListTile(
                    leading: Icon(
                      IconData(
                        chatRoomsStream.value[item.value]!.iconCodePoint,
                        fontPackage: 'fluentui_system_icons',
                        fontFamily: 'FluentSystemIcons-Filled',
                      ),
                    ),
                    title: Text(item.label, maxLines: 1),
                    onPressed: () {
                      final provider = context.read<ChatProvider>();
                      final id = item.value;
                      provider.selectChatRoom(chatRoomsStream.value[id]!);
                    },
                  );
                },
                items: chatRoomsStream.value.values
                    .map((item) => AutoSuggestBoxItem(
                          label: item.chatRoomName,
                          value: item.id,
                        ))
                    .toList(),
                leadingIcon: const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(FluentIcons.search_24_regular)),
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
                ...chatRoomsStream.value.values.map((room) => PaneItem(
                      key: ValueKey(room.id),
                      tileColor: WidgetStatePropertyAll(
                        room.id == selectedChatRoomId
                            ? FluentTheme.of(context).accentColor
                            : Colors.transparent,
                      ),
                      icon: Icon(
                        IconData(
                          room.iconCodePoint,
                          fontPackage: 'fluentui_system_icons',
                          fontFamily: 'FluentSystemIcons-Filled',
                        ),
                        size: 20,
                      ),
                      title: Text(room.chatRoomName),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
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
                                    room: room,
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
                                  // check shift key is pressed
                                  if (shiftPressedStream.value) {
                                    provider.deleteChatRoomHard(room.id);
                                  } else {
                                    provider.archiveChatRoom(room);
                                  }
                                  _updateUI();
                                }),
                          ),
                        ],
                      ),
                      body: const ChatRoomPage(),
                      onTap: () {
                        final provider = context.read<ChatProvider>();
                        provider.selectChatRoom(room);
                      },
                    )),
              ],
              autoSuggestBoxReplacement:
                  const Icon(FluentIcons.search_24_regular),
              footerItems: navigationProvider.footerItems,
            ),
            onOpenSearch: navigationProvider.searchFocusNode.requestFocus,
          );
        });
  }

  void _updateUI() {
    selectedChatRoomIdStream.add(selectedChatRoomId);
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
