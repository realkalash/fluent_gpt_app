// import 'package:chat_gpt_flutter/chat_gpt_flutter.dart';
import 'dart:async';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:fluent_gpt/common/custom_prompt.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/overlay/sidebar_overlay_ui.dart';
import 'package:fluent_gpt/pages/home_page.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as ic;
import 'package:flutter/services.dart';
import 'package:glowy_borders/glowy_borders.dart';
import 'package:langchain/langchain.dart';
import 'package:pasteboard/pasteboard.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../providers/chat_provider.dart';

class InputField extends StatefulWidget {
  const InputField({super.key});

  @override
  State<InputField> createState() => _InputFieldState();
}

class _InputFieldState extends State<InputField> {
  void onSubmit(String text, ChatProvider chatProvider) {
    if (text.trim().isEmpty && chatProvider.fileInput == null) {
      return;
    }
    chatProvider.sendMessage(text.trim());
    clearFieldAndFocus();
  }

  void clearFieldAndFocus() {
    final chatProvider = context.read<ChatProvider>();
    Future.delayed(const Duration(milliseconds: 50)).then(
      (value) {
        chatProvider.messageController.clear();
        promptTextFocusNode.requestFocus();
      },
    );
  }

  @override
  void initState() {
    super.initState();
    shiftPressedStream.stream.listen((isShiftPressed) {
      _isShiftPressed = isShiftPressed;
      if (mounted) setState(() {});
    });
  }

  void onShortcutPasteText(String text) {
    final chatProvider = context.read<ChatProvider>();
    final currentCursorPosition =
        chatProvider.messageController.selection.base.offset;
    final currentText = chatProvider.messageController.text;
    final newText = currentText.substring(0, currentCursorPosition) +
        text +
        currentText.substring(currentCursorPosition);
    chatProvider.messageController.text = newText;
    windowManager.focus();
    promptTextFocusNode.requestFocus();
    // place the cursor at the end of the pasted text
    chatProvider.messageController.selection =
        TextSelection.collapsed(offset: currentCursorPosition + text.length);
  }

  void onShortcutPasteImage(image) async {
    final chatProvider = context.read<ChatProvider>();
    if (image is Uint8List) {
      chatProvider.addFileToInput(
        XFile.fromData(
          image,
          name: 'image.png',
          mimeType: 'image/png',
          length: image.length,
        ),
      );
    } else {
      final convertedPngImage = await image.toPNG();
      chatProvider.addFileToInput(convertedPngImage);
    }
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
    final lastMessage = messages.value.values.last;
    // final previousClipboard = await Pasteboard.text;
    Pasteboard.writeText(lastMessage.contentAsString);
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
    final ChatProvider chatProvider = context.watch<ChatProvider>();

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
                    promptTextFocusNode.requestFocus();
                  }
                },
                placeholder: 'Type your message here',
              ),
            ),
            const SizedBox(width: 4),
            if (_isShiftPressed)
              const Icon(ic.FluentIcons.arrow_down_12_filled),
            const SizedBox(width: 4),
            if (chatProvider.isAnswering)
              SizedBox.square(
                dimension: 52,
                child: AnimatedGradientBorder(
                  borderRadius: BorderRadius.circular(5),
                  gradientColors: [
                    Colors.red,
                    Colors.orange,
                    Colors.yellow,
                    Colors.green,
                    Colors.blue,
                  ],
                  glowSize: 2,
                  animationTime: 5,
                  child: IconButton(
                    style: ButtonStyle(
                        backgroundColor: WidgetStatePropertyAll(
                      context.theme.scaffoldBackgroundColor,
                    )),
                    onPressed: () {
                      // chatProvider.stopAnswering();
                    },
                    icon: const ProgressRing(),
                  ),
                ),
              )
            else
              FlyoutTarget(
                controller: menuController,
                child: SizedBox.square(
                  dimension: 44,
                  child: GestureDetector(
                    onSecondaryTap: _onSecondaryTap,
                    child: Button(
                      onPressed: () => onSubmit(
                        chatProvider.messageController.text,
                        chatProvider,
                      ),
                      child:
                          const Icon(ic.FluentIcons.send_24_filled, size: 24),
                    ),
                  ),
                ),
              ),
            const SizedBox(width: 10),
          ],
        ),
      ),
    );
  }

  final menuController = FlyoutController();

  void _onSecondaryTap() {
    final provider = context.read<ChatProvider>();
    final controller = provider.messageController;
    menuController.showFlyout(builder: (ctx) {
      return MenuFlyout(
        items: [
          MenuFlyoutItem(
              text: const Text('Send as assistant (silently)'),
              onPressed: () {
                provider.addMessageSystem(controller.text);
                clearFieldAndFocus();
              }),
          MenuFlyoutItem(
              text: const Text('Send as user (silently)'),
              onPressed: () {
                provider.addHumanMessageToList(HumanChatMessage(
                    content: ChatMessageContent.text(controller.text)));
                clearFieldAndFocus();
              }),
          MenuFlyoutItem(
              text: const Text('Send as AI answer (silently)'),
              onPressed: () {
                provider.addBotMessageToList(
                    AIChatMessage(content: controller.text),
                    DateTime.now().toIso8601String());
                clearFieldAndFocus();
              }),
        ],
      );
    });
  }
}

