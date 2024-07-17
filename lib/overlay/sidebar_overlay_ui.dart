import 'dart:math';

import 'package:fluent_gpt/common/custom_prompt.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/chat_gpt_provider.dart';
import '../widgets/input_field.dart';
import '../widgets/message_list_tile.dart';

class SidebarOverlayUI extends StatefulWidget {
  const SidebarOverlayUI({super.key});
  // each element width is 50 + padding 8 + main button 36. Max 6 elements
  // we need to choose minimal width for the window
  static const double _maxCompactHeight = 6 * (36 + 8 + 8);
  static const double _maxChatHeight = 10 * (36 + 8 + 8);
  static Offset previousCompactOffset = Offset.zero;

  static Size defaultWindowSize() {
    final elementsLength = customPrompts.value.length;
    final height = elementsLength * (30 + 8 + 8);
    final minHeight = min(height, _maxCompactHeight).toDouble();
    return Size(48, minHeight);
  }

  @override
  State<SidebarOverlayUI> createState() => _OverlayUIState();
}

class _OverlayUIState extends State<SidebarOverlayUI> {
  @override
  Widget build(BuildContext context) {
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
              if (isShowChatUI) const Expanded(child: ChatPageOverlayUI()),
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 4),
                  Flexible(
                    fit: FlexFit.loose,
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          InkWell(
                            onTap: OverlayManager.switchToMainWindow,
                            child: Container(
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle, color: Colors.blue),
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
                                  _buildTextOption(prompt, 'custom'))
                        ],
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
                          icon: const Icon(FluentIcons.chat_add_20_filled),
                          onPressed: () => onTrayButtonTap('create_new_chat'),
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
                        onPressed: () => toggleShowChatUI(),
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
  }

  void _onButtonTap(String selectedText, String command) {
    const urlScheme = 'fluentgpt';

    final uri = Uri(
        scheme: urlScheme,
        path: '///',
        queryParameters: {'command': command, 'text': selectedText});
    if (isShowChatUI == false) toggleShowChatUI();
    onTrayButtonTap(uri.toString());
  }

  /// Builds a text option button. Size is 40x30
  Widget _buildTextOption(CustomPrompt prompt, String command) {
    final IconData icon = prompt.icon;
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
      print('Error repositioning window: $e');
    }
  }

  bool isShowChatUI = false;
  Future<void> toggleShowChatUI() async {
    isShowChatUI = !isShowChatUI;
    final defaultWindowSize = SidebarOverlayUI.defaultWindowSize();
    final currentHeight = defaultWindowSize.height;
    final newHeight =
        isShowChatUI ? SidebarOverlayUI._maxChatHeight : currentHeight;
    final newWidth = isShowChatUI ? 500.0 : defaultWindowSize.width;
    if (isShowChatUI) {
      SidebarOverlayUI.previousCompactOffset =
          await windowManager.getPosition();
    }

    await windowManager.setSize(Size(newWidth, newHeight), animate: true);
    setState(() {});
    await Future.delayed(const Duration(milliseconds: 200));
    if (isShowChatUI == false) {
      await windowManager.setPosition(SidebarOverlayUI.previousCompactOffset,
          animate: true);
    }
    await Future.delayed(const Duration(milliseconds: 200));
    await checkAndRepositionOverOffsetWindow();
  }

  Future<void> _showSubPrompts(
      CustomPrompt prompt, BuildContext context) async {
    if (isShowChatUI == false) {
      toggleShowChatUI();
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
                tileColor: fluent.ButtonState.all(Colors.red.withOpacity(0.4)),
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
      toggleShowChatUI();
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
                stream: chatRoomsStream,
                builder: (context, snapshot) {
                  return ListView.builder(
                    itemCount: messages.length,
                    controller: _scrollController,
                    reverse: false,
                    itemBuilder: (context, index) {
                      final message = messages.entries.elementAt(index).value;
                      final dateTimeRaw =
                          messages.entries.elementAt(index).value['created'];
                      return MessageCard(
                        id: messages.entries.elementAt(index).key,
                        message: message,
                        dateTime: DateTime.tryParse(dateTimeRaw ?? ''),
                        selectionMode: false,
                        isError: message['error'] == 'true',
                        textSize: 10,
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
