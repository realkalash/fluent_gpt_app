import 'package:fluent_gpt/common/prefs/app_cache.dart';

import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/pages/about_page.dart';
import 'package:fluent_gpt/pages/log_page.dart';
import 'package:fluent_gpt/pages/settings_page.dart';
import 'package:fluent_gpt/pages/welcome/welcome_shortcuts_helper_screen.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:window_manager/window_manager.dart';

import 'pages/welcome/welcome_llm_screen.dart';
import 'pages/welcome/welcome_permissions_page.dart';
import 'pages/welcome/welcome_screen.dart';

class NavigationProvider with ChangeNotifier {
  final viewKey = GlobalKey(debugLabel: 'Navigation View Key');
  final searchKey = GlobalKey(debugLabel: 'Search Bar Key');
  final searchFocusNode = FocusNode();
  final searchController = TextEditingController();
  // it's bad practice to use context in a provider
  // late BuildContext context;
  BuildContext? get context => navigatorKey.currentContext;

  NavigationProvider();

  /// onTap will be overridden for each item
  late final List<PaneItem> footerItems = [
    PaneItem(
      key: const ValueKey('/settings'),
      icon: const Icon(FluentIcons.settings_24_regular),
      title: const Text('Settings'),
      body: const SettingsPage(),
      onTap: () => Navigator.of(context!).pushNamed('/settings'),
    ),
    PaneItem(
      key: const ValueKey('/about'),
      icon: const Icon(FluentIcons.info_24_regular),
      title: const Text('About'),
      body: const AboutPage(),
      onTap: () => Navigator.of(context!).pushNamed('/about'),
    ),
    PaneItem(
      key: const ValueKey('/log'),
      icon: const Icon(FluentIcons.bug_24_regular),
      title: const Text('Log'),
      body: const LogPage(),
      onTap: () => Navigator.of(context!).pushNamed('/log'),
    ),
    LinkPaneItemAction(
      icon: const Icon(FluentIcons.link_24_regular),
      title: const Text('Source code'),
      link: 'https://github.com/realkalash/fluent_gpt',
      body: const SizedBox.shrink(),
    ),
  ];

  void welcomeScreenEnd() {
    AppCache.isWelcomeShown.value = true;
    // restore title bar because on the [WelcomePage] we hide it
    if (AppCache.hideTitleBar.value == false) {
      windowManager.setTitleBarStyle(TitleBarStyle.normal,
          windowButtonVisibility: false);
    }
    Navigator.of(context!).pushReplacement(
      FluentPageRoute(builder: (context) => const GlobalPage()),
    );
  }

  PageController welcomeScreenPageController = PageController(keepPage: false);
  void initWelcomeScreenController([int indexStartPage = 0]) {
    welcomeScreenPageController =
        PageController(keepPage: false, initialPage: indexStartPage);
  }

  final welcomeScreens = const [
    WelcomePage(),
    WelcomePermissionsPage(),
    WelcomeLLMConfigPage(),
    WelcomeShortcutsHelper()
  ];
  void welcomeScreenNext() {
    if (welcomeScreenPageController.page == welcomeScreens.length - 1) {
      welcomeScreenEnd();
      return;
    }
    welcomeScreenPageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void updateUI() {
    notifyListeners();
  }
}
