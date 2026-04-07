import 'package:file_picker/file_picker.dart';
import 'package:fluent_gpt/common/attachment.dart';
import 'package:fluent_gpt/common/chat_model.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/dialogs/answer_with_tags_dialog.dart';
import 'package:fluent_gpt/dialogs/models_list_dialog.dart';
import 'package:fluent_gpt/dialogs/search_chat_dialog.dart';
import 'package:fluent_gpt/features/push_to_talk_tool.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/pages/prompts_settings_page.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/custom_buttons.dart';
import 'package:fluent_gpt/widgets/input_field/input_field.dart';
import 'package:fluent_gpt/widgets/input_field/input_field_main.dart';
import 'package:fluent_gpt/widgets/markdown_builders/code_wrapper.dart';
import 'package:fluent_gpt/widgets/settings_page/settings_page_widgets.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as ic;
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter_single_instance/flutter_single_instance.dart';
import 'package:provider/provider.dart';
import 'package:record/record.dart';
// material
import 'package:flutter/material.dart' as material;

class MicrophoneButton extends StatefulWidget {
  const MicrophoneButton({super.key});

  @override
  State<MicrophoneButton> createState() => _MicrophoneButtonState();
}

class _MicrophoneButtonState extends State<MicrophoneButton> {
  Future<bool> checkPermission() async {
    final result = await AudioRecorder().hasPermission();
    if (!result) {
      // ignore: use_build_context_synchronously
      displayInfoBar(context, builder: (ctx, close) {
        return const InfoBar(
          title: Text('Permission required'),
          severity: InfoBarSeverity.warning,
        );
      });
    }
    return result;
  }

  Future startRecording() async {
    final permission = await checkPermission();
    if (!permission) {
      return;
    }
    PushToTalkTool.isRecording = true;
    // ignore: use_build_context_synchronously
    final provider = context.read<ChatProvider>();
    final resultStart = await provider.startListeningForInput();
    if (!resultStart) {
      PushToTalkTool.isRecording = false;
    }
  }

  void stopRecording() {
    PushToTalkTool.isRecording = false;
    final provider = context.read<ChatProvider>();
    provider.stopListeningForInput();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Object>(
        stream: PushToTalkTool.isRecordingStream,
        builder: (context, _) {
          final isRecording = PushToTalkTool.isRecording;
          return MouseRegion(
            cursor: SystemMouseCursors.click,
            child: TransparentButtonAdvanced(
              onChanged: (v) {
                if (PushToTalkTool.isRecording) {
                  stopRecording();
                } else {
                  startRecording();
                }
              },
              contextItems: [
                for (final locale in gptLocales)
                  FlyoutListTile(
                    text: Text(locale.languageCode),
                    selected: AppCache.speechLanguage.value == locale.languageCode,
                    onPressed: () {
                      AppCache.speechLanguage.value = locale.languageCode;
                      setState(() {});
                      Navigator.of(context).pop();
                    },
                  ),
              ],
              maxWidthContextMenu: 84,
              checked: PushToTalkTool.isRecording,
              tooltip: 'Use voice input'.tr,
              child: Icon(
                ic.FluentIcons.mic_24_regular,
                color: isRecording ? context.theme.accentColor : null,
              ),
            ),
          );
        });
  }
}

class ChooseModelButton extends StatefulWidget {
  const ChooseModelButton({super.key});

  @override
  State<ChooseModelButton> createState() => _ChooseModelButtonState();
}

