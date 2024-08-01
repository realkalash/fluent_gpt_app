// import 'package:chat_gpt_flutter/chat_gpt_flutter.dart';
import 'dart:async';
import 'dart:io';

import 'package:fluent_gpt/common/chat_room.dart';
import 'package:fluent_gpt/common/custom_prompt.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/pages/home_page.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as ic;
import 'package:flutter/services.dart';
import 'package:pasteboard/pasteboard.dart';
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
    shiftPressedStream.stream.listen((isShiftPressed) {
      _isShiftPressed = isShiftPressed;
      if (mounted) setState(() {});
    });
  }

  void onShortcutPasteText(text) {
    final chatProvider = context.read<ChatGPTProvider>();
    chatProvider.messageController.text =
        chatProvider.messageController.text + text;
    windowManager.focus();
    promptTextFocusNode.requestFocus();
  }

  void onShortcutPasteImage(image) async {
    final chatProvider = context.read<ChatGPTProvider>();
    final convertedPngImage = await image.toPNG();
    chatProvider.addFileToInput(convertedPngImage);
    windowManager.focus();
    promptTextFocusNode.requestFocus();
  }

  Future<void> onShortcutPasteToField() async {
    final text = await Pasteboard.text;
    if (text != null) {
      onShortcutPasteText(text);
    }
    final image = await Pasteboard.image;
    if (image != null) {
      onShortcutPasteImage(image);
    }
  }

  Future<void> onShortcutCopyToThirdParty() async {
    final lastMessage = selectedChatRoom.messages.values.last;
    // final previousClipboard = await Pasteboard.text;
    Pasteboard.writeText(lastMessage['content'] ?? '');
    displayCopiedToClipboard();
    // await windowManager.minimize();
    // // wait for the window to hideasdasd
    // Future.delayed(const Duration(milliseconds: 400));
    // await simulateCtrlVKeyPress();
    // Future.delayed(const Duration(milliseconds: 100));
    // if (previousClipboard != null) Pasteboard.writeText(previousClipboard);
  }

  bool _isShiftPressed = false;
  @override
  Widget build(BuildContext context) {
    final ChatGPTProvider chatProvider = context.watch<ChatGPTProvider>();

    return CallbackShortcuts(
      bindings: {
        if (Platform.isMacOS)
          const SingleActivator(LogicalKeyboardKey.keyV, meta: true):
              onShortcutPasteToField
        else
          const SingleActivator(LogicalKeyboardKey.keyV, control: true):
              onShortcutPasteToField,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true):
            onShortcutCopyToThirdParty,
        const SingleActivator(LogicalKeyboardKey.arrowUp, meta: true): () {
          FocusScope.of(context).previousFocus();
        },
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            // Button(
            //     child: const Text('Search test'),
            //     onPressed: () async {
            //       chatProvider
            //           .sendMessage('Can you search for file named "1.png?');
            //     }),
            if (chatProvider.fileInput == null)
              _AddFileButton(chatProvider: chatProvider),
            if (chatProvider.fileInput != null)
              _FileThumbnail(chatProvider: chatProvider),
            Expanded(
              child: TextBox(
                autofocus: true,
                autocorrect: true,
                focusNode: promptTextFocusNode,
                prefixMode: OverlayVisibilityMode.always,
                controller: chatProvider.messageController,
                minLines: 2,
                maxLines: 30,
                prefix: const _ChooseModelButton(),
                textInputAction: TextInputAction.done,
                onSubmitted: (value) {
                  if (value.trim().isEmpty) {
                    promptTextFocusNode.requestFocus();
                    return;
                  }
                  if (_isShiftPressed == false) {
                    onSubmit(value, chatProvider);
                  }
                  if (_isShiftPressed) {
                    chatProvider.messageController.text =
                        '${chatProvider.messageController.text}\n';
                    // refocus
                    promptTextFocusNode.requestFocus();
                  }
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
    );
  }
}

class _ChooseModelButton extends StatefulWidget {
  const _ChooseModelButton({super.key});

  @override
  State<_ChooseModelButton> createState() => _ChooseModelButtonState();
}

class _ChooseModelButtonState extends State<_ChooseModelButton> {
  Widget getModelIcon(String model) {
    if (model.contains('gpt')) {
      return Image.asset(
        'assets/openai_icon.png',
        fit: BoxFit.contain,
        // width: 24,
        // height: 24,
        // cacheHeight: 24,
        // cacheWidth: 24,
      );
    }
    return const Icon(ic.FluentIcons.chat_24_regular);
  }

  final FlyoutController flyoutController = FlyoutController();

  @override
  Widget build(BuildContext context) {
    return Focus(
      canRequestFocus: false,
      descendantsAreTraversable: false,
      child: StreamBuilder(
          stream: chatRoomsStream,
          builder: (context, snapshot) {
            return FlyoutTarget(
              controller: flyoutController,
              child: Container(
                decoration: BoxDecoration(
                  color: FluentTheme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                width: 30,
                height: 30,
                padding: const EdgeInsets.all(2),
                child: GestureDetector(
                  onTap: () => openFlyout(context),
                  child: SizedBox.square(
                    dimension: 20,
                    child: getModelIcon(selectedModel.model),
                  ),
                ),
              ),
            );
          }),
    );
  }

  void openFlyout(BuildContext context) {
    final provider = context.read<ChatGPTProvider>();
    final models = [...allModels, LocalChatModel()];
    final selectedModel = selectedChatRoom.model;
    flyoutController.showFlyout(builder: (ctx) {
      return MenuFlyout(
        items: models
            .map(
              (e) => MenuFlyoutItem(
                selected: e.model == selectedModel.model,
                trailing: e.model == selectedModel.model
                    ? const Icon(ic.FluentIcons.checkmark_16_filled)
                    : null,
                leading: SizedBox.square(
                    dimension: 24, child: getModelIcon(e.model)),
                text: Text(e.model),
                onPressed: () => provider.selectNewModel(e),
              ),
            )
            .toList(),
      );
    });
  }
}

class _AddFileButton extends StatelessWidget {
  const _AddFileButton({
    super.key,
    required this.chatProvider,
  });

  final ChatGPTProvider chatProvider;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 48,
      child: IconButton(
        onPressed: () async {
          FilePickerResult? result = await FilePicker.platform.pickFiles();
          if (result != null && result.files.isNotEmpty) {
            chatProvider.addFileToInput(result.files.first.toXFile());
            windowManager.focus();
            promptTextFocusNode.requestFocus();
          }
        },
        icon: chatProvider.isSendingFile
            ? const ProgressRing()
            : const Icon(ic.FluentIcons.attach_24_filled, size: 24),
      ),
    );
  }
}

class _FileThumbnail extends StatelessWidget {
  const _FileThumbnail({
    super.key,
    required this.chatProvider,
  });

  final ChatGPTProvider chatProvider;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 48,
      child: Stack(
        children: [
          IconButton(
            onPressed: () async {
              if (chatProvider.isSendingFile) {
                return;
              }
              FilePickerResult? result = await FilePicker.platform.pickFiles();
              if (result != null && result.files.isNotEmpty) {
                chatProvider.addFileToInput(result.files.first.toXFile());
                windowManager.focus();
                promptTextFocusNode.requestFocus();
              }
            },
            icon: const Icon(ic.FluentIcons.document_number_1_16_regular,
                size: 24),
          ),
          if (chatProvider.fileInput!.mimeType?.contains('image') == true)
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
                backgroundColor: WidgetStateProperty.all(Colors.black.withOpacity(0.5)),
              ),
              onPressed: () => chatProvider.removeFileFromInput(),
              icon: Icon(FluentIcons.chrome_close, size: 12, color: Colors.red),
            ),
          ),
        ],
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
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: SizedBox(
        width: double.infinity,
        child: Wrap(
          alignment: WrapAlignment.start,
          spacing: 4,
          runSpacing: 4,
          children: [
            if (textFromClipboard.trim().isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Button(
                  style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.all(Colors.blue)),
                  onPressed: () {
                    chatProvider.sendMessage(textFromClipboard);
                  },
                  child: Text(
                    textFromClipboard.replaceAll('\n', '').trim(),
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    textAlign: TextAlign.start,
                  ),
                ),
              ),
            for (final prompt in customPrompts.value)
              if (prompt.showInChatField) PromptChipWidget(prompt: prompt),
            Button(
                child: const Text('Answer with tags'),
                onPressed: () {
                  final text = txtController.text.trim().isEmpty
                      ? textFromClipboard
                      : txtController.text;
                  HotShurtcutsWidget.showAnswerWithTagsDialog(context, text);
                  txtController.clear();
                }),
          ],
        ),
      ),
    );
  }
}

