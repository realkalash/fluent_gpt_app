import 'dart:math';

import 'package:fluent_gpt/common/custom_prompt.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/pages/new_settings_page.dart';
import 'package:fluent_gpt/theme.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/subjects.dart';
import 'package:widget_and_text_animator/widget_and_text_animator.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/chat_provider.dart';
import '../widgets/input_field.dart';
import '../widgets/message_list_tile.dart';

class OverlayUI extends StatefulWidget {
  const OverlayUI({super.key});
  static const _maxWidth = 6 * (50 + 8 + 8);

  /// stream to trigger changing chat ui
  static BehaviorSubject<bool> isChatVisible =
      BehaviorSubject<bool>.seeded(false);

  static Size defaultWindowSize() {
    var elementsLength = 5;
    if (AppCache.overlayVisibleElements.value != -1) {
      elementsLength = AppCache.overlayVisibleElements.value!;
    } else {
      elementsLength = customPrompts.value
          .where(
            (element) => element.showInOverlay,
          )
          .length;
    }

    // each element width is 50 + padding 8 + main button 36. Max 6 elements
    // we need to choose minimal width for the window
    final width = elementsLength * (50 + 8 + 8 + 6);
    final minWidth = min(width, _maxWidth).toDouble();
    return Size(minWidth, 64);
  }

  static Size superCompactWindowSize = const Size(64, 34);

  @override
  State<OverlayUI> createState() => _OverlayUIState();
}

class _OverlayUIState extends State<OverlayUI> {
  bool isSuperCompact = false;