class _ChooseModelButtonState extends State<ChooseModelButton> {
  final FlyoutController flyoutController = FlyoutController();

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final provider = context.watch<ChatProvider>();
    final models = allModels.value;
    final cardColor = FluentTheme.of(context).cardColor;
    return Focus(
      canRequestFocus: false,
      descendantsAreTraversable: false,
      child: FlyoutTarget(
        controller: flyoutController,
        child: Listener(
          onPointerDown: (_) => openFlyout(context),
          onPointerSignal: (event) {
            if (event is PointerScrollEvent) {
              if (event.scrollDelta.dy > 0) {
                final selectedModel = selectedChatRoom.model;
                final index = models.indexOf(selectedModel);
                if (index < models.length - 1) {
                  final model = models[index + 1];
                  provider.selectNewModel(model);
                  displayTextInfoBar('${'Model changed to'.tr} ${model.customName}');
                }
              } else {
                final models = allModels.value;
                final selectedModel = selectedChatRoom.model;
                final index = models.indexOf(selectedModel);
                if (index > 0) {
                  final model = models[index - 1];
                  provider.selectNewModel(model);
                  displayTextInfoBar('${'Model changed to'.tr} ${model.customName}');
                }
              }
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: const BorderRadius.all(Radius.circular(4)),
            ),
            width: 30,
            height: 30,
            margin: const EdgeInsets.only(left: 4),
            child: SizedBox.square(
              dimension: 20,
              child: selectedModel.modelIcon,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> createFirstModel() async {
    final chatProvider = context.read<ChatProvider>();
    final isListWasEmpty = allModels.value.isEmpty;
    final model = await showDialog<ChatModelAi>(
      context: context,
      builder: (context) => const AddAiModelDialog(),
    );
    if (model != null) {
      await chatProvider.addNewCustomModel(model);
      if (isListWasEmpty) {
        chatProvider.selectNewModel(model);
      }
    }
  }

  void openFlyout(BuildContext context) {
    final provider = context.read<ChatProvider>();
    final models = allModels.value;
    if (models.isEmpty) {
      createFirstModel();
      return;
    }

    final selectedModel = selectedChatRoom.model;
    flyoutController.showFlyout(builder: (ctx) {
      return StatefulBuilder(
        builder: (_, setState) => MenuFlyout(
          items: [
            ...List.generate(models.length, (i) {
              final e = models[i];
              return MenuFlyoutItem(
                selected: e == selectedModel,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (e == selectedModel)
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: const Icon(ic.FluentIcons.checkmark_16_filled),
                      ),
                    SqueareIconButton(
                      onTap: () async {
                        Navigator.of(ctx).pop();

                        final changedModel = await showDialog<ChatModelAi>(
                          context: context,
                          builder: (context) => AddAiModelDialog(initialModel: e),
                        );
                        if (changedModel != null) {
                          provider.removeCustomModel(e);
                          await provider.addNewCustomModel(changedModel);
                          await Future.delayed(const Duration(milliseconds: 100));
                          provider.selectNewModel(changedModel);
                        }
                      },
                      icon: Icon(ic.FluentIcons.edit_16_regular),
                      tooltip: 'Edit'.tr,
                    ),
                    const SizedBox(width: 4),
                    if (i != 0)
                      SqueareIconButton(
                        onTap: () async {
                          // move this item 1 element up
                          final index = models.indexOf(e);
                          final previous = models[index - 1];
                          models[index - 1] = e;
                          models[index] = previous;
                          allModels.value = models;
                          provider.saveModelsToDisk();
                          setState(() {});
                        },
                        icon: Icon(ic.FluentIcons.arrow_up_12_regular),
                        tooltip: 'Move up'.tr,
                      ),
                  ],
                ),
                leading: SizedBox.square(dimension: 24, child: e.modelIcon),
                text: Text(e.customName),
                onPressed: () => provider.selectNewModel(e),
              );
            }),
            const MenuFlyoutSeparator(),
            MenuFlyoutItem(
              leading: const Icon(ic.FluentIcons.edit_16_regular),
              text: Text('Edit'.tr),
              onPressed: () {
                Navigator.of(ctx).pop();
                showDialog(context: ctx, builder: (ctx) => ModelsListDialog());
              },
            ),
          ],
        ),
      );
    });
  }
}

class ChooseModelDropdownButton extends StatefulWidget {
  const ChooseModelDropdownButton({super.key});

  @override
  State<ChooseModelDropdownButton> createState() => _ChooseModelDropdownButtonState();
}

class _ChooseModelDropdownButtonState extends State<ChooseModelDropdownButton> {
  final FlyoutController flyoutController = FlyoutController();
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
    final provider = context.watch<ChatProvider>();
    final models = allModels.value;
    final Brightness brightness = FluentTheme.of(context).brightness;
    return Focus(
      canRequestFocus: false,
      descendantsAreTraversable: false,
      child: FlyoutTarget(
        controller: flyoutController,
        child: MouseRegion(
          onEnter: (_) => setState(() {
            isHovered = true;
          }),
          onExit: (_) => setState(() {
            isHovered = false;
          }),
          child: Listener(
            onPointerDown: (_) => openFlyout(context),
            onPointerSignal: (event) {
              if (event is PointerScrollEvent) {
                if (event.scrollDelta.dy > 0) {
                  final selectedModel = selectedChatRoom.model;
                  final index = models.indexOf(selectedModel);
                  if (index < models.length - 1) {
                    final model = models[index + 1];
                    provider.selectNewModel(model);
                    displayTextInfoBar('${'Model changed to'.tr} ${model.customName}');
                  }
                } else {
                  final models = allModels.value;
                  final selectedModel = selectedChatRoom.model;
                  final index = models.indexOf(selectedModel);
                  if (index > 0) {
                    final model = models[index - 1];
                    provider.selectNewModel(model);
                    displayTextInfoBar('${'Model changed to'.tr} ${model.customName}');
                  }
                }
              }
            },
            child: Container(
              decoration: BoxDecoration(
                color: isHovered
                    ? brightness == Brightness.dark
                        ? material.Colors.white24
                        : material.Colors.black12
                    : Colors.transparent,
                borderRadius: const BorderRadius.all(Radius.circular(10)),
              ),
              constraints: const BoxConstraints(minWidth: 30, minHeight: 30, maxWidth: 100),
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: Text(
                      selectedModel.customName,
                      maxLines: 1,
                    ),
                  ),
                  Icon(ic.FluentIcons.chevron_down_12_regular, size: 12),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> createFirstModel() async {
    final chatProvider = context.read<ChatProvider>();
    final isListWasEmpty = allModels.value.isEmpty;
    final model = await showDialog<ChatModelAi>(
      context: context,
      builder: (context) => const AddAiModelDialog(),
    );
    if (model != null) {
      await chatProvider.addNewCustomModel(model);
      if (isListWasEmpty) {
        chatProvider.selectNewModel(model);
      }
    }
  }

  void openFlyout(BuildContext context) {
    final provider = context.read<ChatProvider>();
    final models = allModels.value;
    if (models.isEmpty) {
      createFirstModel();
      return;
    }

    final selectedModel = selectedChatRoom.model;
    flyoutController.showFlyout(builder: (ctx) {
      return StatefulBuilder(
        builder: (_, setState) => MenuFlyout(
          items: [
            ...List.generate(models.length, (i) {
              final e = models[i];
              return MenuFlyoutItem(
                selected: e == selectedModel,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (e == selectedModel)
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: const Icon(ic.FluentIcons.checkmark_16_filled),
                      ),
                    SqueareIconButton(
                      onTap: () async {
                        Navigator.of(ctx).pop();

                        final changedModel = await showDialog<ChatModelAi>(
                          context: context,
                          builder: (context) => AddAiModelDialog(initialModel: e),
                        );
                        if (changedModel != null) {
                          provider.removeCustomModel(e);
                          await provider.addNewCustomModel(changedModel);
                          await Future.delayed(const Duration(milliseconds: 100));
                          provider.selectNewModel(changedModel);
                        }
                      },
                      icon: Icon(ic.FluentIcons.edit_16_regular),
                      tooltip: 'Edit'.tr,
                    ),
                    const SizedBox(width: 4),
                    if (i != 0)
                      SqueareIconButton(
                        onTap: () async {
                          // move this item 1 element up
                          final index = models.indexOf(e);
                          final previous = models[index - 1];
                          models[index - 1] = e;
                          models[index] = previous;
                          allModels.value = models;
                          provider.saveModelsToDisk();
                          setState(() {});
                        },
                        icon: Icon(ic.FluentIcons.arrow_up_12_regular),
                        tooltip: 'Move up'.tr,
                      ),
                  ],
                ),
                leading: SizedBox.square(dimension: 24, child: e.modelIcon),
                text: Text(e.customName),
                onPressed: () => provider.selectNewModel(e),
              );
            }),
            const MenuFlyoutSeparator(),
            MenuFlyoutItem(
              leading: const Icon(ic.FluentIcons.edit_16_regular),
              text: Text('Edit'.tr),
              onPressed: () {
                Navigator.of(ctx).pop();
                showDialog(context: ctx, builder: (ctx) => ModelsListDialog());
              },
            ),
          ],
        ),
      );
    });
  }
}

class AddFileButton extends StatelessWidget {
  const AddFileButton({super.key, this.isMini = false});

  final bool isMini;

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    return TransparentButtonAdvanced(
      tooltip: 'Supports jpeg, png, docx, xlsx, txt, csv',
      onChanged: (p0) async {
        FilePickerResult? result = await FilePicker.pickFiles(
          allowedExtensions: [
            'jpg',
            'jpeg',
            'png',
            'docx',
            'xlsx',
            'txt',
            'csv',
          ],
          type: FileType.custom,
          allowMultiple: true,
        );
        if (result != null && result.files.isNotEmpty) {
          chatProvider.addFilesToInput(result.files.map((e) => e.toXFile()).toList());
          windowManager.focus();
          promptTextFocusNode.requestFocus();
        }
      },
      child: chatProvider.isSendingFiles
          ? const ProgressRing()
          : Icon(ic.FluentIcons.attach_24_filled, size: isMini ? 16 : 24),
    );
  }
}

class FileThumbnails extends StatelessWidget {
  const FileThumbnails();
  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final fileInputs = chatProvider.fileInputs;

    if (fileInputs.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: fileInputs.map((attachment) {
          return attachment.toWidgetThumbnail(
            onTap: (att) {
              showDialog(
                context: context,
                builder: (ctx) => ImagesDialog(images: fileInputs),
              );
            },
            onRemove: (att) {
              chatProvider.removeAttachmentFromInput(att);
            },
          );
        }).toList(),
      ),
    );
  }
}

