import 'dart:convert';

import 'package:fluent_gpt/features/imgur_integration.dart';
import 'package:fluent_gpt/features/souce_nao_image_finder.dart';
import 'package:fluent_gpt/features/yandex_image_finder.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:fluent_gpt/widgets/custom_buttons.dart';
import 'package:fluent_gpt/widgets/markdown_builders/code_wrapper.dart';
import 'package:fluent_gpt/widgets/wiget_constants.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as ic;

class AiLensDialog extends StatefulWidget {
  const AiLensDialog({super.key, required this.base64String});
  final String base64String;

  @override
  State<AiLensDialog> createState() => _AiLensDialogState();
}

class _AiLensDialogState extends State<AiLensDialog> {
  final textContr = TextEditingController();
  final flyoutController = FlyoutController();
  @override
  void dispose() {
    super.dispose();
    textContr.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    return ContentDialog(
      title: const Text('Ai Lens'),
      constraints: const BoxConstraints(
        maxWidth: 600,
        maxHeight: 800,
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Image.memory(
                        base64Decode(widget.base64String),
                        fit: BoxFit.cover,
                        excludeFromSemantics: true,
                      ),
                    ),
                    Acrylic(
                      blurAmount: 5,
                      luminosityAlpha: 0.5,
                      shadowColor: Colors.white,
                      child: SizedBox(
                        width: 400,
                        height: 400,
                        child: Image.memory(
                          base64Decode(widget.base64String),
                          fit: BoxFit.scaleDown,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            biggerSpacer,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: TextBox(
                    autofocus: true,
                    controller: textContr,
                    placeholder: 'Type your message here or leave empty',
                    onSubmitted: (value) => sendMessage(),
                  ),
                ),
                FlyoutTarget(
                  controller: flyoutController,
                  child: GestureDetector(
                    onSecondaryTap: () {
                      _rightClickSendMessage(context);
                    },
                    child: SqueareIconButton(
                      onTap: sendMessage,
                      icon: const Icon(ic.FluentIcons.send_24_filled),
                      tooltip: 'Send message',
                    ),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Divider(),
            ),
            Button(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Search by image (SauceNao)'),
                  const SizedBox(width: 8),
                  Image.asset('assets/saucenao_favicon.png'),
                ],
              ),
              onPressed: () {
                if (ImgurIntegration.isClientIdValid() == false) {
                  onTrayButtonTapCommand(
                    "You don't have Imgur integration enabled. Please, go to settings and set up ImgurAPI",
                    'show_dialog',
                  );
                  return;
                }
                SauceNaoImageFinder.uploadToImgurAndFindImageBytes(
                  base64Decode(widget.base64String),
                );
              },
            ),
            spacer,
            Button(
              child: const Text('Search by image (Yandex)'),
              onPressed: () {
                if (ImgurIntegration.isClientIdValid() == false) {
                  onTrayButtonTapCommand(
                    "You don't have Imgur integration enabled. Please, go to settings and set up ImgurAPI",
                    'show_dialog',
                  );
                  return;
                }
                YandexImageFinder.uploadToImgurAndFindImageBytes(
                  base64Decode(widget.base64String),
                );
              },
            ),
            spacer,
            Wrap(
              children: [
                Button(
                  child: const Text('Extract text'),
                  onPressed: () {
                    final provider = context.read<ChatProvider>();
                    provider.sendSingleMessage(
                      'Extract text from this image. Copy the main part to the clipboard using this format:\n\n```Clipboard\nYour text here\n```',
                      imageBase64: widget.base64String,
                      showImageInChat: true,
                    );
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        FilledRedButton(
          onPressed: () {
            context.read<ChatProvider>().removeFileFromInput();
            Navigator.of(ctx).pop();
          },
          child: const Text('Dismiss'),
        )
      ],
    );
  }

  void sendMessage([bool asStream = true]) {
    final provider = context.read<ChatProvider>();
    provider.sendMessage(textContr.text, false, asStream);
    Navigator.of(context).pop();
  }

  void _rightClickSendMessage(BuildContext context) {
    flyoutController.showFlyout(builder: (context) {
      return MenuFlyout(
        items: [
          MenuFlyoutItem(
            text: const Text(
                'Send not in real-time (can help with some LLM providers)'),
            onPressed: () {
              Navigator.of(context).pop();
              sendMessage(false);
            },
          )
        ],
      );
    });
  }
}
