import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/common/prompts_templates.dart';
import 'package:fluent_gpt/features/notification_service.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/native_channels.dart';
import 'package:fluent_gpt/overlay/search_overlay_ui.dart';
import 'package:fluent_gpt/overlay/sidebar_overlay_ui.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:fluent_gpt/widgets/input_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:rxdart/rxdart.dart';
import 'package:window_manager/window_manager.dart';

import '../common/custom_prompt.dart';
import 'overlay_ui.dart';

BehaviorSubject<OverlayStatus> overlayVisibility =
    BehaviorSubject<OverlayStatus>.seeded(OverlayStatus());

BehaviorSubject<List<CustomPrompt>> customPrompts =
    BehaviorSubject.seeded([...basePromptsTemplate]);
BehaviorSubject<List<CustomPrompt>> archivedPrompts =
    BehaviorSubject.seeded([...baseArchivedPromptsTemplate]);

int calcAllPromptsForChild(CustomPrompt prompt) {
  int count = 1;
  for (var child in prompt.children) {
    count += calcAllPromptsForChild(child);
  }
  return count;
}

int calcAllPromptsLenght() {
  final archivedList = archivedPrompts.value.toList();
  final customList = customPrompts.value.toList();
  int count = 0;
  for (var prompt in customList) {
    count += calcAllPromptsForChild(prompt);
  }
  for (var prompt in archivedList) {
    count += calcAllPromptsForChild(prompt);
  }
  return count;
}

class OverlayStatus {
  final bool isShowingOverlay;
  final bool isShowingSidebarOverlay;
  final bool isShowingSearchOverlay;
  const OverlayStatus({
    this.isShowingOverlay = false,
    this.isShowingSidebarOverlay = false,
    this.isShowingSearchOverlay = false,
  });

  bool get isEnabled =>
      isShowingOverlay || isShowingSidebarOverlay || isShowingSearchOverlay;

  static const OverlayStatus enabled = OverlayStatus(isShowingOverlay: true);
  static const OverlayStatus disabled = OverlayStatus(isShowingOverlay: false);
  static const OverlayStatus sidebarEnabled =
      OverlayStatus(isShowingSidebarOverlay: true);
  static const OverlayStatus sidebarDisabled =
      OverlayStatus(isShowingSidebarOverlay: false);
  static const OverlayStatus searchEnabled =
      OverlayStatus(isShowingSearchOverlay: true);


  //equality
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is OverlayStatus &&
        other.isShowingOverlay == isShowingOverlay &&
        other.isShowingSidebarOverlay == isShowingSidebarOverlay &&
        other.isShowingSearchOverlay == isShowingSearchOverlay;
  }

  @override
  int get hashCode =>
      isShowingOverlay.hashCode ^
      isShowingSidebarOverlay.hashCode ^
      isShowingSearchOverlay.hashCode;
}

class OverlayManager {
  static Future<void> init() async {
    final customPromptsJson = await AppCache.quickPrompts.value();
    if (customPromptsJson.isNotEmpty) {
      final customPromptsList = jsonDecode(customPromptsJson) as List<dynamic>;
      final customPromptsListDecoded =
          customPromptsList.map((e) => CustomPrompt.fromJson(e)).toList();
      customPrompts.add(customPromptsListDecoded);
      bindHotkeys(customPromptsListDecoded);
    }
    final archivedPromptsJson = AppCache.archivedPrompts.value;
    if (archivedPromptsJson != null && archivedPromptsJson.isNotEmpty) {
      final archivedPromptsList = jsonDecode(archivedPromptsJson) as List;
      final archivedPromptsListDecoded =
          archivedPromptsList.map((e) => CustomPrompt.fromJson(e)).toList();
      archivedPrompts.add(archivedPromptsListDecoded);
    }
    customPrompts.listen((newData) {
      AppCache.quickPrompts.set(
        jsonEncode(newData.map((e) => e.toJson()).toList()),
      );
    });
  }
  
