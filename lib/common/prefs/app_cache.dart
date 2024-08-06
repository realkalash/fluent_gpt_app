import 'package:fluent_gpt/common/prefs/prefs_types.dart';
import 'package:flutter/gestures.dart';

class AppCache {
  static const currentFileIndex = IntPref("currentFileIndex");
  // ${resolution.width}x${resolution.height}
  static const resolution = StringPref("resolution", '500x700');
  static const preventClose = BoolPref("preventClose");
  static const showAppInDock = BoolPref("showAppInDock", false);
  static const enableOverlay = BoolPref("enableOverlay", false);
  static const alwaysOnTop = BoolPref("alwaysOnTop", false);
  static const hideTitleBar = BoolPref("hideTitleBar", false);
  static const isMarkdownViewEnabled = BoolPref("isMarkdownView", true);
  static const overlayVisibleElements = IntPref("overlayVisibleElements");
  static const messageTextSize = IntPref("messageTextSize", 14);
  static const compactMessageTextSize = IntPref("compactMessageTextSize", 10);
  static const showSettingsInOverlay = BoolPref("showSettingsInOverlay", true);

  /// related to the very first welcome screen
  static const isWelcomeShown = BoolPref("isWelcomeShown", false);
  static const isFoldersAccessGranted =
      BoolPref("isFoldersAccessGranted", false);
  static const isMicAccessGranted = BoolPref("isMicAccessGranted", false);

  static const openWindowKey = StringPref("openWindowKey");

  static const windowX = IntPref("windowX");
  static const windowY = IntPref("windowY");
  static const previousCompactOffset =
      OffsetPref("previousCompactOffset", Offset.zero);
  static const windowWidth = IntPref("windowWidth");
  static const windowHeight = IntPref("windowHeight");
  static const selectedChatRoomId = StringPref("selectedChatRoomName");
  static const llmUrl = StringPref("llmUrl");
  static const tokensUsedTotal = IntPref("tokensUsedTotal");
  static const costTotal = DoublePref("costTotal");

  static const customPrompts = FileStringPref("customPrompts");
  static const archivedPrompts = StringPref("archivedPrompts");

  static const gptToolSearchEnabled = BoolPref("gptToolSearchEnabled", true);
  static const gptToolPythonEnabled = BoolPref("gptToolPythonEnabled", true);
  static const gptToolCopyToClipboardEnabled =
      BoolPref("copyToClipboardEnabled", true);
}