  @override
  void initState() {
    super.initState();
    OverlayUI.isChatVisible.listen((value) {
      toggleShowChatUI();
    });
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = context.read<AppTheme>();
    final backgroundColor = appTheme.isDark
        ? appTheme.darkBackgroundColor
        : appTheme.lightBackgroundColor;
    return StreamBuilder(
        stream: OverlayUI.isChatVisible,
        builder: (context, snapshot) {
          return GestureDetector(
            onPanStart: (v) => WindowManager.instance.startDragging(),
            child: Material(
              color: Colors.transparent,
              type: MaterialType.transparency,
              child: Container(
                color: backgroundColor,
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    if (isShowChatUI)
                      const Positioned.fill(
                        top: 64,
                        child: ChatPageOverlayUI(),
                      ),
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (isSuperCompact == false)
                            const IconButton(
                              visualDensity: VisualDensity.compact,
                              icon: Icon(Icons.close),
                              onPressed: OverlayManager.hideOverlay,
                            ),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            icon:
                                const Icon(Icons.align_horizontal_left_rounded),
                            onPressed: _toggleSuperCompactMode,
                          )
                        ],
                      ),
                    ),
                    if (isSuperCompact == false)
                      Positioned(
                          left: 0,
                          bottom: 0,
                          child: IconButton(
                            visualDensity: VisualDensity.compact,
                            icon: isShowChatUI
                                ? const Icon(Icons.arrow_circle_up_rounded)
                                : const Icon(Icons.arrow_circle_down_rounded),
                            onPressed: () => toggleChatVisibilityStream(),
                          )),
                    Positioned(
                      top: isSuperCompact ? 7.0 : 0,
                      left: 4.0,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            IconButton.filled(
                                visualDensity: isSuperCompact
                                    ? VisualDensity.compact
                                    : VisualDensity.standard,
                                onPressed: () =>
                                    OverlayManager.switchToMainWindow(),
                                icon: Image.asset(
                                  'assets/transparent_app_icon.png',
                                  fit: BoxFit.contain,
                                  cacheHeight: 60,
                                  cacheWidth: 60,
                                ),
                                tooltip: 'Show App',
                                padding: const EdgeInsets.all(0),
                                constraints: isSuperCompact
                                    ? const BoxConstraints(
                                        maxHeight: 20, maxWidth: 20)
                                    : const BoxConstraints(
                                        maxHeight: 36, maxWidth: 36)),
                            if (isSuperCompact == false) ...[
                              ...customPrompts.value
                                  .where((element) => element.showInOverlay)
                                  .map((prompt) =>
                                      _buildTextOption(prompt, 'custom')),
                            ],
                            if (AppCache.showSettingsInOverlay.value == true &&
                                isSuperCompact == false)
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                icon:
                                    const Icon(FluentIcons.settings_28_filled),
                                onPressed: () async {
                                  await OverlayManager.switchToMainWindow();
                                  // ignore: use_build_context_synchronously
                                  Navigator.of(navigatorKey.currentContext!)
                                      .push(
                                    fluent.FluentPageRoute(
                                        builder: (context) =>
                                            const NewSettingsPage()),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
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
      toggleShowChatUI();
    }
    onTrayButtonTapCommand(selectedText, command);
  }

  /// Builds a text option button. Size is 30x30
  Widget _buildTextOption(CustomPrompt prompt, String command) {
    final IconData icon = fluent.IconData(
      prompt.iconCodePoint,
      fontFamily: CustomPrompt.fontFamily,
      fontPackage: CustomPrompt.fontPackage,
    );
    final String text = prompt.title;
    return InkWell(
      onTap: () async {
        // final selectedText =
        //     await NativeChannelUtils.getSelectedText();
        final clipboard = await Clipboard.getData('text/plain');
        final selectedText = clipboard?.text;
        if (selectedText != null && selectedText.trim().isNotEmpty) {
          _onButtonTap(prompt.getPromptText(selectedText), command);
        }
      },
      child: SizedBox.square(
        dimension: 50,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 28),
                  SizedBox(
                    width: 30,
                    child: Text(
                      text.split(' ').first,
                      style: const TextStyle(fontSize: 8),
                      overflow: TextOverflow.fade,
                      maxLines: 1,
                      softWrap: false,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
            if (prompt.children.isNotEmpty)
              Positioned(
                top: 0,
                right: 0,
                child: IconButton(
                  onPressed: () => _showSubPrompts(prompt, context),
                  icon: const Icon(FluentIcons.caret_down_16_filled),
                  constraints:
                      const BoxConstraints(maxWidth: 24, maxHeight: 24),
                  padding: const EdgeInsets.all(0),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleSuperCompactMode() async {
    final currentPosition = await windowManager.getPosition();
    final defaultWindowSize = OverlayUI.defaultWindowSize();
    final defaultWidth = defaultWindowSize.width;
    if (!isSuperCompact) {
      setState(() {
        OverlayUI.isChatVisible.add(false);
        isSuperCompact = true;
      });
      await windowManager.setSize(OverlayUI.superCompactWindowSize,
          animate: true);
      // Delays because of window animations
      await Future.delayed(const Duration(milliseconds: 250));
      // Move position a little to the left to create effect aligning from the right to the left
      // 64 is the width of the super compact window
      await windowManager.setPosition(
        Offset(currentPosition.dx + defaultWidth - 64, currentPosition.dy),
        animate: true,
      );
    } else {
      setState(() {
        isSuperCompact = false;
      });
      await windowManager.setSize(defaultWindowSize, animate: true);
      await Future.delayed(const Duration(milliseconds: 250));
      await windowManager.setPosition(
        Offset(currentPosition.dx - defaultWidth + 64, currentPosition.dy),
        animate: true,
      );
    }
    await Future.delayed(const Duration(milliseconds: 300));
    await OverlayManager.checkAndRepositionOverOffsetWindow();
  }

  void toggleChatVisibilityStream() {
    OverlayUI.isChatVisible.value == false
        ? OverlayUI.isChatVisible.add(true)
        : OverlayUI.isChatVisible.add(false);
  }

  bool get isShowChatUI => OverlayUI.isChatVisible.value;

  Future<void> toggleShowChatUI() async {
    final windowSize = await windowManager.getSize();
    final defaultWindowSize = OverlayUI.defaultWindowSize();
    final resolutionStr = AppCache.resolution.value ?? '500x700';
    final resolutionHeight = double.parse(resolutionStr.split('x')[1]);
    final currentWidth = isSuperCompact
        ? OverlayUI.superCompactWindowSize.width
        : defaultWindowSize.width;
    final newHeight = isShowChatUI
        ? 400.0
        : isSuperCompact
            ? OverlayUI.superCompactWindowSize.height
            : defaultWindowSize.height;

    await windowManager.setSize(Size(currentWidth, newHeight), animate: true);
    await Future.delayed(const Duration(milliseconds: 250));
    // if the window is near bottom we should make effect of moving the window down when chat is being closed (and up when it opens to avoid overflow)
    final currentPosition = await windowManager.getPosition();
    if (isShowChatUI) {
      // we don't need to do it because checkAndRepositionOverOffsetWindow will handle overflow and mov the window up
    } else {
      // if near bottom we should move the window down
      if (currentPosition.dy >= resolutionHeight - windowSize.height) {
        await windowManager.setPosition(
            Offset(currentPosition.dx, currentPosition.dy + 350),
            animate: true);
      }
    }
    await Future.delayed(const Duration(milliseconds: 300));
    await OverlayManager.checkAndRepositionOverOffsetWindow();
  }

  void _showSubPrompts(CustomPrompt prompt, BuildContext context) {
    if (isShowChatUI == false) {
      toggleChatVisibilityStream();
    }
    fluent.showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return fluent.ContentDialog(
          title: Row(
            children: [
              Text(prompt.title),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(FluentIcons.dismiss_24_filled),
                color: Colors.red,
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var child in prompt.children)
                fluent.ListTile(
                  title: Text(child.title),
                  onPressed: () async {
                    final clipboard = await Clipboard.getData('text/plain');
                    final selectedText = clipboard?.text;
                    if (selectedText != null &&
                        selectedText.trim().isNotEmpty) {
                      _onButtonTap(child.getPromptText(selectedText), 'custom');
                      // ignore: use_build_context_synchronously
                      Navigator.of(context).pop();
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
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
                  final reverseList = messagesReversedList;
                  if (reverseList.isEmpty) {
                    final randWelcome = OverlayManager.welcomesForEmptyList[
                        Random().nextInt(OverlayManager.welcomesForEmptyList.length)];
                    return Center(
                      child: TextAnimator(
                        randWelcome,
                        initialDelay: Duration(milliseconds: 200),
                        style: TextStyle(fontSize: 30),
                        textAlign: TextAlign.center,
                      ),
                    );
                  }

                  return ListView.builder(
                    itemCount: reverseList.length,
                    controller: _scrollController,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: true,
                    reverse: true,
                    itemBuilder: (context, index) {
                      final message = reverseList[index];

                      return MessageCard(
                        message: message,
                        selectionMode: false,
                        textSize: AppCache.compactMessageTextSize.value!,
                        isCompactMode: true,
                      );
                    },
                  );
                }),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 20),
            child: SizedBox(
              height: 86,
              child: InputField(isMini: true),
            ),
          ),
        ],
      ),
    );
  }
}
