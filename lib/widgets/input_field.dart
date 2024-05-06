// import 'package:chat_gpt_flutter/chat_gpt_flutter.dart';
import 'dart:async';

import 'package:chatgpt_windows_flutter_app/common/app_intents.dart';
import 'package:chatgpt_windows_flutter_app/file_utils.dart';
import 'package:chatgpt_windows_flutter_app/pages/home_page.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as ic;
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/chat_gpt_provider.dart';

class InputField extends StatefulWidget {
  const InputField({super.key});

  @override
  State<InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<InputField> {
  void onSubmit(String text, ChatGPTProvider chatProvider) {
    if (text.trim().isEmpty && chatProvider.fileInput == null) {
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

  bool _isShiftPressed = false;
  @override
  Widget build(BuildContext context) {
    final ChatGPTProvider chatProvider = context.watch<ChatGPTProvider>();

    return Actions(
      actions: {
        PasteIntent: pasteAction,
      },
      child: Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          /// CTRL + V should paste image or text from clipboard
          LogicalKeySet(LogicalKeyboardKey.keyV, LogicalKeyboardKey.control):
              PasteIntent(
            onPasteText: (text) {
              chatProvider.messageController.text =
                  chatProvider.messageController.text + text;
              windowManager.focus();
              promptTextFocusNode.requestFocus();
            },
            onPasteImage: (image) async {
              final convertedPngImage = await image.toPNG();
              chatProvider.addFileToInput(convertedPngImage);
              windowManager.focus();
              promptTextFocusNode.requestFocus();
            },
          ),
        },
        child: KeyboardListener(
          focusNode: _focusNode,
          onKeyEvent: (event) {
            if (event is KeyRepeatEvent) return;
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.shiftLeft) {
              setState(() {
                _isShiftPressed = true;
              });
            }
            if (event is KeyDownEvent &&
                event.logicalKey == LogicalKeyboardKey.enter) {
              if (_isShiftPressed == false) {
                onSubmit(chatProvider.messageController.text, chatProvider);
              }
              setState(() {
                _isShiftPressed = false;
              });
            }
            if (event is KeyUpEvent &&
                event.logicalKey == LogicalKeyboardKey.shiftLeft) {
              setState(() {
                _isShiftPressed = false;
              });
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                if (chatProvider.fileInput == null)
                  SizedBox.square(
                    dimension: 48,
                    child: IconButton(
                      onPressed: () async {
                        /// if we don't have oneDrive api yet, show the dialog
                        // if (prefs?.getString('oneDriveRedirectURL') == null ||
                        //     prefs?.getString('oneDriveClientID') == null) {
                        //   _showOneDriveDialog(context);
                        //   return;
                        // }
                        FilePickerResult? result =
                            await FilePicker.platform.pickFiles();
                        if (result != null && result.files.isNotEmpty) {
                          chatProvider
                              .addFileToInput(result.files.first.toXFile());
                          windowManager.focus();
                          promptTextFocusNode.requestFocus();
                        }
                      },
                      icon: chatProvider.isSendingFile
                          ? const ProgressRing()
                          : const Icon(ic.FluentIcons.attach_24_filled,
                              size: 24),
                    ),
                  ),
                if (chatProvider.fileInput != null)
                  SizedBox.square(
                    dimension: 48,
                    child: Stack(
                      children: [
                        IconButton(
                          onPressed: () async {
                            if (chatProvider.isSendingFile) {
                              return;
                            }
                            FilePickerResult? result =
                                await FilePicker.platform.pickFiles();
                            if (result != null && result.files.isNotEmpty) {
                              chatProvider
                                  .addFileToInput(result.files.first.toXFile());
                              windowManager.focus();
                              promptTextFocusNode.requestFocus();
                            }
                          },
                          icon: const Icon(
                              ic.FluentIcons.document_number_1_16_regular,
                              size: 24),
                        ),
                        if (chatProvider.fileInput!.mimeType
                                ?.contains('image') ==
                            true)
                          Positioned.fill(
                            bottom: 0,
                            right: 0,
                            child: FutureBuilder<Uint8List>(
                                future: chatProvider.fileInput!.readAsBytes(),
                                builder: (context, snapshot) {
                                  if (snapshot.data == null) {
                                    return const SizedBox.shrink();
                                  }
                                  return ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: Image.memory(
                                      snapshot.data as Uint8List,
                                      fit: BoxFit.cover,
                                    ),
                                  );
                                }),
                          ),
                        if (chatProvider.isSendingFile)
                          const Positioned.fill(
                            child: Center(child: ProgressRing()),
                          ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton(
                            style: ButtonStyle(
                              backgroundColor: ButtonState.all(
                                  Colors.black.withOpacity(0.5)),
                            ),
                            onPressed: () => chatProvider.removeFileFromInput(),
                            icon: Icon(FluentIcons.chrome_close,
                                size: 12, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: TextBox(
                    autofocus: true,
                    autocorrect: true,
                    focusNode: promptTextFocusNode,
                    prefix: (chatProvider.selectedChatRoom.commandPrefix ==
                                null ||
                            chatProvider.selectedChatRoom.commandPrefix == '')
                        ? null
                        : Tooltip(
                            message:
                                chatProvider.selectedChatRoom.commandPrefix,
                            child: const Card(
                                margin: EdgeInsets.all(4),
                                padding: EdgeInsets.all(4),
                                child: Text('SMART')),
                          ),
                    prefixMode: OverlayVisibilityMode.always,
                    controller: chatProvider.messageController,
                    minLines: 2,
                    maxLines: 30,
                    textInputAction: TextInputAction.newline,
                    onSubmitted: (value) {
                      // do nothing
                    },
                    placeholder: 'Type your message here',
                  ),
                ),
                if (_isShiftPressed)
                  const Icon(ic.FluentIcons.arrow_down_12_filled),
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
                  SizedBox.square(
                    dimension: 48,
                    child: IconButton(
                      onPressed: () => onSubmit(
                          chatProvider.messageController.text, chatProvider),
                      icon: const Icon(ic.FluentIcons.send_24_filled, size: 24),
                    ),
                  ),
              ],
            ),
          ),
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
    final chatProvider = context.read<ChatGPTProvider>();
    final txtController = chatProvider.messageController;

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
            if (textFromClipboard.trim().isNotEmpty)
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
                  chatProvider.sendMessage('Explain: "${txtController.text}"');
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
                  chatProvider.sendCheckGrammar(txtController.text);
                }),
            Button(
                child: const Text('Translate to English'),
                onPressed: () {
                  chatProvider.sendMessage(
                      'Translate to English: "${txtController.text}"');
                }),
            Button(
                child: const Text('Translate to Rus'),
                onPressed: () {
                  chatProvider
                      .sendMessage('Translate to Rus: "${txtController.text}"');
                }),
            Button(
                child: const Text('Answer with tags'),
                onPressed: () {
                  HotShurtcutsWidget.showAnswerWithTagsDialog(
                      context, txtController.text);
                }),
          ],
        ),
      ),
    );
  }
}