class PromptChipWidget extends StatelessWidget {
  const PromptChipWidget({
    super.key,
    required this.prompt,
  });

  final CustomPrompt prompt;

  Future<void> _onTap(BuildContext context, CustomPrompt child) async {
    final contr = context.read<ChatGPTProvider>().messageController;

    if (contr.text.trim().isNotEmpty) {
      onTrayButtonTapCommand(child.getPromptText(contr.text));
      contr.clear();
    } else {
      final clipboard = await Clipboard.getData('text/plain');
      final selectedText = clipboard?.text?.trim() ?? '';
      if (selectedText.isNotEmpty) {
        onTrayButtonTapCommand(child.getPromptText(selectedText));
        contr.clear();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Button(
      onPressed: () => _onTap(context, prompt),
      onLongPress: () => _onLongPress(context),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(prompt.icon, size: 18),
          const SizedBox(width: 4),
          Text(prompt.title),
          if (prompt.children.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: DropDownButton(
                items: [
                  for (final child in prompt.children)
                    MenuFlyoutItem(
                      leading: Icon(child.icon),
                      text: Text(child.title),
                      onPressed: () => _onTap(context, child),
                    )
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _onLongPress(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return ContentDialog(
          title: Row(
            children: [
              Text(prompt.title),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(ic.FluentIcons.dismiss_24_filled, color: Colors.red),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var child in prompt.children)
                ListTile(
                  title: Text(child.title),
                  onPressed: () {
                    _onTap(context, child);
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
