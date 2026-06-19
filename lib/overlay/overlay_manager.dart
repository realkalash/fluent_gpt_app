import 'dart:convert';
import 'dart:io';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/common/prompts_templates.dart';
import 'package:fluent_gpt/features/notification_service.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/native_channels.dart';
import 'package:fluent_gpt/overlay/region_chat_overlay_ui.dart';
import 'package:fluent_gpt/overlay/search_overlay_ui.dart';
import 'package:fluent_gpt/overlay/sidebar_overlay_ui.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:fluent_gpt/widgets/input_field/input_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:rxdart/rxdart.dart';
import 'package:screen_retriever/screen_retriever.dart';
import 'package:window_manager/window_manager.dart';

import '../common/custom_prompt.dart';
import 'overlay_ui.dart';

BehaviorSubject<OverlayStatus> overlayVisibility = BehaviorSubject<OverlayStatus>.seeded(const OverlayStatus());

BehaviorSubject<List<CustomPrompt>> customPrompts = BehaviorSubject.seeded([...basePromptsTemplate]);
BehaviorSubject<List<CustomPrompt>> archivedPrompts = BehaviorSubject.seeded([...baseArchivedPromptsTemplate]);

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

  /// Compact chat opened from a screen-region snip (Cmd+Shift+drag on macOS).
  final bool isShowingRegionChatOverlay;

  /// Fullscreen frozen-frame "AI Lens" (Cmd+Shift+6 on macOS).
  final bool isShowingLensOverlay;
  const OverlayStatus({
    this.isShowingOverlay = false,
    this.isShowingSidebarOverlay = false,
    this.isShowingSearchOverlay = false,
    this.isShowingRegionChatOverlay = false,
    this.isShowingLensOverlay = false,
  });

  bool get isEnabled =>
      isShowingOverlay ||
      isShowingSidebarOverlay ||
      isShowingSearchOverlay ||
      isShowingRegionChatOverlay ||
      isShowingLensOverlay;

  static const OverlayStatus enabled = OverlayStatus(isShowingOverlay: true);
  static const OverlayStatus disabled = OverlayStatus(isShowingOverlay: false);
  static const OverlayStatus sidebarEnabled = OverlayStatus(isShowingSidebarOverlay: true);
  static const OverlayStatus sidebarDisabled = OverlayStatus(isShowingSidebarOverlay: false);
  static const OverlayStatus searchEnabled = OverlayStatus(isShowingSearchOverlay: true);
  static const OverlayStatus regionChatEnabled = OverlayStatus(isShowingRegionChatOverlay: true);
  static const OverlayStatus lensEnabled = OverlayStatus(isShowingLensOverlay: true);

  //equality
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is OverlayStatus &&
        other.isShowingOverlay == isShowingOverlay &&
        other.isShowingSidebarOverlay == isShowingSidebarOverlay &&
        other.isShowingSearchOverlay == isShowingSearchOverlay &&
        other.isShowingRegionChatOverlay == isShowingRegionChatOverlay &&
        other.isShowingLensOverlay == isShowingLensOverlay;
  }

  @override
  int get hashCode =>
      isShowingOverlay.hashCode ^
      isShowingSidebarOverlay.hashCode ^
      isShowingSearchOverlay.hashCode ^
      isShowingRegionChatOverlay.hashCode ^
      isShowingLensOverlay.hashCode;
}

/// A frozen capture of the display under the cursor, used by the fullscreen
/// AI Lens. All geometry is in the captured display's own space: [cursorX]/
/// [cursorY] are top-left-origin points within the display; [pxWidth]/[pxHeight]
/// are the image's pixel dimensions; [pointWidth]/[pointHeight] are the display
/// size in points; [scale] is the backing scale factor (px = point * scale).
class LensCapture {
  final Uint8List imageBytes;
  final int pxWidth;
  final int pxHeight;
  final double pointWidth;
  final double pointHeight;
  final double scale;
  final double cursorX;
  final double cursorY;