  static const List<String> welcomesForEmptyList = [
    'Ask me anything',
    'What can I do for you?',
    'How can I help you?',
    'What do you need?',
    'Hey {user}',
    '👋 Hi there!',
    '✨ Ready when you are',
    '🤔 Got a question?',
    '💬 Chat with me',
    '🚀 Let\'s get started',
    '💡 Need some ideas?',
    '🔍 Looking for something?',
    '📝 Need help with writing?',
    '👨‍💻 Coding assistance?',
    '🎯 What\'s your goal today?',
    '✌️ At your service',
    '🌈 Let\'s create something',
    '🧠 Pick my brain',
    '🎨 Need creative help?',
    '🛠️ Tool time!',
    '💪 Let\'s solve problems',
    '🌟 What shall we explore?',
    '🔮 Tell me your thoughts',
    '🌱 Growing ideas together',
    '🧩 Puzzle-solving time',
    '⚡ Ready for anything',
    '🎭 How can I assist?',
    '🎬 Action!',
    '📊 Need data analysis?',
    '🚦 Where to next?',
    '🎵 What\'s your tune today?',
    '🧪 Let\'s experiment',
    '📱 App help needed?',
    '🔧 Technical questions?',
    '🌐 Web development?',
    '✏️ Drafting together',
    '👾 Debugging help?',
    '🤝 Let\'s collaborate',
    '📚 Research assistance?',
    '🏗️ Building something?',
    '🧮 Math problems?',
    '💻 Code review needed?',
    '🧵 Threading thoughts...',
    '🔥 What\'s hot on your mind?',
    '🦄 Magical solutions await',
    '🎪 Welcome to the show',
    '🚢 Let\'s navigate together',
    '🧐 Curious minds unite',
    '🌞 Brightening your day',
    '🎁 Got a surprise question?',
    '🔠 Language help needed?',
    '🧗 Tackling challenges',
    '🏆 Aiming for excellence',
    '🎲 Let\'s take a chance',
    '🪄 Working magic here',
    '🔋 Fully charged to help',
    '🌊 Dive into questions',
    '🧘 How can I bring clarity?',
    '🏎️ Speed-solving ready',
    '🔍 Investigating together',
    '👁️ Looking for insights?',
    '🎮 Game development help?',
    '🧬 Complex problem to solve?',
    '📡 Broadcasting assistance',
    '🎯 Targeting solutions',
    '🌎 Global questions welcome',
    '🧠 Brain.exe is running',
    '🎧 I\'m listening...',
    '🌈 Inspiration needed?'
  ];

  static Future<void> showOverlay(
    BuildContext rootContext, {
    double? positionX,
    double? positionY,
  }) async {
    if (overlayVisibility.value.isShowingOverlay ||
        AppCache.enableOverlay.value == false) {
      return;
    }
    overlayVisibility.add(OverlayStatus.enabled);
    await windowManager.setAlwaysOnTop(true);

    final compactOverlaySize = OverlayUI.defaultWindowSize();
    await windowManager.setMinimumSize(compactOverlaySize);
    await windowManager.setSize(compactOverlaySize, animate: true);
    await windowManager.setResizable(false);
    // Ensure the overlay does not go off-screen
    if (positionX != null && positionY != null) {
      // we need to invert Y because the overlay is from the bottom to top
      final resolutionStr = AppCache.resolution.value ?? '500x700';
      final resHeight = double.tryParse(resolutionStr.split('x')[1]) ?? 700;
      positionY = resHeight - positionY;
      if (positionY < 0) {
        positionY = 0;
      }
      // Ensure the overlay does not go off-screen
      if (positionX < 0) {
        positionX = 0;
      }
      // because if chatUI is opening it can try to use previous position, we need to wait until the animation is done
      await Future.delayed(const Duration(milliseconds: 500));
      await windowManager.setPosition(
        Offset((positionX), (positionY)),
        animate: false,
      );
    }
  }

