import 'dart:io';

import 'package:chatgpt_windows_flutter_app/log.dart';

import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:chatgpt_windows_flutter_app/common/prefs/app_cache.dart';
import 'package:chatgpt_windows_flutter_app/common/window_listener.dart';
import 'package:chatgpt_windows_flutter_app/native_channels.dart';
import 'package:chatgpt_windows_flutter_app/overlay_manager.dart';
import 'package:chatgpt_windows_flutter_app/pages/home_page.dart';
import 'package:chatgpt_windows_flutter_app/theme.dart';
import 'package:chatgpt_windows_flutter_app/tray.dart';
import 'package:chatgpt_windows_flutter_app/widgets/main_app_header_buttons.dart';
import 'package:fluent_ui/fluent_ui.dart' hide Page;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as flutter_acrylic;
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:protocol_handler/protocol_handler.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_theme/system_theme.dart';
import 'package:system_tray/system_tray.dart';
import 'package:url_launcher/link.dart';
import 'package:window_manager/window_manager.dart';
import 'package:windows_single_instance/windows_single_instance.dart';
import 'navigation_provider.dart';
import 'overlay_ui.dart';
import 'providers/chat_gpt_provider.dart';

var openAI = OpenAI.instance.build(
  token: 'empty',
  baseOption:
      HttpSetup(receiveTimeout: const Duration(seconds: kDebugMode ? 240 : 30)),
  enableLog: true,
);

SharedPreferences? prefs;

void resetOpenAiUrl({String? url, required String token}) {
  if (url != null) {}
  openAI = OpenAI.instance.build(
    token: token,
    baseOption: HttpSetup(
        receiveTimeout: const Duration(seconds: kDebugMode ? 240 : 30)),
    enableLog: true,
    apiUrl: url ?? 'https://api.openai.com/v1/',
  );
}

Future<void> initWindow() async {
  if (Platform.isMacOS) {
    // causes breaking of acrylic and mica effects on windows
    windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
  }

  await windowManager.setTitle('chatgpt_windows_flutter_app');
  await windowManager.setMinimumSize(const Size(500, 600));
  await windowManager.show();
  await windowManager.setPreventClose(prefs?.getBool('preventClose') ?? false);
  windowManager.removeListener(AppWindowListener());
  windowManager.addListener(AppWindowListener());
  await windowManager.setSkipTaskbar(AppCache.showAppInDock.value ?? true);
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
}

String appVersion = '-';
BehaviorSubject<bool> shiftPressedStream = BehaviorSubject<bool>.seeded(false);
final navigatorKey = GlobalKey<NavigatorState>();