  /// The captured display's global top-left origin, in points (primary display
  /// top-left = 0,0). Add to a display-local point to get a global one.
  final double originX;
  final double originY;
  final RegionCaptureContext context;

  const LensCapture({
    required this.imageBytes,
    required this.pxWidth,
    required this.pxHeight,
    required this.pointWidth,
    required this.pointHeight,
    required this.scale,
    required this.cursorX,
    required this.cursorY,
    this.originX = 0,
    this.originY = 0,
    required this.context,
  });
}

/// The active fullscreen-lens capture, or null when the lens is closed.
BehaviorSubject<LensCapture?> lensCapture = BehaviorSubject<LensCapture?>.seeded(null);

/// Metadata captured alongside a screen-region snip: the app/window that was
/// frontmost *before* our overlay grabbed focus. Surfaced in [RegionChatOverlayUI]
/// and prepended to the outgoing message so the model knows the visual context.
class RegionCaptureContext {
  final String? appName;
  final String? bundleId;
  final String? windowTitle;
  const RegionCaptureContext({this.appName, this.bundleId, this.windowTitle});

  bool get hasContext => (appName?.isNotEmpty == true) || (windowTitle?.isNotEmpty == true);

  /// Short human-readable label, e.g. `Firefox — "(2) YouTube"`.
  String get label {
    final parts = <String>[];
    if (appName?.isNotEmpty == true) parts.add(appName!);
    if (windowTitle?.isNotEmpty == true) parts.add('"$windowTitle"');
    return parts.join(' — ');
  }

  /// Line prepended to the user's message so the LLM has the source context.
  String get promptPrefix => hasContext ? 'Captured from: $label' : '';
}

/// Most recent region-snip context. `null` until the first snip of a session.
BehaviorSubject<RegionCaptureContext?> regionCaptureContext = BehaviorSubject<RegionCaptureContext?>.seeded(null);

