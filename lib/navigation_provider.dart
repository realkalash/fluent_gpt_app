import 'package:fluent_gpt/common/prefs/app_cache.dart';

import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/pages/welcome/welcome_shortcuts_helper_screen.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;

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

  void welcomeScreenEnd() {
    AppCache.isWelcomeShown.value = true;
    // restore title bar because on the [WelcomePage] we hide it
    // if (AppCache.hideTitleBar.value == false) {
    //   windowManager.setTitleBarStyle(
    //     TitleBarStyle.normal,
    //     windowButtonVisibility: false,
    //   );
    // }
    Navigator.of(context!).pushReplacement(
      FluentPageRoute(builder: (context) => const GlobalPage()),
    );
  }

  PageController welcomeScreenPageController = PageController(keepPage: false);
  void initWelcomeScreenController([int indexStartPage = 0]) {
    welcomeScreenPageController = PageController(keepPage: false, initialPage: indexStartPage);
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