void setupMethodChannel() {
  overlayChannel.setMethodCallHandler((call) async {
    switch (call.method) {
      case 'onTextSelected':
      // TODO: enable when ready
      // final argsNative = call.arguments as Map;
      // final args = argsNative.map<String, dynamic>(
      //   (key, value) => MapEntry(key.toString(), value),
      // );
      // // log('onTextSelected: $args');
      // final selectedText = args['selectedText'] as String?;
      // if (selectedText == null || selectedText.isEmpty) {
      //   return;
      // }
      // final isAppForegrounded = await windowManager.isFocused();
      // if (isAppForegrounded) {
      //   return;
      // }
      // final positionX = args['positionX'] as double?;
      // final positionY = args['positionY'] as double?;
      // final resolution = AppCache.resolution.value ?? '500x700';
      // final screenHeight = double.parse(resolution.split('x').last);
      // final screenWidth = double.parse(resolution.split('x').first);
      // OverlayManager.showOverlay(
      //   navigatorKey.currentContext!,
      //   positionX: positionX,
      //   positionY: positionY,
      //   resolution: Size(screenWidth, screenHeight),
      // );
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
    logError(details.exceptionAsString(), details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    logError('[Platform] $error', stack);
    return true;
  };
  await protocolHandler.register('fluentgpt');
  setupMethodChannel();

  SystemTheme.accentColor.load();
  await WindowsSingleInstance.ensureSingleInstance(
      args, "chatgpt_windows_flutter_app", onSecondWindow: (secondWindowArgs) {
    AppWindow().show();

    log('onSecondWindow. args: $args');
  });
  prefs = await SharedPreferences.getInstance();
  await flutter_acrylic.Window.initialize();
  await flutter_acrylic.Window.hideWindowControls();
  await WindowManager.instance.ensureInitialized();
  windowManager.waitUntilReadyToShow().then((_) {
    initWindow();
  });
  // For hot reload, `unregisterAll()` needs to be called.
  await hotKeyManager.unregisterAll();
  OverlayManager.init();

  runApp(const MyApp());
}

final _appTheme = AppTheme();

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
      log('size: $size');
      if (size != null) {
        await windowManager.setSize(Size(650, size.height - 100),
            animate: true);
        await windowManager.setAlignment(Alignment.centerRight, animate: true);
      } else {
        final result = await overlayChannel.invokeMethod('getScreenSize');
        log('screen result: $result');
        if (result != null) {
          final screenSize = Size(result['width'], result['height']);
          await windowManager.setSize(Size(500, screenSize.height - 100),
              animate: true);
          await windowManager.setAlignment(Alignment.centerRight,
              animate: true);
          _appTheme.setResolution(screenSize, notify: false);
        }
      }
      if (mounted) {
        await _appTheme.setEffect(flutter_acrylic.WindowEffect.acrylic);
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
        create: (context) => ChatGPTProvider(),
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
                infoBarTheme: InfoBarThemeData(
                    decoration: (severity) =>
                        appTheme.buildInfoBarDecoration(severity)),
                accentColor: appTheme.color,
                visualDensity: VisualDensity.standard,
                focusTheme: FocusThemeData(
                  glowFactor: is10footScreen(ctx) ? 2.0 : 0.0,
                ),
              ),
              theme: FluentThemeData(
                accentColor: appTheme.color,
                infoBarTheme: InfoBarThemeData(
                    decoration: (severity) =>
                        appTheme.buildInfoBarDecoration(severity)),
                visualDensity: VisualDensity.standard,
                focusTheme: FocusThemeData(
                  glowFactor: is10footScreen(ctx) ? 2.0 : 0.0,
                ),
              ),
              locale: appTheme.locale,
              builder: (ctx, child) {
                return Directionality(
                  textDirection: appTheme.textDirection,
                  child: NavigationPaneTheme(
                    data: NavigationPaneThemeData(
                      backgroundColor: appTheme.windowEffect !=
                              flutter_acrylic.WindowEffect.disabled
                          ? Colors.transparent
                          : null,
                    ),
                    child: child!,
                  ),
                );
              },
              // routeInformationParser: router.routeInformationParser,
              // routerDelegate: router.routerDelegate,
              // routeInformationProvider: router.routeInformationProvider,
            );
          },
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
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      final navigationProvider = context.read<NavigationProvider>();
      navigationProvider.refreshNavItems();

      if (openAI.token == 'empty') {
        showDialog(
          context: context,
          barrierDismissible: false,
          dismissWithEsc: false,
          builder: (ctx) {
            final provider = context.watch<ChatGPTProvider>();
            final textController = provider.dialogApiKeyController;
            return ContentDialog(
              title: const Text('OpenAI API key'),
              actions: [
                Button(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('OpenAI key'),
                  TextBox(
                    controller: textController,
                    onChanged: (v) {
                      provider.setOpenAIKeyForCurrentChatRoom(v);
                    },
                  ),
                  const Text('OpenAI group ID (optional)'),
                  TextBox(
                    onChanged: (v) {
                      provider.setOpenAIGroupIDForCurrentChatRoom(v);
                    },
                  ),
                ],
              ),
            );
          },
        );
      }
    });
  }

  @override
  void dispose() {
    final navigationProvider = context.read<NavigationProvider>();
    windowManager.removeListener(this);
    navigationProvider.searchController.dispose();
    navigationProvider.searchFocusNode.dispose();
    super.dispose();
  }

  final FocusNode _focusNode = FocusNode();

  @override
  Widget build(BuildContext context) {
    var navigationProvider = context.watch<NavigationProvider>();
    navigationProvider.context = context;
    final appTheme = context.watch<AppTheme>();
    return KeyboardListener(
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
      child: StreamBuilder<bool>(
          stream: isShowingOverlay,
          builder: (context, snapshot) {
            final isNeedToHide = snapshot.data ?? false;
            if (isNeedToHide) {
              return const OverlayUI();
            }
            return NavigationView(
              key: navigationProvider.viewKey,
              appBar: const NavigationAppBar(
                automaticallyImplyLeading: false,
                actions: MainAppHeaderButtons(),
              ),
              paneBodyBuilder: (item, child) {
                final name = item?.key is ValueKey
                    ? (item!.key as ValueKey).value
                    : null;
                return FocusTraversalGroup(
                  key: ValueKey('body$name'),
                  child: child ?? const ChatRoomPage(),
                );
              },
              pane: NavigationPane(
                selected: navigationProvider.index,
                displayMode: appTheme.displayMode,
                indicator: () {
                  switch (appTheme.indicator) {
                    case NavigationIndicators.end:
                      return const EndNavigationIndicator();
                    case NavigationIndicators.sticky:
                    default:
                      return const StickyNavigationIndicator();
                  }
                }(),
                items: navigationProvider.originalItems,
                autoSuggestBoxReplacement: const Icon(FluentIcons.search),
                footerItems: navigationProvider.footerItems,
              ),
              onOpenSearch: navigationProvider.searchFocusNode.requestFocus,
            );
          }),
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
