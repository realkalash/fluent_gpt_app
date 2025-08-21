import 'dart:io';

import 'package:fluent_gpt/features/additional_features.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/common/window_listener.dart';
import 'package:fluent_gpt/main_page_with_navbar.dart';
import 'package:fluent_gpt/native_channels.dart';
import 'package:fluent_gpt/notification_util.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/overlay/search_overlay_ui.dart';
import 'package:fluent_gpt/pages/settings_page.dart';
import 'package:fluent_gpt/pages/welcome/welcome_tab.dart';
import 'package:fluent_gpt/system_messages.dart';
import 'package:fluent_gpt/theme.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:fluent_gpt/services/update_manager.dart';
import 'package:fluent_ui/fluent_ui.dart' hide Page, FluentIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as flutter_acrylic;
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:protocol_handler/protocol_handler.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:simple_spell_checker_en_lan/simple_spell_checker_en_lan.dart';
// import 'package:simple_spell_checker_ru_lan/simple_spell_checker_ru_lan.dart';
import 'package:system_theme/system_theme.dart';
import 'package:window_manager/window_manager.dart';
import 'navigation_provider.dart';
import 'overlay/overlay_ui.dart';
import 'overlay/sidebar_overlay_ui.dart';
import 'providers/chat_provider.dart';
import 'providers/server_provider.dart';
import 'providers/weather_provider.dart';

SharedPreferences? prefs;

const defaultMinimumWindowSize = Size(500, 600);
Offset mouseLocalPosition = Offset(0, 0);
Future<void> initWindow() async {
  if (AppCache.frameless.value!) {
    windowManager.setAsFrameless();
  }
  if (AppCache.hideTitleBar.value!) {
    windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
  }

  windowManager.setTitle('fluent_gpt');
  windowManager.setMinimumSize(defaultMinimumWindowSize);
  // windowManager.show();
  windowManager.removeListener(AppWindowListener());
  final lastWindowWidth = AppCache.windowWidth.value;
  final lastWindowHeight = AppCache.windowHeight.value;
  final lastWindowX = AppCache.windowX.value;
  final lastWindowY = AppCache.windowY.value;
  if (lastWindowWidth != null && lastWindowHeight != null && lastWindowX != null && lastWindowY != null) {
    await windowManager.setBounds(
      null,
      size: Size(lastWindowWidth.toDouble(), lastWindowHeight.toDouble()),
      position: Offset(lastWindowX.toDouble(), lastWindowY.toDouble()),
      animate: false,
    );
  } else {
    if (lastWindowWidth != null && lastWindowHeight != null) {
      await windowManager.setSize(
        Size(lastWindowWidth.toDouble(), lastWindowHeight.toDouble()),
      );
    }
    if (lastWindowX != null && lastWindowY != null) {
      await windowManager.setPosition(
        Offset(lastWindowX.toDouble(), lastWindowY.toDouble()),
      );
    }
  }
  if (Platform.isMacOS) {
    await windowManager.setSkipTaskbar(AppCache.showAppInDock.value == false);
  }
  windowManager.addListener(AppWindowListener());
}

