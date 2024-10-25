import 'dart:io';

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
  static const frameless = BoolPref("frameless", false);
  static const speechLanguage = StringPref("speechLanguage", 'en');
  static const textToSpeechService = StringPref("textToSpeechService", 'deepgram');
  static const deepgramVoiceModel = StringPref("deepgramVoiceModel", 'aura-asteria-en');
  static const elevenlabsVoiceModelName = StringPref("elevenlabsVoiceModel", '');
  static const elevenlabsModel = StringPref("elevenlabsModel", '');
  static const elevenlabsVoiceModelId = StringPref("elevenlabsVoiceModelId", '');

  static StringPref backgroundEffect =
      StringPref("backgroundEffect", Platform.isLinux ? 'disabled' : 'acrylic');

  /// related to the very first welcome screen
  static const isWelcomeShown = BoolPref("isWelcomeShown", false);
  static const isStorageAccessGranted =
      BoolPref("isFoldersAccessGranted", false);
  static const isMicAccessGranted = BoolPref("isMicAccessGranted", false);

  static const openWindowKey = StringPref("openWindowKey");
  static const takeScreenshotKey = StringPref("takeScreenshotKey");

  static const windowX = IntPref("windowX");
  static const windowY = IntPref("windowY");
  static const previousCompactOffset =
      OffsetPref("previousCompactOffset", Offset.zero);
  static const windowWidth = IntPref("windowWidth");
  static const windowHeight = IntPref("windowHeight");
  static const autoScrollSpeed = DoublePref("autoScrollSpeed", 1.0);
  static const selectedChatRoomId = StringPref("selectedChatRoomName");

  static const globalSystemPrompt = StringPref("globalSystemPrompt", '');

  static const tokensUsedTotal = IntPref("tokensUsedTotal");
  static const costTotal = DoublePref("costTotal");

  /// Contains custom prompts for the buttons in the chat
  static const customPrompts = FileStringPref("fluent_gpt/customPrompts.json");

  /// Contains all the prompts from the library like system messages, helpers etc.
  static const promptsLibrary = FileStringPref("fluent_gpt/promptsLibrary.json");
  static const customActions = FileStringPref("fluent_gpt/customActions.json");
  static const savedModels = FileStringPref("fluent_gpt/savedModels.json");
  static const userInfo = FileStringPref("fluent_gpt/userInfo.json");
  static const userName = StringPref("userName", 'User');
  static const archivedPrompts = StringPref("archivedPrompts");

  static const localApiModelPaths = StringPref("localApiModels", '{}');
  static const braveSearchApiKey = StringPref("braveSearchApiKey", '');
  static const imgurClientId = StringPref("imgurClientId", '');
  static const deepgramApiKey = StringPref("deepgramApiKey", '');
  static const elevenLabsApiKey = StringPref("elevenLabsApiKey", '');

  static const gptToolCopyToClipboardEnabled =
      BoolPref("copyToClipboardEnabled", true);
  static const useSecondRequestForNamingChats =
      BoolPref("useSecondRequestForNamingChats", false);
  static const scrapOnlyDecription = BoolPref("scrapOnlyDecription", true);
  static const includeUserNameToSysPrompt =
      BoolPref("includeUserNameToSysPrompt", false);
  static const includeSysInfoToSysPrompt =
      BoolPref("includeSysInfoToSysPrompt", false);
  static const includeKnowledgeAboutUserToSysPrompt =
      BoolPref("includeKnowledgeAboutUserToSysPrompt", false);
  static const learnAboutUserAfterCreateNewChat =
      BoolPref("learnAboutUserAfterCreateNewChat", false);

  static const useGoogleApi = BoolPref("useGoogleApi", false);
  static const useImgurApi = BoolPref("useImgurApi", false);
  static const useSouceNao = BoolPref("useSouceNao", false);
  static const useYandexImageSearch = BoolPref("useYandexImageSearch", false);
}
