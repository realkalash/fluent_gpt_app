import 'dart:io';
import 'dart:math';

import 'package:fluent_gpt/common/custom_prompt.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/pages/settings_page.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:rxdart/subjects.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/chat_provider.dart';
import '../widgets/input_field.dart';
import '../widgets/message_list_tile.dart';

class SidebarOverlayUI extends StatefulWidget {
  const SidebarOverlayUI({super.key});
  // each element height is 50 + padding 8 + main button 36. Max 6 elements
  // we need to choose minimal height for the window
  static const double _maxCompactHeight = 6 * (36 + 8 + 8.5);
  static const double _minChatHeight = 2 * (36 + 8 + 8.5);
  static const double _maxChatHeight = 10 * (36 + 8 + 8.5);

  /// stream to trigger changing chat ui
  static BehaviorSubject<bool> isChatVisible =
      BehaviorSubject<bool>.seeded(false);

  static Size defaultWindowSize() {
    var elementsLength = 5;
    if (AppCache.overlayVisibleElements.value != null) {
      elementsLength = AppCache.overlayVisibleElements.value!;
    } else {
      elementsLength = customPrompts.value
          .where(
            (element) => element.showInOverlay,
          )
          .length;
    }
    if (AppCache.showSettingsInOverlay.value == true) {
      elementsLength++;
    }
    final allHeight = elementsLength * (30 + 8 + 8.5);
    final maxAllowedHeight = min(allHeight, _maxCompactHeight).toDouble();
    final height = max(maxAllowedHeight, _minChatHeight).toDouble();
    if (Platform.isWindows) {
      return Size(64.9, height);
    }
    return Size(48, height);
  }

  @override
  State<SidebarOverlayUI> createState() => _OverlayUIState();
}

class _OverlayUIState extends State<SidebarOverlayUI> {
  @override
  void initState() {
    super.initState();
    SidebarOverlayUI.isChatVisible.listen((value) {
      toggleShowChatUI();
    });
  }

