import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_gpt/common/annotation_point.dart';
import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/common/language_list.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/features/image_util.dart';
import 'package:fluent_gpt/features/imgur_integration.dart';
import 'package:fluent_gpt/features/souce_nao_image_finder.dart';
import 'package:fluent_gpt/features/yandex_image_finder.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/pages/home_page.dart';
import 'package:fluent_gpt/pages/settings_page.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/annotated_image.dart';
import 'package:fluent_gpt/widgets/custom_buttons.dart';
import 'package:fluent_gpt/widgets/custom_list_tile.dart';
import 'package:fluent_gpt/widgets/drop_region.dart';
import 'package:fluent_gpt/widgets/markdown_builders/code_wrapper.dart';
import 'package:fluent_gpt/widgets/wiget_constants.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as ic;
import 'package:shimmer_animation/shimmer_animation.dart';

enum AiLensSelectedFeature { translate, scan }

class AiLensDialog extends StatefulWidget {
  const AiLensDialog({super.key, required this.bytes});
  final Uint8List bytes;

  static Future<T?> show<T>(BuildContext context, Uint8List bytes) async {
    // if image is not supported, show error
    if (!selectedChatRoom.model.imageSupported) {
      displayErrorInfoBar(
        title: 'Image not supported',
        message: 'This chat room does not support images',
      );
      return null as T;
    }
    return showDialog<T>(
      context: context,
      barrierDismissible: true,
      builder: (context) => AiLensDialog(bytes: bytes),
    );
  }

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
        imageBytes = widget.bytes;
        imageDimensions = await ImageDimensions.fromBytes(imageBytes!);
        if (kDebugMode) {
          print('Image info: $imageDimensions. Bytes: ${imageBytes?.length}');
        }
        if (mounted) setState(() {});
      }
    });
  }

  final points = <AnnotationPoint>[];

  @override
  void dispose() {
    textContr.dispose();
    super.dispose();
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
            if (selectedChatRoom.model.imageSupported)
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
                          if (kDebugMode)
                            GestureDetector(
                              onTap: () async {
                                final newBytes =
                                    await ImageUtil.resizeAndCompressImage(
                                        imageBytes!);

                                // choose path
                                final res = await FileUtils.saveFileOsPrompt(
                                  newBytes,
                                  type: FileType.image,
                                  allowedExtensions: ['png', 'jpg', 'jpeg'],
                                  fileName: 'image.png',
                                );
                                if (res == null) return;
                                displaySuccessInfoBar(
                                  title: 'Image saved. $res',
                                );
                              },
                              child: Container(
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                    FluentIcons.arrow_download_32_filled,
                                    size: 24),
                              ),
                            ),
                          GestureDetector(
                            onTap: () => _selectedFeature(
                                AiLensSelectedFeature.translate),
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
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: screenSize.width,
                  maxHeight: screenSize.height * 0.7,
                  minHeight: 200,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      top: 0,
                      bottom: 0,
                      right: 0,
                      left: 0,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: screenSize.width,
                          maxHeight: screenSize.height * 0.7,
                          minHeight: 200,
                        ),
                        child: Shimmer(
                          enabled: isLoading,
                          duration: const Duration(seconds: 1),
                          child: AnnotatedImageOverlay(
                            image: Image.memory(imageBytes!,
                                filterQuality: FilterQuality.high),
                            annotations: points,
                            originalHeight: imageDimensions!.height,
                            originalWidth: imageDimensions!.width,
                          ),
                        ),
                      ),
                    ),
                    HomeDropOverlay(),
                    HomeDropRegion(
                      onDrop: () {
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
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
                    widget.bytes,
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
                    widget.bytes,
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
                                imageBase64: base64Encode(widget.bytes),
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
                              imageBase64: base64Encode(widget.bytes),
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
          onPressed: () => Navigator.of(ctx).maybePop(),
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
    String format = '[{"x":"0","y":"0","label":"text"},...]';
    String instruction =
        'Translate what\'s on the image to "$languageTo" language. The answer should follow the json format: "$format". Use coordinates based on the image and "label" for the text! . DON\'T WRITE ANYTHING ELSE!';
    final finalizedPrompt = instruction;
    final response = await provider
        .retrieveResponseFromPrompt(finalizedPrompt, additionalPreMessages: [
      FluentChatMessage.image(
        id: "0",
        content: base64Encode(widget.bytes),
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
        content: base64Encode(widget.bytes),
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
          color: isHovering ? tileColor.withAlpha(127) : tileColor,
          child: widget.child,
        ),
      ),
    );
  }
}
