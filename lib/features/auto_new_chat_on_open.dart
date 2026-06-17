import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:provider/provider.dart';

/// Start a fresh chat when the main window is opened after this much idle time.
const kAutoNewChatAfterIdle = Duration(minutes: 5);

class AutoNewChatOnOpen {
  static void recordAppHidden() {
    AppCache.lastAppHiddenAtMs.value = DateTime.now().millisecondsSinceEpoch;
    log('App hidden at ${AppCache.lastAppHiddenAtMs.value}');
  }

  static Future<void> maybeCreateNewChatAfterIdle({ChatProvider? chatProvider}) async {
    if (AppCache.isWelcomeShown.value != true) return;

    final lastHiddenMs = AppCache.lastAppHiddenAtMs.value;
    if (lastHiddenMs == null) return;

    final idle = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(lastHiddenMs));
    AppCache.lastAppHiddenAtMs.value = null;

    if (idle < kAutoNewChatAfterIdle) {
      log('App opened after ${idle.inSeconds}s idle — keeping current chat');
      return;
    }

    final provider = chatProvider ?? appContext?.read<ChatProvider>();
    if (provider == null) return;

    log('Auto-creating new chat after ${idle.inMinutes} min idle');
    await provider.createNewChatRoom();
  }
}