  static Future<void> showSidebarOverlay(
    BuildContext rootContext, {
    double? positionX,
    double? positionY,
    String? command,
  }) async {
    if (overlayVisibility.value.isShowingSidebarOverlay ||
        AppCache.enableOverlay.value == false) {
      return;
    }
    overlayVisibility.add(OverlayStatus.sidebarEnabled);
    await windowManager.setAlwaysOnTop(true);
    final compactOverlaySize = SidebarOverlayUI.defaultWindowSize();
    await windowManager.setMinimumSize(compactOverlaySize);
    await windowManager.setSize(compactOverlaySize, animate: true);
    // wait for the window to be resized
    await Future.delayed(const Duration(milliseconds: 100));
    await windowManager.setResizable(false);
    if (AppCache.previousCompactOffset.value != Offset.zero) {
      await windowManager.setPosition(
        AppCache.previousCompactOffset.value!,
        animate: false,
      );
    } else {
      // Ensure the overlay does not go off-screen
      if (positionX != null && positionY != null) {
        if (positionY < 0) {
          positionY = 0;
        }
        // Ensure the overlay does not go off-screen
        if (positionX < 0) {
          positionX = 0;
        }
        await windowManager.setPosition(
          Offset((positionX) + 16, (positionY) + 16),
          animate: true,
        );
      }
    }
  }

  static Future<void> showSearchOverlay({String? command}) async {
    if (overlayVisibility.value.isShowingSearchOverlay) {
      return;
    }
    promptTextFocusNode.unfocus();
    final haveMessages = messages.valueOrNull?.isNotEmpty == true;
    await windowManager.setAlwaysOnTop(true);
    // final compactOverlaySize = ;
    await windowManager.setMinimumSize(SearchOverlayUI.defaultWindowSize());
    await windowManager.setSize(haveMessages
        ? SearchOverlayUI.defaultWindowSize() + Offset(0, 470)
        : SearchOverlayUI.defaultWindowSize());
    overlayVisibility.add(OverlayStatus.searchEnabled);
    Size windowSize = await windowManager.getSize();
    Offset position = await calcWindowPosition(windowSize, Alignment.topCenter);
    await Future.delayed(Duration(milliseconds: 100));
    await windowManager.setPosition(position + Offset(0, 200), animate: false);
  }

  static Future<void> hideOverlay() async {
    windowManager.setAlwaysOnTop(AppCache.alwaysOnTop.value!);
    await windowManager.setResizable(true);
    await windowManager.setMinimumSize(defaultMinimumWindowSize);
    overlayVisibility.add(OverlayStatus.disabled);
    await windowManager.hide();
  }

  static Future<void> switchToMainWindow() async {
    windowManager.setAlwaysOnTop(AppCache.alwaysOnTop.value!);
    await windowManager.setResizable(true);
    await windowManager.setMinimumSize(defaultMinimumWindowSize);
    overlayVisibility.add(OverlayStatus.disabled);
    final x = AppCache.windowX.value!.toDouble();
    final y = AppCache.windowY.value!.toDouble();
    log('Switching to main window at $x, $y');
    await windowManager.setPosition(
      Offset(x, y),
      animate: true,
    );
    // delay due to macos bug. We can't do it simulteniously
    if (Platform.isMacOS)
      await Future.delayed(const Duration(milliseconds: 300));
    await windowManager.setSize(
      Size(AppCache.windowWidth.value?.toDouble() ?? 600.0,
          AppCache.windowHeight.value?.toDouble() ?? 700.0),
      animate: true,
    );
    await Future.delayed(const Duration(milliseconds: 400));
    await OverlayManager.checkAndRepositionOverOffsetWindow();
  }