class _ChooseModelButton extends StatefulWidget {
  const _ChooseModelButton({super.key});

  @override
  State<_ChooseModelButton> createState() => _ChooseModelButtonState();
}

class _ChooseModelButtonState extends State<_ChooseModelButton> {
  Widget getModelIcon(String ownedBy) {
    if (ownedBy == 'openai') {
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
    // ignore: unused_local_variable
    final provider = context.watch<ChatProvider>();
    return Focus(
      canRequestFocus: false,
      descendantsAreTraversable: false,
      child: FlyoutTarget(
        controller: flyoutController,
        child: Container(
          decoration: BoxDecoration(
            color: FluentTheme.of(context).cardColor,
            borderRadius: BorderRadius.circular(4),
          ),
          width: 30,
          height: 30,
          margin: const EdgeInsets.only(left: 8),
          padding: const EdgeInsets.all(2),
          child: GestureDetector(
            onTap: () => openFlyout(context),
            child: SizedBox.square(
              dimension: 20,
              child: getModelIcon(selectedModel.ownedBy ?? ''),
            ),
          ),
        ),
      ),
    );
  }

  void openFlyout(BuildContext context) {
    final provider = context.read<ChatProvider>();
    final models = allModels.value;
    final selectedModel = selectedChatRoom.model;
    flyoutController.showFlyout(builder: (ctx) {
      return MenuFlyout(
        items: models
            .map(
              (e) => MenuFlyoutItem(
                selected: e.name == selectedModel.name,
                trailing: e.name == selectedModel.name
                    ? const Icon(ic.FluentIcons.checkmark_16_filled)
                    : null,
                leading: SizedBox.square(
                    dimension: 24, child: getModelIcon(e.ownedBy ?? '')),
                text: Text(e.name),
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

  final ChatProvider chatProvider;

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

  final ChatProvider chatProvider;

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
          // if (chatProvider.isSendingFile)
          //   const Positioned.fill(
          //     child: Center(child: ProgressRing()),
          //   ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              style: ButtonStyle(
                backgroundColor:
                    WidgetStateProperty.all(Colors.black.withOpacity(0.5)),
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
    final chatProvider = context.read<ChatProvider>();
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
  // Timer? timer;
  // String textFromClipboard = '';

  // @override
  // void initState() {
  //   super.initState();

  //   /// periodically checks the clipboard for text and displays a widget if there is text
  //   /// in the clipboard
  //   timer = Timer.periodic(const Duration(milliseconds: 1000), (timer) {
  //     Clipboard.getData(Clipboard.kTextPlain).then((value) {
  //       if (value?.text != textFromClipboard) {
  //         textFromClipboard = value?.text ?? '';
  //         if (mounted) setState(() {});
  //       }
  //     });
  //   });
  // }

  // @override
  // void dispose() {
  //   super.dispose();
  //   timer?.cancel();
  // }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
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
            // if (textFromClipboard.trim().isNotEmpty)
            //   Container(
            //     constraints: const BoxConstraints(maxWidth: 180),
            //     child: Button(
            //       style: ButtonStyle(
            //           backgroundColor: WidgetStateProperty.all(Colors.blue)),
            //       onPressed: () {
            //         chatProvider.sendMessage(textFromClipboard);
            //       },
            //       child: Text(
            //         textFromClipboard.replaceAll('\n', '').trim(),
            //         maxLines: 1,
            //         overflow: TextOverflow.clip,
            //         textAlign: TextAlign.start,
            //       ),
            //     ),
            //   ),
            for (final prompt in customPrompts.value)
              if (prompt.showInChatField) PromptChipWidget(prompt: prompt),

            Button(
                child: const Text('Answer with tags'),
                onPressed: () async {
                  final textFromClipboard =
                      (await Clipboard.getData('text/plain'))?.text ?? '';
                  final text = txtController.text.trim().isEmpty
                      ? textFromClipboard
                      : txtController.text;
                  // ignore: use_build_context_synchronously
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
    final contr = context.read<ChatProvider>().messageController;

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
