// import 'package:chat_gpt_flutter/chat_gpt_flutter.dart';
import 'dart:async';

import 'package:chatgpt_windows_flutter_app/pages/home_page.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as ic;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../providers/chat_gpt_provider.dart';

class InputField extends StatefulWidget {
  const InputField({super.key});

  @override
  State<InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<InputField> {
  void onSubmit(String text, ChatGPTProvider chatProvider) {
    if (text.trim().isEmpty) {
      return;
    }
    chatProvider.sendMessage(text.trim());
    Future.delayed(const Duration(milliseconds: 50)).then(
      (value) {
        chatProvider.messageController.clear();
        promptTextFocusNode.requestFocus();
      },
    );
  }

  bool _shiftPressed = false;
  int wordCountInField = 0;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    final chatProvider = context.read<ChatGPTProvider>();
    chatProvider.messageController.addListener(() {
      final text = chatProvider.messageController.text;
      if (text.contains(' ')) {
        wordCountInField = text.trim().split(' ').length;
      } else {
        wordCountInField = 0;
      }
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final ChatGPTProvider chatProvider = context.watch<ChatGPTProvider>();

    return RawKeyboardListener(
      focusNode: _focusNode,
      onKey: (RawKeyEvent event) {
        if (event is RawKeyDownEvent) {
          if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
              event.logicalKey == LogicalKeyboardKey.shiftRight) {
            _shiftPressed = true;
          } else if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter) {
            if (!_shiftPressed) {
              // Enter pressed without shift, send message
              // print('Enter pressed');
              onSubmit(chatProvider.messageController.text, chatProvider);
            }
          }
        } else if (event is RawKeyUpEvent) {
          if (event.logicalKey == LogicalKeyboardKey.shiftLeft ||
              event.logicalKey == LogicalKeyboardKey.shiftRight) {
            _shiftPressed = false;
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
              child: TextBox(
                focusNode: promptTextFocusNode,
                prefix: (chatProvider.selectedChatRoom.commandPrefix == null ||
                        chatProvider.selectedChatRoom.commandPrefix == '')
                    ? null
                    : Tooltip(
                        message: chatProvider.selectedChatRoom.commandPrefix,
                        child: const Card(
                            margin: EdgeInsets.all(4),
                            padding: EdgeInsets.all(4),
                            child: Text('SMART')),
                      ),
                prefixMode: OverlayVisibilityMode.always,
                controller: chatProvider.messageController,
                minLines: 2,
                maxLines: 30,
                placeholder: 'Type your message here',
              ),
            ),
            if (wordCountInField != 0)
              Text(
                '$wordCountInField words',
                style: FluentTheme.of(context).typography.caption,
              ),
            if (chatProvider.isAnswering)
              IconButton(
                icon: const Icon(ic.FluentIcons.stop_16_filled),
                onPressed: () {
                  chatProvider.stopAnswering();
                },
              )
            else
              Button(
                onPressed: () =>
                    onSubmit(chatProvider.messageController.text, chatProvider),
                child: const Text('Send'),
              ),
          ],
        ),
      ),
    );
  }
}

class HotShurtcutsWidget extends StatefulWidget {
  const HotShurtcutsWidget({super.key});

  static void showAnswerWithTagsDialog(BuildContext context, String text) {
    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('Answer with tags'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                children: [
                  const Text('Your message:'),
                  Card(child: Text(text)),
                ],
              ),
            ),
            const Text('Quick Tags:'),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Button(
                    onPressed: () => answerWithTags(ctx, text, 'Yes'),
                    child: const Text('Answer Yes'),
                  ),
                  Button(
                    onPressed: () => answerWithTags(ctx, text, 'No'),
                    child: const Text('Answer No'),
                  ),
                  Button(
                    onPressed: () =>
                        answerWithTags(ctx, text, 'Explain please'),
                    child: const Text('Answer Explain please'),
                  ),
                ],
              ),
            ),
            TextBox(
              autofocus: true,
              placeholder: 'Type your tags here (e.g. yes, no, explain)',
              onSubmitted: (value) {
                if (value.trim().isEmpty) {
                  return;
                }
                answerWithTags(ctx, text, value);
              },
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () {
              Navigator.of(ctx).pop();
            },
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  static void answerWithTags(BuildContext context, String text, String tags) {
    final chatProvider = context.read<ChatGPTProvider>();
    final formattedText = text.trim();
    final formattedTags = tags.trim();
    chatProvider.sendMessage(
      'Based on the text message: "$formattedText" '
      'and within the context defined by these tags: '
      '"$formattedTags", '
      'please provide an answer like you a real human.',
      false,
    );
    Navigator.of(context).pop();
  }

  @override
  State<HotShurtcutsWidget> createState() => _HotShurtcutsWidgetState();
}

class _HotShurtcutsWidgetState extends State<HotShurtcutsWidget> {
  Timer? timer;
  String textFromClipboard = '';

  @override
  void initState() {
    super.initState();

    /// periodically checks the clipboard for text and displays a widget if there is text
    /// in the clipboard
    timer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
      Clipboard.getData(Clipboard.kTextPlain).then((value) {
        if (value?.text != textFromClipboard) {
          textFromClipboard = value?.text ?? '';
          if (mounted) setState(() {});
        }
      });
    });
  }

  @override
  void dispose() {
    super.dispose();
    timer?.cancel();
  }

  @override
  Widget build(BuildContext context) {
    if (textFromClipboard.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final chatProvider = context.read<ChatGPTProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          /// align to the left start
          alignment: WrapAlignment.start,
          spacing: 4,
          runSpacing: 4,
          children: [
            Tooltip(
              message: 'Paste:\n$textFromClipboard',
              child: Container(
                constraints: const BoxConstraints(maxWidth: 200),
                child: Button(
                  style: ButtonStyle(
                      backgroundColor: ButtonState.all(Colors.blue)),
                  onPressed: () {
                    chatProvider.sendMessage(textFromClipboard);
                  },
                  child: Text(
                    textFromClipboard.replaceAll('\n', '').trim(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
            Button(
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(ic.FluentIcons.info_16_regular, size: 16),
                    Text('Explain'),
                  ],
                ),
                onPressed: () {
                  chatProvider.sendMessage('Explain: "$textFromClipboard"');
                }),
            Button(
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(ic.FluentIcons.book_16_regular, size: 16),
                    Text('Check grammar'),
                  ],
                ),
                onPressed: () {
                  chatProvider.sendCheckGrammar(textFromClipboard.trim());
                }),
            Button(
                child: const Text('Translate to English'),
                onPressed: () {
                  chatProvider.sendMessage(
                      'Translate to English: "$textFromClipboard"');
                }),
            Button(
                child: const Text('Translate to Rus'),
                onPressed: () {
                  chatProvider
                      .sendMessage('Translate to Rus: "$textFromClipboard"');
                }),
            Button(
                child: const Text('Answer with tags'),
                onPressed: () {
                  HotShurtcutsWidget.showAnswerWithTagsDialog(
                      context, textFromClipboard);
                }),
          ],
        ),
      ),
    );
  }
}
