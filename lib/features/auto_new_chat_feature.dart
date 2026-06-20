import 'dart:async';

import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:provider/provider.dart';

/// Automatically creates a fresh empty chat after a configurable period of
/// inactivity.
///
/// "Inactivity" means no new messages were sent or received. Whenever there is
/// chat activity, [notifyActivity] restarts the countdown. When the timer fires
/// and the currently selected chat is not empty, a new chat room is created so
/// the user returns to a clean slate.
class AutoNewChatFeature {
  static Timer? timer;

  /// Starts the inactivity timer if the feature is enabled in settings.
  /// Safe to call multiple times — it restarts the timer.
  static void init() {
    stop();
    if (AppCache.autoNewChatOnInactivity.value == true) {
      start();
    }
  }

  static void start() {
    final minutes = AppCache.autoNewChatInactivityMinutes.value ?? 30;
    if (minutes <= 0) return;
    stop();
    timer = Timer(Duration(minutes: minutes), _onInactivityReached);
  }

  /// Restarts the countdown. Call on any chat activity (message sent/received).
  static void notifyActivity() {
    if (AppCache.autoNewChatOnInactivity.value == true) {
      start();
    }
  }

  static void stop() {
    if (timer?.isActive == true) {
      timer?.cancel();
    }
    timer = null;
  }

  static Future<void> _onInactivityReached() async {
    if (AppCache.autoNewChatOnInactivity.value != true) return;
    // The current chat is already empty — wait for the next activity to restart.
    if (messages.value.isEmpty) return;

    final context = appContext;
    if (context == null) return;
    final chatProvider = context.read<ChatProvider>();
    // Don't interrupt an in-progress answer; check again after another window.
    if (chatProvider.isAnswering) {
      start();
      return;
    }
    log('Auto-creating new chat after $autoNewChatInactivityLabel of inactivity');
    await chatProvider.createNewChatRoom();
  }

  static String get autoNewChatInactivityLabel =>
      '${AppCache.autoNewChatInactivityMinutes.value ?? 30} min';
}
