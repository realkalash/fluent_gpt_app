import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/pages/welcome/welcome_llm_screen.dart' show NerdySelectorType;
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/providers/chat_provider_mixins/chat_provider_base_mixin.dart';
import 'package:fluent_ui/fluent_ui.dart';

mixin ChatProviderSettingsMixin on ChangeNotifier, ChatProviderBaseMixin {
  int _messageTextSize = 14;
  bool includeConversationGlobal = true;
  
  @override
  double autoScrollSpeed = 1.0;

  set textSize(int v) {
    _messageTextSize = v;
    AppCache.messageTextSize.set(v);
    notifyListeners();
  }

  int get textSize => _messageTextSize;

  void setAutoScrollSpeed(double v) {
    autoScrollSpeed = v;
    AppCache.autoScrollSpeed.set(v);
    notifyListeners();
  }

  void setMaxTokensForChat(int? v) {
    if (v == null) return;
    selectedChatRoom.maxTokenLength = v;
    notifyListeners();
  }

  void toggleScrollToBottomOnAnswer() {
    scrollToBottomOnAnswer = !scrollToBottomOnAnswer;
  }

  void setIncludeWholeConversation(bool v) {
    includeConversationGlobal = v;
    notifyListeners();
  }

  void setNerdySelectorType(NerdySelectorType e) {
    AppCache.nerdySelectorType.value = e.index;
    switch (e) {
      case NerdySelectorType.newbie:
        AppCache.hideEditSystemPromptInHomePage.value = true;
        AppCache.includeTimeToSystemPrompt.value = true;
        AppCache.includeUserNameToSysPrompt.value = true;
        if (AppCache.userCityName.value?.trim().isNotEmpty == true) {
          AppCache.includeUserCityNamePrompt.value = true;
        }
        break;
      case NerdySelectorType.advanced:
      case NerdySelectorType.developer:
        AppCache.hideEditSystemPromptInHomePage.value = false;
        break;
    }
    notifyListeners();
  }

  // Required dependencies from ScrollingMixin
  bool get scrollToBottomOnAnswer;
  set scrollToBottomOnAnswer(bool value);
}

