import 'package:chatgpt_windows_flutter_app/native_channels.dart';
import 'package:chatgpt_windows_flutter_app/overlay_manager.dart';
import 'package:chatgpt_windows_flutter_app/tray.dart';
import 'package:flutter/material.dart';
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
              bottom: 64,
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
                      ? const Icon(Icons.arrow_circle_down_rounded)
                      : const Icon(Icons.arrow_circle_up_rounded),
                  onPressed: () => toggleShowChatUI(),
                )),
          Positioned(
            left: 4.0,
            bottom: isSuperCompact ? 0.0 : 12.0,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: 4,
              children: [
                IconButton.filled(
                  visualDensity: isSuperCompact
                      ? VisualDensity.compact
                      : VisualDensity.standard,
                  onPressed: () => OverlayManager.switchToMainWindow(),
                  icon: SizedBox.square(
                    dimension: isSuperCompact ? 16 : 24,
                    child: Image.asset(
                      'assets/transparent_app_icon.png',
                      fit: BoxFit.contain,
                      cacheHeight: 60,
                      cacheWidth: 60,
                    ),
                  ),
                  tooltip: 'Show App',
                ),
                if (isSuperCompact == false) ...[
                  _buildTextOption(
                      Icons.lightbulb_outline, 'Explain this', 'explain'),
                  _buildTextOption(Icons.translate, 'Translate', 'to_rus'),
                  _buildTextOption(
                      Icons.summarize, 'Summarize', 'summarize_markdown_short'),
                  _buildTextOption(
                      Icons.edit, 'Improve writing', 'impove_writing'),
                  _buildTextOption(
                      Icons.spellcheck, 'Fix spelling & grammar', 'grammar'),
                  _buildTextOption(Icons.question_answer,
                      'Answer this question', 'answer_with_tags'),
                ]
              ],
            ),
          ),
        ],
      ),
    );
  }

  _onButtonTap(String selectedText, String command) {
    const urlScheme = 'fluentgpt';

    final uri = Uri(
        scheme: urlScheme,
        path: '///',
        queryParameters: {'command': command, 'text': selectedText});
    if (isShowChatUI == false) toggleShowChatUI();
    onTrayButtonTap(uri.toString());
  }

  Widget _buildTextOption(IconData icon, String text, String command) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(
          onPressed: () async {
            final selectedText =
                await overlayChannel.invokeMethod('getSelectedText') as String?;
            if (selectedText != null && selectedText.trim().isNotEmpty) {
              _onButtonTap(selectedText, command);
            }
          },
          icon: Icon(icon, size: 22),
          tooltip: text,
        ),
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
    );
  }

  void _toggleSuperCompactMode() {
    if (!isSuperCompact) {
      setState(() {
        isSuperCompact = true;
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
    return Column(
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
    );
  }
}