  @override
  Widget build(BuildContext context) {
    return fluent.StreamBuilder<Object>(
        stream: SidebarOverlayUI.isChatVisible,
        builder: (context, snapshot) {
          return GestureDetector(
            onPanStart: (v) => WindowManager.instance.startDragging(),
            child: Material(
              color: Colors.transparent,
              type: MaterialType.transparency,
              child: Container(
                color: Colors.transparent,
                child: fluent.Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isShowChatUI)
                      const Expanded(child: ChatPageOverlayUI()),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 4),
                        Flexible(
                          fit: FlexFit.loose,
                          child: ScrollConfiguration(
                            behavior: const ScrollBehavior()
                                .copyWith(overscroll: false, scrollbars: false),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  InkWell(
                                    onTap: OverlayManager.switchToMainWindow,
                                    child: Container(
                                      decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: Colors.blue),
                                      padding: const EdgeInsets.all(2),
                                      width: 40,
                                      height: 30,
                                      child: Image.asset(
                                        'assets/transparent_app_icon.png',
                                        fit: BoxFit.contain,
                                        cacheHeight: 50,
                                        cacheWidth: 50,
                                      ),
                                    ),
                                  ),
                                  ...customPrompts.value
                                      .where((element) => element.showInOverlay)
                                      .map((prompt) =>
                                          _buildTextOption(prompt, 'custom')),
                                  if (AppCache.showSettingsInOverlay.value ==
                                      true)
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: const Icon(
                                          FluentIcons.settings_28_filled),
                                      onPressed: () async {
                                        await OverlayManager
                                            .switchToMainWindow();
                                        // ignore: use_build_context_synchronously
                                        Navigator.of(
                                                navigatorKey.currentContext!)
                                            .push(
                                          fluent.FluentPageRoute(
                                              builder: (context) =>
                                                  const SettingsPage()),
                                        );
                                      },
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              height: 2,
                              width: 36,
                              decoration: BoxDecoration(
                                color: Colors.blue,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            if (isShowChatUI == true)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon:
                                    const Icon(FluentIcons.chat_add_20_filled),
                                onPressed: () => onTrayButtonTapCommand(
                                    '', 'create_new_chat'),
                              ),
                            IconButton(
                              visualDensity: VisualDensity.compact,
                              color: Colors.blue,
                              icon: Icon(
                                isShowChatUI
                                    ? FluentIcons.panel_left_24_filled
                                    : FluentIcons.panel_left_24_regular,
                                size: 24,
                              ),
                              onPressed: () => toggleChatVisibilityStream(),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        });
  }

  void _onButtonTap(String selectedText, String command) {
    if (isShowChatUI == false) {
      toggleChatVisibilityStream();
    }
    onTrayButtonTapCommand(selectedText, command);
  }

  /// Builds a text option button. Size is 40x30
  Widget _buildTextOption(CustomPrompt prompt, String command) {
    final IconData icon = fluent.IconData(
      prompt.iconCodePoint,
      fontFamily: CustomPrompt.fontFamily,
      fontPackage: CustomPrompt.fontPackage,
    );

    String? hotkeyText;
    if (prompt.hotkey != null) {
      hotkeyText = prompt.hotkey!.hotkeyShortString;
    }
    return InkWell(
      onTap: () async {
        final clipboard = await Clipboard.getData('text/plain');
        final selectedText = clipboard?.text;
        if (selectedText != null && selectedText.trim().isNotEmpty) {
          _onButtonTap(prompt.getPromptText(selectedText), command);
        }
      },
      child: Tooltip(
        message: prompt.title,
        waitDuration: const Duration(milliseconds: 1000),
        excludeFromSemantics: true,
        child: SizedBox(
          width: 50,
          height: 30,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Expanded(
                child: Icon(icon, size: 24),
              ),
              if (prompt.children.isNotEmpty)
                IconButton(
                  onPressed: () => _showSubPrompts(prompt, context),
                  icon: const Icon(FluentIcons.caret_down_16_filled),
                  constraints:
                      const BoxConstraints(maxWidth: 24, maxHeight: 24),
                  padding: const EdgeInsets.all(0),
                )
              else if (hotkeyText != null)
                Text(
                  hotkeyText.replaceAll('+', '\n'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 8,
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future checkAndRepositionOverOffsetWindow() async {
    try {
      final currentPosition = await windowManager.getPosition();
      final windowSize = await windowManager.getSize();
      final resolutionString = AppCache.resolution.value ?? '500x700';
      final resList = resolutionString.split('x');
      if (resList.length != 2) {
        throw const FormatException('Invalid resolution format');
      }
      final resolutionSize =
          Size(double.parse(resList[0]), double.parse(resList[1]));

      double newX = currentPosition.dx;
      double newY = currentPosition.dy;

      // Adjust X if out of bounds
      if (newX + windowSize.width > resolutionSize.width) {
        // 70 is the additional padding for the window by width
        newX = resolutionSize.width - windowSize.width + 70;
      }
      newX = max(0, newX); // Ensure newX is not negative

      // Adjust Y if out of bounds
      if (newY + windowSize.height > resolutionSize.height) {
        // 24 is the additional padding for the window by height
        newY = resolutionSize.height - windowSize.height + 24;
      }
      newY = max(0, newY); // Ensure newY is not negative

      // Reposition only if necessary
      if (newX != currentPosition.dx || newY != currentPosition.dy) {
        await windowManager.setPosition(Offset(newX, newY), animate: true);
      }
    } catch (e) {
      // Handle or log the error
      logError('Error repositioning window: $e');
    }
  }

  void toggleChatVisibilityStream() {
    SidebarOverlayUI.isChatVisible.value == false
        ? SidebarOverlayUI.isChatVisible.add(true)
        : SidebarOverlayUI.isChatVisible.add(false);
  }

  bool get isShowChatUI => SidebarOverlayUI.isChatVisible.value;

  Future<void> toggleShowChatUI() async {
    final defaultWindowSize = SidebarOverlayUI.defaultWindowSize();
    final currentHeight = defaultWindowSize.height;
    final newHeight =
        isShowChatUI ? SidebarOverlayUI._maxChatHeight : currentHeight;
    final newWidth = isShowChatUI ? 500.0 : defaultWindowSize.width;
    if (isShowChatUI) {
      AppCache.previousCompactOffset.value = await windowManager.getPosition();
    }

    await windowManager.setSize(Size(newWidth, newHeight), animate: true);
    await Future.delayed(const Duration(milliseconds: 200));
    if (isShowChatUI == false) {
      await windowManager.setPosition(AppCache.previousCompactOffset.value!,
          animate: true);
    }
    await Future.delayed(const Duration(milliseconds: 200));
    await checkAndRepositionOverOffsetWindow();
  }

  Future<void> _showSubPrompts(
      CustomPrompt prompt, BuildContext context) async {
    if (isShowChatUI == false) {
      toggleChatVisibilityStream();
    }
    final promptText = await fluent.showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return fluent.ContentDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var child in prompt.children)
                fluent.ListTile(
                  title: Text(child.title),
                  trailing: child.hotkey != null
                      ? HotKeyVirtualView(hotKey: child.hotkey!)
                      : null,
                  onPressed: () async {
                    final clipboard = await Clipboard.getData('text/plain');
                    final selectedText = clipboard?.text ?? '';
                    // ignore: use_build_context_synchronously
                    Navigator.of(context)
                        .pop(child.getPromptText(selectedText));
                  },
                ),
              const fluent.Padding(
                padding: EdgeInsets.all(8.0),
                child: fluent.Divider(),
              ),
              fluent.ListTile(
                leading: const Icon(FluentIcons.dismiss_16_filled),
                tileColor:
                    fluent.WidgetStateProperty.all(Colors.red.withOpacity(0.4)),
                title: const Text('CLOSE'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
    if (promptText != null && promptText.trim().isNotEmpty) {
      _onButtonTap(promptText, 'custom');
    } else {
      toggleChatVisibilityStream();
    }
  }
}

class ChatPageOverlayUI extends StatefulWidget {
  const ChatPageOverlayUI({super.key});

  @override
  State<ChatPageOverlayUI> createState() => _ChatPageOverlayUIState();
}

class _ChatPageOverlayUIState extends State<ChatPageOverlayUI> {
  final ScrollController _scrollController = ScrollController();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      chatRoomsStream.listen(
        (event) async {
          await Future.delayed(const Duration(milliseconds: 300));
          if (!mounted) return;
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12.0),
      child: Column(
        children: [
          Expanded(
            child: StreamBuilder(
                stream: messages,
                builder: (context, snapshot) {
                  return ListView.builder(
                    itemCount: messages.value.length,
                    controller: _scrollController,
                    reverse: false,
                    itemBuilder: (context, index) {
                      final element = messages.value.entries.elementAt(index);
                      final message = element.value;

                      return MessageCard(
                        id: element.key,
                        message: message,
                        dateTime: null,
                        selectionMode: false,
                        isError: false,
                        textSize: AppCache.compactMessageTextSize.value!,
                        isCompactMode: true,
                      );
                    },
                  );
                }),
          ),
          const InputField(),
        ],
      ),
    );
  }
}
