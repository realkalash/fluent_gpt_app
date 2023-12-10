import 'dart:developer';

import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:chatgpt_windows_flutter_app/pages/home_page.dart';
import 'package:chatgpt_windows_flutter_app/theme.dart';
import 'package:chatgpt_windows_flutter_app/tray.dart';
import 'package:chatgpt_windows_flutter_app/widgets/add_chat_button.dart';
import 'package:fluent_ui/fluent_ui.dart' hide Page;
import 'package:flutter_acrylic/flutter_acrylic.dart' as flutter_acrylic;
import 'package:go_router/go_router.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_theme/system_theme.dart';
import 'package:url_launcher/link.dart';
import 'package:window_manager/window_manager.dart';

import 'navigation_provider.dart';
import 'providers/chat_gpt_provider.dart';

final openAI = OpenAI.instance.build(
  token: 'empty',
  baseOption: HttpSetup(receiveTimeout: const Duration(seconds: 30)),
  enableLog: true,
);

SharedPreferences? prefs;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemTheme.accentColor.load();
  prefs = await SharedPreferences.getInstance();

  await flutter_acrylic.Window.initialize();
  await flutter_acrylic.Window.hideWindowControls();
  await WindowManager.instance.ensureInitialized();
  windowManager.waitUntilReadyToShow().then((_) async {
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    await windowManager.setMinimumSize(const Size(500, 600));
    await windowManager.show();
    await windowManager.setPreventClose(true);
    await windowManager.setSkipTaskbar(false);
  });
// For hot reload, `unregisterAll()` needs to be called.
  await hotKeyManager.unregisterAll();

  runApp(const MyApp());
}

final _appTheme = AppTheme();

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    _appTheme.init();
    initSystemTray();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      final size = _appTheme.resolution;
      log('size: $size');
      if (size != null) {
        await windowManager.setSize(Size(500, size.height - 100),
            animate: true);
        await windowManager.setAlignment(Alignment.centerRight, animate: true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => NavigationProvider(),
      child: ChangeNotifierProvider(
        create: (context) => ChatGPTProvider(),
        child: ChangeNotifierProvider.value(
          value: _appTheme,
          builder: (context, child) {
            final appTheme = context.watch<AppTheme>();
            return FluentApp(
              title: 'appTitle',
              themeMode: appTheme.mode,
              debugShowCheckedModeBanner: false,
              home: const MyHomePage(shellContext: null),
              color: appTheme.color,
              darkTheme: FluentThemeData(
                brightness: Brightness.dark,
                accentColor: appTheme.color,
                visualDensity: VisualDensity.standard,
                focusTheme: FocusThemeData(
                  glowFactor: is10footScreen(context) ? 2.0 : 0.0,
                ),
              ),
              theme: FluentThemeData(
                accentColor: appTheme.color,
                visualDensity: VisualDensity.standard,
                focusTheme: FocusThemeData(
                  glowFactor: is10footScreen(context) ? 2.0 : 0.0,
                ),
              ),
              locale: appTheme.locale,
              builder: (context, child) {
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

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.shellContext,
  });

  final BuildContext? shellContext;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with WindowListener {
  @override
  void initState() {
    windowManager.addListener(this);
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      final provider = context.read<ChatGPTProvider>();
      final navigationProvider = context.read<NavigationProvider>();
      navigationProvider.refreshNavItems(provider);

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

  @override
  Widget build(BuildContext context) {
    var navigationProvider = context.watch<NavigationProvider>();
    navigationProvider.context = context;

    final localizations = FluentLocalizations.of(context);

    final appTheme = context.watch<AppTheme>();
    // final theme = FluentTheme.of(context);
    if (widget.shellContext != null) {
      if (Navigator.of(context).canPop() == false) {
        setState(() {});
      }
    }
    return NavigationView(
      key: navigationProvider.viewKey,
      appBar: NavigationAppBar(
        automaticallyImplyLeading: false,
        leading: () {
          final enabled =
              widget.shellContext != null && Navigator.of(context).canPop();

          final onPressed = enabled
              ? () {
                  if (Navigator.of(context).canPop()) {
                    context.pop();
                    setState(() {});
                  }
                }
              : null;
          return NavigationPaneTheme(
            data: NavigationPaneTheme.of(context).merge(NavigationPaneThemeData(
              unselectedIconColor: ButtonState.resolveWith((states) {
                if (states.isDisabled) {
                  return ButtonThemeData.buttonColor(context, states);
                }
                return ButtonThemeData.uncheckedInputColor(
                  FluentTheme.of(context),
                  states,
                ).basedOnLuminance();
              }),
            )),
            child: Builder(
              builder: (context) => PaneItem(
                icon: const Center(child: Icon(FluentIcons.back, size: 12.0)),
                title: Text(localizations.backButtonTooltip),
                body: const SizedBox.shrink(),
                enabled: enabled,
              ).build(
                context,
                false,
                onPressed,
                displayMode: PaneDisplayMode.compact,
              ),
            ),
          );
        }(),
        title: () {
          return const DragToMoveArea(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text('appTitle'),
            ),
          );
        }(),
        actions: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            const CollapseAppButton(),
            const AddChatButton(),
            const ClearChatButton(),
            const PinAppButton(),
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 16),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: ToggleButton(
                  checked: FluentTheme.of(context).brightness.isDark,
                  onChanged: (v) {
                    if (v) {
                      appTheme.mode = ThemeMode.dark;
                    } else {
                      appTheme.mode = ThemeMode.light;
                    }
                  },
                  child: const Icon(FluentIcons.sunny),
                ),
              ),
            ),
            // if (!kIsWeb) const WindowButtons(),
          ],
        ),
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
        selected: navigationProvider.calculateSelectedIndex(context),
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
        // autoSuggestBox: Builder(builder: (context) {
        //   return AutoSuggestBox(
        //     key: navigationProvider.searchKey,
        //     focusNode: navigationProvider.searchFocusNode,
        //     controller: navigationProvider.searchController,
        //     unfocusedColor: Colors.transparent,
        //     items: navigationProvider.originalItems
        //         .whereType<PaneItem>()
        //         .map((item) {
        //       assert(item.title is Text);
        //       final text = (item.title as Text).data!;
        //       return AutoSuggestBoxItem(
        //         label: text,
        //         value: text,
        //         onSelected: () {
        //           item.onTap?.call();
        //           navigationProvider.searchController.clear();
        //           navigationProvider.searchFocusNode.unfocus();
        //           final view = NavigationView.of(context);
        //           if (view.compactOverlayOpen) {
        //             view.compactOverlayOpen = false;
        //           } else if (view.minimalPaneOpen) {
        //             view.minimalPaneOpen = false;
        //           }
        //         },
        //       );
        //     }).toList(),
        //     trailingIcon: IgnorePointer(
        //       child: IconButton(
        //         onPressed: () {},
        //         icon: const Icon(FluentIcons.search),
        //       ),
        //     ),
        //     placeholder: 'Search',
        //   );
        // }),
      ),
      onOpenSearch: navigationProvider.searchFocusNode.requestFocus,
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