class HotShurtcutsWidget extends StatelessWidget {
  const HotShurtcutsWidget({super.key});

  static void showAnswerWithTagsDialog(BuildContext context, String text) {
    showDialog(
      context: context,
      builder: (ctx) => AnswerWithTagsDialog(text: text),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: customPrompts,
        builder: (context, snapshot) {
          if (snapshot.data == null) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SizedBox(
              width: double.infinity,
              child: Wrap(
                alignment: WrapAlignment.start,
                spacing: 4,
                runSpacing: 4,
                children: [
                  for (final prompt in customPrompts.value)
                    if (prompt.showInChatField) PromptChipWidget(prompt: prompt),
                  Button(
                      child: Text('Answer with tags'.tr),
                      onPressed: () async {
                        final chatProvider = context.read<ChatProvider>();
                        final txtController = chatProvider.messageController;
                        final textFromClipboard = (await Clipboard.getData('text/plain'))?.text ?? '';
                        final text = txtController.text.trim().isEmpty ? textFromClipboard : txtController.text;
                        HotShurtcutsWidget.showAnswerWithTagsDialog(
                          // ignore: use_build_context_synchronously
                          context,
                          text,
                        );
                        txtController.clear();
                      }),
                  ToggleButtonAdvenced(
                    icon: Icon(ic.FluentIcons.settings_20_regular),
                    onChanged: (_) => showDialog(
                      context: context,
                      builder: (ctx) => const CustomPromptsSettingsDialog(),
                    ),
                    tooltip: 'Quick prompts'.tr,
                  ),
                ],
              ),
            ),
          );
        });
  }
}

class HotShurtcutsOneLineWidget extends StatelessWidget {
  const HotShurtcutsOneLineWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
        stream: customPrompts,
        builder: (context, snapshot) {
          if (snapshot.data == null) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: SizedBox(
              width: double.infinity,
              child: Row(
                spacing: 4,
                children: [
                  ToggleButtonAdvenced(
                    icon: Icon(ic.FluentIcons.settings_20_regular),
                    onChanged: (_) => showDialog(
                      context: context,
                      builder: (ctx) => const CustomPromptsSettingsDialog(),
                    ),
                    tooltip: 'Quick prompts'.tr,
                  ),
                  for (final prompt
                      in customPrompts.value.length > 4 ? customPrompts.value.take(4) : customPrompts.value)
                    if (prompt.showInChatField) PromptChipWidget(prompt: prompt),
                ],
              ),
            ),
          );
        });
  }
}
