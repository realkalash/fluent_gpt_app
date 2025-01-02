import 'dart:convert';
import 'dart:typed_data';

import 'package:fluent_gpt/common/annotation_point.dart';
import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/common/language_list.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/features/imgur_integration.dart';
import 'package:fluent_gpt/features/souce_nao_image_finder.dart';
import 'package:fluent_gpt/features/yandex_image_finder.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/pages/settings_page.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/annotated_image.dart';
import 'package:fluent_gpt/widgets/custom_buttons.dart';
import 'package:fluent_gpt/widgets/custom_list_tile.dart';
import 'package:fluent_gpt/widgets/markdown_builders/code_wrapper.dart';
import 'package:fluent_gpt/widgets/wiget_constants.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as ic;
import 'package:shimmer_animation/shimmer_animation.dart';

enum AiLensSelectedFeature { translate, scan }

class AiLensDialog extends StatefulWidget {
  const AiLensDialog({super.key, required this.base64String});
  final String base64String;

  @override
  State<AiLensDialog> createState() => _AiLensDialogState();
}

class _AiLensDialogState extends State<AiLensDialog> {
  final textContr = TextEditingController();
  final flyoutController = FlyoutController();
  Uint8List? imageBytes;
  ImageDimensions? imageDimensions;
  @override
  initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (selectedChatRoom.model.imageSupported) {
        imageBytes = base64Decode(widget.base64String);
        imageDimensions = await ImageDimensions.fromBytes(imageBytes!);
        if (mounted) setState(() {});
      }
    });
  }

  final points = <AnnotationPoint>[];

  @override
  void dispose() {
    super.dispose();
    textContr.dispose();
  }

  AiLensSelectedFeature? selectedFeature;

  Color getSelectedFeatureBackgroundColorButton(AiLensSelectedFeature feature) {
    return selectedFeature == feature
        ? context.theme.accentColor
        : context.theme.cardColor;
  }

  final flyoutTargetTranslateFrom = FlyoutController();
  final flyoutTargetTranslateTo = FlyoutController();

  String languageFrom = 'Auto';
  String languageTo = defaultGPTLanguage.value;

  Future selectTranslateFrom() async {
    flyoutTargetTranslateFrom.showFlyout(builder: (ctx) {
      return FlyoutContent(
        useAcrylic: false,
        child: SizedBox(
          width: 200,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              HoverListTile(
                backgroundColor: Colors.transparent,
                onTap: () {
                  languageFrom = 'Auto';
                  Navigator.of(ctx).pop();
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Text('Auto'),
                ),
              ),
              for (final lang in LanguageList.languages)
                HoverListTile(
                  backgroundColor: Colors.transparent,
                  onTap: () {
                    languageFrom = lang;
                    Navigator.of(ctx).pop();
                    setState(() {});
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Text(lang),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  Future selectTranslateTo() async {
    await flyoutTargetTranslateTo.showFlyout(builder: (ctx) {
      return FlyoutContent(
        useAcrylic: false,
        child: SizedBox(
          width: 200,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final lang in LanguageList.languages)
                HoverListTile(
                  backgroundColor: Colors.transparent,
                  onTap: () {
                    languageTo = lang;
                    _translateImage();
                    Navigator.of(ctx).pop();
                  },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Text(lang),
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext ctx) {
    final screenSize = MediaQuery.sizeOf(context);
    return ContentDialog(
      title: const Text('Ai Lens'),
      constraints: BoxConstraints(
        maxWidth: screenSize.width,
        maxHeight: screenSize.height,
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.theme.cardColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () =>
                              _selectedFeature(AiLensSelectedFeature.translate),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: getSelectedFeatureBackgroundColorButton(
                                  AiLensSelectedFeature.translate),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(FluentIcons.translate_24_regular,
                                size: 24),
                          ),
                        ),
                        GestureDetector(
                          onTap: () =>
                              _selectedFeature(AiLensSelectedFeature.scan),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              color: getSelectedFeatureBackgroundColorButton(
                                  AiLensSelectedFeature.scan),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(FluentIcons.scan_camera_20_filled,
                                size: 24),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (selectedFeature == AiLensSelectedFeature.translate)
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // MouseRegion(
                          //   cursor: SystemMouseCursors.click,
                          //   child: FlyoutTarget(
                          //     controller: flyoutTargetTranslateFrom,
                          //     child: GestureDetector(
                          //       onTap: selectTranslateFrom,
                          //       child: Container(
                          //         padding: const EdgeInsets.symmetric(
                          //             horizontal: 4, vertical: 2),
                          //         decoration: BoxDecoration(
                          //           color: context.theme.accentColor,
                          //           borderRadius: BorderRadius.circular(8),
                          //         ),
                          //         child: Text(languageFrom),
                          //       ),
                          //     ),
                          //   ),
                          // ),
                          // GestureDetector(
                          //   onTap: () {
                          //     final temp = languageFrom == 'Auto'
                          //         ? defaultGPTLanguage.value
                          //         : languageFrom;
                          //     languageFrom = languageTo;
                          //     languageTo = temp;
                          //     setState(() {});
                          //   },
                          //   child: Container(
                          //     padding: const EdgeInsets.symmetric(
                          //         horizontal: 16, vertical: 4),
                          //     color: context.theme.cardColor,
                          //     child: Icon(
                          //         FluentIcons
                          //             .arrow_bidirectional_left_right_16_filled,
                          //         size: 16),
                          //   ),
                          // ),

                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: FlyoutTarget(
                              controller: flyoutTargetTranslateTo,
                              child: GestureDetector(
                                onTap: selectTranslateTo,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(8)),
                                  child: Text(languageTo),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (points.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: context.theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: () => viewAllAnnotations(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 2),
                            decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8)),
                            child: Text('Transcript points'),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (imageBytes != null)
              Shimmer(
                enabled: isLoading,
                duration: const Duration(seconds: 1),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: screenSize.width,
                    maxHeight: screenSize.height * 0.7,
                    minHeight: 200,
                  ),
                  child: AnnotatedImageOverlay(
                    image: Image.memory(imageBytes!),
                    annotations: points,
                    originalHeight: imageDimensions!.height,
                    originalWidth: imageDimensions!.width,
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
                    enabled: selectedChatRoom.model.imageSupported,
                    placeholder: selectedChatRoom.model.imageSupported
                        ? 'Type your message here or leave empty'
                        : 'This ai model does support not images',
                    onSubmitted: (value) {
                      if (selectedChatRoom.model.imageSupported) sendMessage();
                    },
                  ),
                ),
                FlyoutTarget(
                  controller: flyoutController,
                  child: GestureDetector(
                    onSecondaryTap: () {
                      _rightClickSendMessage(context);
                    },
                    child: SqueareIconButton(
                      onTap: selectedChatRoom.model.imageSupported
                          ? sendMessage
                          : null,
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
            if (AppCache.useSouceNao.value == true)
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
            if (AppCache.useYandexImageSearch.value == true)
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
                GestureDetector(
                  onSecondaryTap: () {
                    flyoutController.showFlyout(builder: (context) {
                      return MenuFlyout(
                        items: [
                          MenuFlyoutItem(
                            text: const Text(
                                'Send not in real-time (can help with some LLM providers)'),
                            onPressed: () {
                              // close flyout
                              Navigator.of(context).pop();
                              final provider = context.read<ChatProvider>();
                              provider.sendSingleMessage(
                                'Extract text from this image. Copy the main part to the clipboard using this format:\n\n```Clipboard\nYour text here\n```',
                                imageBase64: widget.base64String,
                                showImageInChat: true,
                                sendAsStream: false,
                              );
                              // close dialog
                              Navigator.of(context).pop();
                            },
                          )
                        ],
                      );
                    });
                  },
                  child: Button(
                    onPressed: !selectedChatRoom.model.imageSupported
                        ? null
                        : () {
                            final provider = context.read<ChatProvider>();
                            provider.sendSingleMessage(
                              'Extract text from this image. Copy the main part to the clipboard using this format:\n\n```Clipboard\nYour text here\n```',
                              imageBase64: widget.base64String,
                              showImageInChat: true,
                            );
                            Navigator.of(context).pop();
                          },
                    child: const Text('Extract text'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        FilledRedButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Dismiss'),
        )
      ],
    );
  }

  void sendMessage([bool asStream = true]) {
    final provider = context.read<ChatProvider>();
    provider.sendMessage(textContr.text,
        hidePrompt: false, sendStream: asStream);
    Navigator.of(context).pop(true);
  }

  void _rightClickSendMessage(BuildContext context) {
    if (!selectedChatRoom.model.imageSupported) return;
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

  bool isLoading = false;

  _selectedFeature(AiLensSelectedFeature feature) {
    if (selectedFeature == feature) {
      selectedFeature = null;
      points.clear();
      setState(() {});
      return;
    }
    setState(() {
      selectedFeature = feature;
    });
    if (feature == AiLensSelectedFeature.translate) {
      // updateAnnotationPointsDebug();
      _translateImage();
    } else if (feature == AiLensSelectedFeature.scan) {
      _scanImage();
    }
  }

  _translateImage() async {
    final provider = context.read<ChatProvider>();
    setState(() {
      isLoading = true;
    });
    String format = '[{"x":"0","y":"0","label":"text"}]';
    String instruction =
        'Translate what\'s on the image to "$languageTo" language. The answer should follow the json format: $format, ...]. DON\'T WRITE ANYTHING ELSE!';
    final finalizedPrompt = instruction;
    final response = await provider
        .retrieveResponseFromPrompt(finalizedPrompt, additionalPreMessages: [
      FluentChatMessage.image(
        id: "0",
        content: widget.base64String,
        creator: "user",
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    ]);
    final normalizedText = response.trim().removeWrappedQuotes;
    try {
      final json = jsonDecode(normalizedText) as List;
      final annotationsResponseList =
          json.map((e) => AnnotationPoint.fromJson(e)).toList();

      points.clear();
      points.addAll(annotationsResponseList);
      log('json: $json');
    } catch (e) {
      logError('Error: $e');
      displayErrorInfoBar(
        title: 'Error translating image',
        message: e.toString(),
      );
    } finally {
      isLoading = false;
      setState(() {});
    }
  }

  String extractCodeFromMarkdown(String text) {
    final regex = RegExp(r'```json\n(.*?)```', dotAll: true);
    final match = regex.firstMatch(text);
    return match?.group(1) ?? '';
  }

  _scanImage() async {
    final provider = context.read<ChatProvider>();
    setState(() {
      isLoading = true;
    });
    String format = '[{"x":"0","y":"0","label":"text"}]';
    String youAre = 'You are a spatial understanding Agent.';
    String instruction =
        'Point to the items/objects/persons with no more than 10 items. The answer should follow the json format: $format, ...]. DON\'T WRITE ANYTHING ELSE!';
    final finalizedPrompt = '$youAre\n\n$instruction';
    final response = await provider
        .retrieveResponseFromPrompt(finalizedPrompt, additionalPreMessages: [
      FluentChatMessage.image(
        id: "0",
        content: widget.base64String,
        creator: "user",
        timestamp: DateTime.now().millisecondsSinceEpoch,
      ),
    ]);
    final normalizedText = response.trim().removeWrappedQuotes;
    try {
      final isContainsMarkdown = normalizedText.contains('```json');
      final jsonText = isContainsMarkdown
          ? extractCodeFromMarkdown(normalizedText)
          : normalizedText;
      final json = jsonDecode(jsonText) as List;
      final annotationsResponseList =
          json.map((e) => AnnotationPoint.fromJson(e)).toList();

      points.clear();
      points.addAll(annotationsResponseList);
      log('json: $json');
    } catch (e) {
      selectedFeature = null;
      logError('Error: $e');
      displayErrorInfoBar(
        title: 'Error translating image',
        message: e.toString(),
      );
    } finally {
      isLoading = false;
      setState(() {});
    }
  }

  viewAllAnnotations() {
    showDialog(
      context: context,
      builder: (context) {
        return ContentDialog(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.sizeOf(context).width - 64,
            maxHeight: MediaQuery.sizeOf(context).height,
          ),
          title: const Text('Annotations'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final point in points)
                  BasicListTile(
                    title: SelectableText('label: ${point.label}'),
                    trailing: Text('x: ${point.x}, y: ${point.y}'),
                  ),
              ],
            ),
          ),
          actions: [
            Button(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }
}

class HoverListTile extends StatefulWidget {
  const HoverListTile(
      {super.key, this.backgroundColor, required this.child, this.onTap});
  final Color? backgroundColor;
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<HoverListTile> createState() => _HoverListTileState();
}

class _HoverListTileState extends State<HoverListTile> {
  bool isHovering = false;
  @override
  Widget build(BuildContext context) {
    final tileColor =
        widget.backgroundColor ?? context.theme.scaffoldBackgroundColor;
    return MouseRegion(
      onEnter: (_) {
        if (isHovering) return;
        setState(() {
          isHovering = true;
        });
      },
      onExit: (_) {
        if (!isHovering) return;
        setState(() {
          isHovering = false;
        });
      },
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          color: isHovering ? tileColor.withOpacity(0.5) : tileColor,
          child: widget.child,
        ),
      ),
    );
  }
}
