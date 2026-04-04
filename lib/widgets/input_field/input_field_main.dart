import 'package:fluent_gpt/common/custom_prompt.dart';
import 'package:fluent_gpt/common/stop_reason_enum.dart';
import 'package:fluent_gpt/dialogs/ai_prompts_library_dialog.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/pages/edit_prompt_dialog.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:fluent_gpt/utils/custom_spellcheck_service.dart';
import 'package:fluent_gpt/widgets/context_menu_builders.dart';
import 'package:fluent_gpt/widgets/custom_buttons.dart';
import 'package:fluent_gpt/widgets/input_field/additional_btns_input_field.dart';
import 'package:fluent_gpt/widgets/input_field/input_field.dart';
import 'package:fluent_gpt/widgets/input_field/models_tooltip.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as ic;
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:provider/provider.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:spell_check_on_client/spell_check_on_client.dart';

class InputFieldMain extends StatefulWidget {
  const InputFieldMain(
      {super.key,
      required this.countTokensInInputField,
      required this.onSubmit,
      required this.onSecondaryTap,
      required this.menuController});
  final Function() countTokensInInputField;
  final Function(String) onSubmit;
  final Function() onSecondaryTap;
  final FlyoutController menuController;

  @override
  State<InputFieldMain> createState() => _InputFieldMainState();
}

class _InputFieldMainState extends State<InputFieldMain> {
  bool _useShimmer = false;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Row(
      children: [
        const AddFileButton(),
        Expanded(
          child: Selector<ChatProvider, SpellCheck?>(
            selector: (context, chatProvider) => chatProvider.spellCheck,
            builder: (context, spellCheck, child) => Shimmer(
              enabled: _useShimmer,
              duration: const Duration(milliseconds: 600),
              color: theme.accentColor,
              child: TextBox(
                key: ValueKey(spellCheck),
                autofocus: true,
                focusNode: promptTextFocusNode,
                // prefixMode: OverlayVisibilityMode.always,
                controller: ChatProvider.messageControllerGlobal,
                minLines: 3,
                maxLines: 30,
                onChanged: (_) => widget.countTokensInInputField(),
                contextMenuBuilder: ContextMenuBuilders.spellCheckContextMenuBuilder,
                suffix: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const MicrophoneButton(),
                    if (ChatProvider.messageControllerGlobal.text.isNotEmpty)
                      ImproveTextSparkleButton(
                        onStateChange: (state) {
                          if (state == ImproveTextSparkleButtonState.improving) {
                            setState(() {
                              _useShimmer = true;
                            });
                          }
                          if (state == ImproveTextSparkleButtonState.improved) {
                            setState(() {
                              _useShimmer = false;
                            });
                          }
                        },
                        onTextImproved: (text) {
                          ChatProvider.messageControllerGlobal.text = text;
                        },
                        input: () => ChatProvider.messageControllerGlobal.text.trim(),
                      ),
                  ],
                ),
                prefix: Focus(
                  skipTraversal: true,
                  canRequestFocus: false,
                  descendantsAreFocusable: false,
                  descendantsAreTraversable: false,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Tooltip(
                        richMessage: WidgetSpan(
                          child: ModelsTooltipContainer(),
                          alignment: PlaceholderAlignment.top,
                        ),
                        style: TooltipThemeData(waitDuration: Duration.zero),
                        child: const ChooseModelButton(),
                      ),
                      AiLibraryButton(
                        onPressed: () async {
                          // ignore: use_build_context_synchronously
                          final controller = context.read<ChatProvider>();
                          final prompt = await showDialog<CustomPrompt?>(
                            context: context,
                            builder: (ctx) => const AiPromptsLibraryDialog(),
                            barrierDismissible: true,
                          );
                          if (prompt != null) {
                            controller.messageController.text = prompt.getPromptText(controller.messageController.text);
                            promptTextFocusNode.requestFocus();
                          }
                        },
                        isSmall: true,
                      ),
                    ],
                  ),
                ),
                spellCheckConfiguration: CustomSpellCheckService.getSpellCheckConfiguration(spellCheck),
                textInputAction: TextInputAction.done,
                onSubmitted: (value) => widget.onSubmit(value),
                placeholder: 'Use "/" or type your message here'.tr,
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        Selector<ChatProvider, bool>(
          selector: (context, chatProvider) => chatProvider.isAnswering,
          builder: (context, isAnswering, child) {
            if (!isAnswering) return const SizedBox.shrink();
            return SizedBox.square(
              dimension: 52,
              child: IconButton(
                style: ButtonStyle(
                    backgroundColor: WidgetStatePropertyAll(
                  theme.scaffoldBackgroundColor,
                )),
                onPressed: () {
                  context.read<ChatProvider>().stopAnswering(StopReason.canceled);
                },
                icon: Icon(
                  ic.FluentIcons.stop_24_filled,
                  size: 24,
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

class PromptChipWidget extends StatefulWidget {
  const PromptChipWidget({
    super.key,
    required this.prompt,
  });

  final CustomPrompt prompt;

  @override
  State<PromptChipWidget> createState() => _PromptChipWidgetState();
}

class _PromptChipWidgetState extends State<PromptChipWidget> {
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

  final flyoutContr = FlyoutController();

  @override
  Widget build(BuildContext context) {
    return FlyoutTarget(
      controller: flyoutContr,
      child: GestureDetector(
        onSecondaryTap: () => _onRightClick(context),
        child: Button(
          onPressed: () => _onTap(context, widget.prompt),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.prompt.icon, size: 18),
              const SizedBox(width: 4),
              Text(widget.prompt.title.tr),
              if (widget.prompt.children.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: DropDownButton(
                    items: [
                      for (final child in widget.prompt.children)
                        MenuFlyoutItem(
                          leading: Icon(child.icon),
                          text: Text(child.title.tr),
                          onPressed: () => _onTap(context, child),
                        )
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _onRightClick(BuildContext context) {
    final item = widget.prompt;

    flyoutContr.showFlyout(builder: (ctx) {
      return FlyoutContent(
        constraints: const BoxConstraints(maxWidth: 220),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final child in item.children)
              FlyoutListTile(
                icon: Icon(child.icon),
                text: Text(child.title),
                onPressed: () => _onTap(ctx, child),
              ),
            if (item.children.isNotEmpty) const Divider(),
            FlyoutListTile(
              icon: const Icon(ic.FluentIcons.settings_20_regular),
              text: Text('Edit'.tr),
              onPressed: () async {
                final prompt = await showDialog<CustomPrompt?>(
                  context: context,
                  builder: (context) => EditPromptDialog(prompt: item),
                );
                if (prompt != null) {
                  // ignore: use_build_context_synchronously
                  final list = customPrompts.value.toList();
                  list.removeWhere((element) => element.id == item.id);
                  list.add(prompt);
                  list.sort((a, b) => a.index.compareTo(b.index));
                  customPrompts.add(list);
                  // ignore: use_build_context_synchronously
                  Navigator.of(ctx).pop();

                  //unbind old hotkey
                  if (item.hotkey != null) {
                    await hotKeyManager.unregister(item.hotkey!);

                    /// wait native channel to finish
                    await Future.delayed(const Duration(milliseconds: 200));
                  }
                  OverlayManager.bindHotkeys(customPrompts.value);
                }
              },
            ),
          ],
        ),
      );
    });
  }
}
