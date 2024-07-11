import 'package:chatgpt_windows_flutter_app/common/custom_prompt.dart';
import 'package:chatgpt_windows_flutter_app/overlay_manager.dart';
import 'package:chatgpt_windows_flutter_app/tray.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

import 'pages/home_page.dart';
import 'providers/chat_gpt_provider.dart';
import 'widgets/input_field.dart';

class OverlayUI extends StatefulWidget {
  const OverlayUI({super.key});
  static Size defaultWindowSize = const Size(340, 64);
  static Size superCompactWindowSize = const Size(64, 34);

  @override
  State<OverlayUI> createState() => _OverlayUIState();
}

class _OverlayUIState extends State<OverlayUI> {
  bool isSuperCompact = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      type: MaterialType.transparency,
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
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      OverlayManager.hideOverlay();
                    },
                  ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.align_horizontal_left_rounded),
                  onPressed: () => _toggleSuperCompactMode(),
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
                  onPressed: () => toggleShowChatUI(),
                )),
          if (isShowChatUI == true)
            Positioned(
                left: 0,
                bottom: 24,
                child: IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(FluentIcons.chat_add_20_filled),
                  onPressed: () => onTrayButtonTap('create_new_chat'),
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
                      onPressed: () => OverlayManager.switchToMainWindow(),
                      icon: Image.asset(
                        'assets/transparent_app_icon.png',
                        fit: BoxFit.contain,
                        cacheHeight: 60,
                        cacheWidth: 60,
                      ),
                      tooltip: 'Show App',
                      padding: const EdgeInsets.all(0),
                      constraints: isSuperCompact
                          ? const BoxConstraints(maxHeight: 20, maxWidth: 20)
                          : const BoxConstraints(maxHeight: 36, maxWidth: 36)),
                  if (isSuperCompact == false) ...[
                    ...customPrompts.value
                        .where((element) => element.showInOverlay)
                        .map((prompt) => _buildTextOption(prompt, 'custom')),
                  ]
                ],
              ),
            ),
          ),
        ],
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

  /// Builds a text option button. Size is 30x30
  Widget _buildTextOption(CustomPrompt prompt, String command) {
    final IconData icon = prompt.icon;
    final String text = prompt.title;
    return InkWell(
      onTap: () async {
        // final selectedText =
        //     await overlayChannel.invokeMethod('getSelectedText') as String?;
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
            Expanded(
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
                  onPressed: () {
                    _showSubPrompts(prompt, context);
                  },
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

  void _toggleSuperCompactMode() {
    if (!isSuperCompact) {
      setState(() {
        isSuperCompact = true;
        isShowChatUI = false;
      });
      windowManager.setSize(OverlayUI.superCompactWindowSize, animate: true);
    } else {
      setState(() {
        isSuperCompact = false;
      });
      windowManager.setSize(OverlayUI.defaultWindowSize, animate: true);
    }
  }

  bool isShowChatUI = false;

  Future<void> toggleShowChatUI() async {
    isShowChatUI = !isShowChatUI;
    final currentWidth = isSuperCompact
        ? OverlayUI.superCompactWindowSize.width
        : OverlayUI.defaultWindowSize.width;
    final newHeight = isShowChatUI
        ? 400.0
        : isSuperCompact
            ? OverlayUI.superCompactWindowSize.height
            : OverlayUI.defaultWindowSize.height;

    await windowManager.setSize(Size(currentWidth, newHeight), animate: true);
    setState(() {});
  }

  void _showSubPrompts(CustomPrompt prompt, BuildContext context) {
    if (isShowChatUI == false) {
      toggleShowChatUI();
    }
    fluent.showDialog(
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