  static Future<void> checkAndRepositionOverOffsetWindow() async {
    try {
      final currentPosition = await windowManager.getPosition();
      final windowSize = await windowManager.getSize();

      late Size resolutionSize;
      final screenSizeResult = await NativeChannelUtils.getScreenSize();
      if (screenSizeResult == null && screenSizeResult!['width'] != null) {
        resolutionSize = Size(screenSizeResult['width']!.toDouble(),
            screenSizeResult['height']!.toDouble());
      } else {
        final resolutionString = AppCache.resolution.value ?? '1920x1080';
        final resList = resolutionString.split('x');
        if (resList.length != 2) {
          throw const FormatException('Invalid resolution format');
        }
        resolutionSize =
            Size(double.parse(resList[0]), double.parse(resList[1]));
      }

      // Consider accounting for system UI elements (taskbar height, etc.)
      // Example value, should be determined dynamically
      final safeAreaInset = 0;
      // Not sure why but we should add 60. Otherwise it will go out of screen bounds a little bit
      final safeAreaInsetWidth = 60;

      double newX = currentPosition.dx;
      double newY = currentPosition.dy;

      // Adjust X if out of bounds (keep fully visible when possible)
      if (newX + windowSize.width > resolutionSize.width) {
        newX = resolutionSize.width - windowSize.width + safeAreaInsetWidth;
      }
      newX = max(0, newX);

      // Adjust Y if out of bounds (keep fully visible when possible)
      if (newY + windowSize.height > resolutionSize.height - safeAreaInset) {
        newY = resolutionSize.height - windowSize.height - safeAreaInset;
      }
      newY = max(0, newY);

      if (newX != currentPosition.dx || newY != currentPosition.dy) {
        await windowManager.setPosition(Offset(newX, newY), animate: true);
      }
    } catch (e) {
      logError('Error repositioning window: $e');
    }
  }

  static void bindHotkeys(List<CustomPrompt> customPromptsList) {
    for (var prompt in customPromptsList) {
      if (prompt.hotkey != null) {
        _bindHotkey(prompt, prompt.hotkey!);
      }
    }
  }

  /// On linux hotkey registration is so fast it could trigger
  /// the hotkey 3 times in a row, so we need to lock it
  static bool _isHotKeyRegistering = false;
  static Future<void> _bindHotkey(CustomPrompt prompt, HotKey key) async {
    // each prompt can have multiple children
    for (var child in prompt.children) {
      if (child.hotkey != null) {
        await _bindHotkey(child, child.hotkey!);
      }
    }

    await hotKeyManager.register(
      key,
      keyDownHandler: (hotKey) async {
        if (_isHotKeyRegistering) return;
        _isHotKeyRegistering = true;
        final previousClipboard =
            (await Clipboard.getData(Clipboard.kTextPlain))?.text;

        String? selectedText; //await NativeChannelUtils.getSelectedText();
        // if (prompt.autoCopySelectedText) {
        await simulateCtrlCKeyPress();
        await Future.delayed(const Duration(milliseconds: 50));
        // }
        selectedText = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
        final isAppVisible = await windowManager.isVisible();
        Map<String, String> data = {};

        if (prompt.silentHideWindowsAfterRun == false) {
          /// show app window
          if (!isAppVisible) {
            final Offset? mouseCoord =
                await NativeChannelUtils.getMousePosition();
            // windows can't resize windows at all
            if (!Platform.isLinux) {
              /// show mini overlay
              if (!overlayVisibility.value.isEnabled) {
                await showOverlay(
                  navigatorKey.currentContext!,
                  positionX: mouseCoord?.dx,
                  positionY: mouseCoord?.dy,
                );
              }
            }
          }
          await showWindow();
        } else {
          log('Prompt is silent. Show processing...');

          /// show only Push notification after run
          NotificationService.showNotification(
            prompt.title,
            'Processing',
            id: prompt.getPromptText(selectedText).length.toString(),
          );
        }

        if (!Platform.isLinux) {
          /// if already open show chat UI inside the overlay
          if (overlayVisibility.value.isShowingSidebarOverlay) {
            SidebarOverlayUI.isChatVisible.add(true);
          } else if (overlayVisibility.value.isShowingOverlay) {
            OverlayUI.isChatVisible.add(true);
          }
        }

        if (previousClipboard != null) {
          Clipboard.setData(ClipboardData(text: previousClipboard));
        }

        data['status'] =
            prompt.silentHideWindowsAfterRun ? 'silent' : 'visible';
        data['includeConversation'] = prompt.includeConversation.toString();
        data['includeSystemPrompt'] = prompt.includeSystemPrompt.toString();

        await onTrayButtonTapCommand(
          prompt.getPromptText(selectedText),
          null,
          data.isNotEmpty ? data : null,
        );
        _isHotKeyRegistering = false;
      },
    );
  }
}