String appVersion = '-';
PackageInfo? packageInfo;
BehaviorSubject<bool> shiftPressedStream = BehaviorSubject<bool>.seeded(false);
BehaviorSubject<bool> altPressedStream = BehaviorSubject<bool>.seeded(false);
BehaviorSubject<bool> escPressedStream = BehaviorSubject<bool>.seeded(false);
BehaviorSubject<bool> ctrlPressedStream = BehaviorSubject<bool>.seeded(false);
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
        throw PlatformException(code: 'Unimplemented', details: '${call.method} is not implemented');
    }
  });
}

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // SimpleSpellCheckerRuRegister.registerLan();
  // SimpleSpellCheckerEnRegister.registerLan();
  await windowManager.ensureInitialized();

  if (await FlutterSingleInstance().isFirstInstance() == false) {
    log("App is already running");
    showWindow();
    return;
  }
  FlutterError.onError = (details) {
    if (kDebugMode) {
      logError(details.exceptionAsString(), details.stack);
    }
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    logError('[Platform] $error', stack);
    return true;
  };
  await protocolHandler.register('fluentgpt');
  setupMethodChannel();
  if (Platform.isMacOS || Platform.isWindows) {
    SystemTheme.accentColor.load();
  }

  prefs = await SharedPreferences.getInstance();
  I18n.init();
  if (AppCache.isWelcomeShown.value == true) {
    await FileUtils.init();
  }
  if (AppCache.globalSystemPrompt.value!.isNotEmpty) {
    defaultGlobalSystemMessage = AppCache.globalSystemPrompt.value!;
  }
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
  AdditionalFeatures.initAdditionalFeatures(isStorageAccessGranted: AppCache.isStorageAccessGranted.value!);
  packageInfo = await PackageInfo.fromPlatform();
  initializeNotifications(packageInfo?.packageName);
  launchAtStartup.setup(
    appName: packageInfo!.appName,
    appPath: Platform.resolvedExecutable,
    // Set packageName parameter to support MSIX.
    packageName: packageInfo!.packageName,
  );
  if (Platform.isMacOS == false) {
    launchAtStartup.isEnabled().then((value) {
      isLaunchAtStartupEnabled = value;
    });
  }

  // Initialize the update manager
  UpdateManager.instance.initialize();

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
          final screenSize = Size(result['width']!.toDouble(), result['height']!.toDouble());

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
              return ChangeNotifierProvider(
                  create: (ctx) => WeatherProvider(context),
                  lazy: true,
                  builder: (context, snapshot) {
                    return Listener(
                      onPointerDown: (event) => mouseLocalPosition = event.position,
                      child: FluentApp(
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
                          visualDensity: appTheme.visualDensity,
                          scaffoldBackgroundColor: _appTheme.darkBackgroundColor,
                          infoBarTheme:
                              InfoBarThemeData(decoration: (severity) => appTheme.buildInfoBarDecoration(severity)),
                          accentColor: appTheme.color,
                          iconTheme: const IconThemeData(size: 20, color: Colors.white),
                          cardColor: _appTheme.darkCardColor,
                        ),
                        theme: FluentThemeData(
                          accentColor: appTheme.color,
                          visualDensity: appTheme.visualDensity,
                          scaffoldBackgroundColor: _appTheme.lightBackgroundColor,
                          infoBarTheme:
                              InfoBarThemeData(decoration: (severity) => appTheme.buildInfoBarDecoration(severity)),
                          iconTheme: const IconThemeData(size: 20),
                          cardColor: _appTheme.lightCardColor,
                        ),
                        locale: appTheme.locale,
                        builder: (ctx, child) {
                          return NavigationPaneTheme(
                            data: NavigationPaneThemeData(
                              backgroundColor:
                                  appTheme.isDark ? _appTheme.darkBackgroundColor : _appTheme.lightBackgroundColor,
                            ),
                            child: child!,
                          );
                        },
                      ),
                    );
                  });
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
      borderRadius: BorderRadius.circular(8.0),
      child: GestureDetector(
        onPanStart: (v) => WindowManager.instance.startDragging(),
        dragStartBehavior: DragStartBehavior.start,
        behavior: HitTestBehavior.translucent,
        child: KeyboardListener(
          focusNode: _focusNode,
          onKeyEvent: (event) {
            if (event is KeyRepeatEvent) return;
            if (!mounted) return;
            if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.shiftLeft) {
              shiftPressedStream.add(true);
            } else if (event is KeyUpEvent && event.logicalKey == LogicalKeyboardKey.shiftLeft) {
              shiftPressedStream.add(false);
            } else if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.escape) {
              escPressedStream.add(true);
            } else if (event is KeyUpEvent && event.logicalKey == LogicalKeyboardKey.escape) {
              escPressedStream.add(false);
            } else if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.controlLeft) {
              ctrlPressedStream.add(true);
            } else if (event is KeyUpEvent && event.logicalKey == LogicalKeyboardKey.controlLeft) {
              ctrlPressedStream.add(false);
            } else if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.altLeft) {
              altPressedStream.add(true);
            } else if (event is KeyUpEvent && event.logicalKey == LogicalKeyboardKey.altLeft) {
              altPressedStream.add(false);
            }
          },
          child: StreamBuilder<OverlayStatus>(
              stream: overlayVisibility,
              initialData: overlayVisibility.value,
              builder: (context, snapshot) {
                if (snapshot.data?.isShowingOverlay == true) {
                  return const OverlayUI();
                }
                if (snapshot.data?.isShowingSidebarOverlay == true) {
                  return const SidebarOverlayUI();
                }
                if (snapshot.data?.isShowingSearchOverlay == true) {
                  return const SearchOverlayUI();
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