class OverlayManager {
  static Future<void> init() async {
    final customPromptsJson = await AppCache.quickPrompts.value();
    if (customPromptsJson.isNotEmpty) {
      final customPromptsList = jsonDecode(customPromptsJson) as List<dynamic>;
      final customPromptsListDecoded = customPromptsList.map((e) => CustomPrompt.fromJson(e)).toList();
      customPrompts.add(customPromptsListDecoded);
      bindHotkeys(customPromptsListDecoded);
    }
    final archivedPromptsJson = AppCache.archivedPrompts.value;
    if (archivedPromptsJson != null && archivedPromptsJson.isNotEmpty) {
      final archivedPromptsList = jsonDecode(archivedPromptsJson) as List;
      final archivedPromptsListDecoded = archivedPromptsList.map((e) => CustomPrompt.fromJson(e)).toList();
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
    if (overlayVisibility.value.isShowingOverlay || AppCache.enableOverlay.value == false) {
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
    if (overlayVisibility.value.isShowingSidebarOverlay || AppCache.enableOverlay.value == false) {
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
    await windowManager.setSize(
        haveMessages ? SearchOverlayUI.defaultWindowSize() + const Offset(0, 470) : SearchOverlayUI.defaultWindowSize());
    overlayVisibility.add(OverlayStatus.searchEnabled);
    Size windowSize = await windowManager.getSize();
    Offset position = await calcWindowPosition(windowSize, Alignment.topCenter);
    await Future.delayed(const Duration(milliseconds: 100));
    await windowManager.setPosition(position + const Offset(0, 200), animate: false);
  }

  /// Opens the compact region-snip chat near the cursor. [positionX]/[positionY]
  /// are the cursor-release point in CG (top-left origin) points, which maps
  /// directly onto window_manager's top-left logical coordinate space on macOS.
  static Future<void> showRegionChatOverlay({double? positionX, double? positionY}) async {
    overlayVisibility.add(OverlayStatus.regionChatEnabled);
    await windowManager.setAlwaysOnTop(true);
    final size = RegionChatOverlayUI.defaultWindowSize();
    await windowManager.setMinimumSize(size);
    await windowManager.setSize(size, animate: false);
    await windowManager.setResizable(false);
    // The app is usually hidden while the user is working in another app.
    await windowManager.show(inactive: false);
    if (positionX != null && positionY != null) {
      // Nudge down-right of the cursor so the window doesn't cover the selection.
      double x = positionX + 12;
      double y = positionY + 12;
      if (x < 0) x = 0;
      if (y < 0) y = 0;
      await windowManager.setPosition(Offset(x, y), animate: false);
      await checkAndRepositionOverOffsetWindow();
    }
  }

  /// Shows the fullscreen frozen-frame AI Lens for [capture]. The native side
  /// expands + raises the window to cover the display under the cursor.
  /// Pre-warm step: reveal the fullscreen lens window IMMEDIATELY (with no
  /// capture yet, so it shows a dark "entering" backdrop). This wakes the
  /// Flutter engine — which macOS pauses while the window is hidden — so it can
  /// resume rendering in parallel with the (native) screenshot capture.
  static Future<void> beginLensOverlay() async {
    lensCapture.add(null);
    overlayVisibility.add(OverlayStatus.lensEnabled);
    await windowManager.setAlwaysOnTop(true);
    await NativeChannelUtils.enterLensMode(); // reveals + resizes + raises
    await windowManager.focus();
  }

  /// Completes the lens: hands over the captured frame so the frozen image +
  /// ripple appear. Pairs with [beginLensOverlay].
  static void completeLensOverlay(LensCapture capture) {
    lensCapture.add(capture);
  }

  /// Closes the lens: restores the window geometry/level, resets overlay state,
  /// and (by default) hides the window so the user returns to their work.
  static Future<void> hideLensOverlay({bool hideWindow = true}) async {
    // Order matters: hide the window FIRST (while it still shows the lens
    // frame), then restore geometry + swap the Flutter content. Doing it the
    // other way round briefly shows the restored-size main chat page on screen
    // before the hide lands — a visible "blink" of the main window on Esc.
    if (hideWindow) {
      await windowManager.hide();
    }
    await NativeChannelUtils.exitLensMode();
    overlayVisibility.add(OverlayStatus.disabled);
    lensCapture.add(null);
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

    // Get cached position and validate it
    final cachedX = AppCache.windowX.value!.toDouble();
    final cachedY = AppCache.windowY.value!.toDouble();
    final windowWidth = AppCache.windowWidth.value?.toDouble() ?? 600.0;
    final windowHeight = AppCache.windowHeight.value?.toDouble() ?? 700.0;

    // Get screen size for validation using screen_retriever
    late Size resolutionSize;
    try {
      final _primaryDisplay = await screenRetriever.getPrimaryDisplay();
      final primaryDisplaySize = _primaryDisplay.visibleSize;
      if (primaryDisplaySize != null) {
        resolutionSize = Size(primaryDisplaySize.width, primaryDisplaySize.height);
      } else {
        // Fallback to cached resolution
        final resolutionString = AppCache.resolution.value ?? '1920x1080';
        final resList = resolutionString.split('x');
        resolutionSize = Size(double.parse(resList[0]), double.parse(resList[1]));
      }
    } catch (e) {
      // Fallback to cached resolution on error
      final resolutionString = AppCache.resolution.value ?? '1920x1080';
      final resList = resolutionString.split('x');
      resolutionSize = Size(double.parse(resList[0]), double.parse(resList[1]));
    }

    // Validate and adjust cached position if necessary
    double validatedX = cachedX;
    double validatedY = cachedY;

    // Only adjust if the cached position would put window off-screen
    if (cachedX < 0) {
      validatedX = 10; // Small margin from left edge
    } else if (cachedX + windowWidth > resolutionSize.width) {
      validatedX = resolutionSize.width - windowWidth - 10; // Small margin from right edge
    }

    if (cachedY < 0) {
      validatedY = 0;
    } else if (cachedY + windowHeight > resolutionSize.height) {
      validatedY = resolutionSize.height - windowHeight;
    }

    log('Switching to main window at validated position: ($validatedX, $validatedY), cached was: ($cachedX, $cachedY) - Screen: ${resolutionSize.width}x${resolutionSize.height}');

    await windowManager.setPosition(
      Offset(validatedX, validatedY),
      animate: true,
    );
    // delay due to macos bug. We can't do it simultaneously
    if (Platform.isMacOS) await Future.delayed(const Duration(milliseconds: 300));
    await windowManager.setSize(
      Size(windowWidth, windowHeight),
      animate: true,
    );
    await Future.delayed(const Duration(milliseconds: 400));

    // Only call repositioning check if we used the original cached values
    // If we already validated and adjusted, no need for further repositioning
    if (validatedX == cachedX && validatedY == cachedY) {
      await OverlayManager.checkAndRepositionOverOffsetWindow();
    }
  }

  static Future<void> checkAndRepositionOverOffsetWindow() async {
    try {
      final currentPosition = await windowManager.getPosition();
      final windowSize = await windowManager.getSize();

      // Clamp against the display that actually contains the window, not always
      // the primary one — otherwise a window opened on a secondary monitor (e.g.
      // from a snip/lens there) is treated as "off-screen" and yanked back to
      // the primary display.
      final bounds = await _displayBoundsContaining(currentPosition, windowSize);

      double newX = currentPosition.dx;
      double newY = currentPosition.dy;
      bool needsRepositioning = false;

      if (newX < bounds.left) {
        newX = bounds.left;
        needsRepositioning = true;
      } else if (newX + windowSize.width > bounds.right) {
        newX = bounds.right - windowSize.width;
        needsRepositioning = true;
      }

      if (newY < bounds.top) {
        newY = bounds.top;
        needsRepositioning = true;
      } else if (newY + windowSize.height > bounds.bottom) {
        newY = bounds.bottom - windowSize.height;
        needsRepositioning = true;
      }

      if (needsRepositioning) {
        log('Repositioning window from (${currentPosition.dx}, ${currentPosition.dy}) to ($newX, $newY) - Display bounds: $bounds');
        await windowManager.setPosition(Offset(newX, newY), animate: true);
      }
    } catch (e) {
      logError('Error repositioning window: $e');
    }
  }

  /// Visible bounds (global, logical px) of the display that contains [point]
  /// (using the window's centre for a stable choice). Falls back to the primary
  /// display, then to the cached resolution at origin.
  static Future<Rect> _displayBoundsContaining(Offset point, Size windowSize) async {
    Rect boundsOf(Display d) {
      final origin = d.visiblePosition ?? Offset.zero;
      final size = d.visibleSize ?? d.size;
      return origin & size;
    }

    final centre = point + Offset(windowSize.width / 2, windowSize.height / 2);
    try {
      final displays = await screenRetriever.getAllDisplays();
      if (displays.isNotEmpty) {
        for (final d in displays) {
          if (boundsOf(d).contains(centre)) return boundsOf(d);
        }
        // Centre isn't on any display (fully off-screen) — use the primary.
        final primary = await screenRetriever.getPrimaryDisplay();
        return boundsOf(primary);
      }
    } catch (_) {
      // Fall through to the cached-resolution fallback below.
    }

    final resolutionString = AppCache.resolution.value ?? '1920x1080';
    final resList = resolutionString.split('x');
    if (resList.length == 2) {
      return Offset.zero & Size(double.parse(resList[0]), double.parse(resList[1]));
    }
    return Offset.zero & const Size(1920, 1080);
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
        final previousClipboard = (await Clipboard.getData(Clipboard.kTextPlain))?.text;

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
            final Offset? mouseCoord = await NativeChannelUtils.getMousePosition();
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

        data['status'] = prompt.silentHideWindowsAfterRun ? 'silent' : 'visible';
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
