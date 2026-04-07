import 'package:fluent_gpt/common/custom_prompt.dart';
import 'package:fluent_gpt/common/debouncer.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/common/stop_reason_enum.dart';
import 'package:fluent_gpt/dialogs/ai_prompts_library_dialog.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/pages/edit_prompt_dialog.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:fluent_gpt/utils/custom_spellcheck_service.dart';
import 'package:fluent_gpt/widgets/context_menu_builders.dart';
import 'package:fluent_gpt/widgets/custom_buttons.dart';
import 'package:fluent_gpt/widgets/input_field/additional_btns_input_field.dart';
import 'package:fluent_gpt/widgets/input_field/input_field.dart';
import 'package:fluent_gpt/widgets/input_field/input_path_url_span_builder.dart';
import 'package:fluent_gpt/widgets/input_field/models_tooltip.dart';
import 'package:extended_text_field/extended_text_field.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as ic;
import 'package:flutter/material.dart'
    hide ButtonStyle, Divider, IconButton, Tooltip, TooltipThemeData, showDialog, Colors;
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';
import 'package:provider/provider.dart';
import 'package:shimmer_animation/shimmer_animation.dart';
import 'package:spell_check_on_client/spell_check_on_client.dart';

class InputFieldMain extends StatefulWidget {
  const InputFieldMain({super.key, required this.onSubmit, required this.onSecondaryTap, required this.menuController});
  final Function(String) onSubmit;
  final Function() onSecondaryTap;
  final FlyoutController menuController;

  @override
  State<InputFieldMain> createState() => _InputFieldMainState();
}

class _InputFieldMainState extends State<InputFieldMain> {
  bool useShimmer = false;
  bool isHovered = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      promptTextFocusNode.addListener(hoverListener);
    });
  }

  void hoverListener() {
    if (mounted) {
      setState(() {
        isHovered = promptTextFocusNode.hasFocus;
      });
    }
  }

  int tokensInInputField = 0;
  final debouncer = Debouncer(milliseconds: 500);

  Future<int> countTokensString(String text) async {
    if (text.isEmpty) return 0;
    final options = ChatOpenAIOptions(model: selectedChatRoom.model.modelName);
    return openAI!.countTokens(PromptValue.string(text), options: options);
  }

  void countTokensInInputField() {
    if (AppCache.nerdySelectorType.value == 0) return;
    debouncer.run(() async {
      final text = ChatProvider.messageControllerGlobal.text;
      final tokens = await countTokensString(text).onError((error, stack) => 0);
      tokensInInputField = tokens;
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: theme.resources.controlFillColorDefault,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: isHovered ? theme.accentColor : theme.resources.controlStrokeColorDefault,
            ),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Selector<ChatProvider, SpellCheck?>(
                      selector: (context, chatProvider) => chatProvider.spellCheck,
                      builder: (context, spellCheck, child) => Shimmer(
                        enabled: useShimmer,
                        duration: const Duration(milliseconds: 600),
                        color: theme.accentColor,
                        child: ListenableBuilder(
                          key: ValueKey(spellCheck),
                          listenable: ChatProvider.messageControllerGlobal,
                          builder: (context, _) {
                            final spellCfg = CustomSpellCheckService.getSpellCheckConfiguration(spellCheck);
                            final extendedSpell = spellCfg != null
                                ? ExtendedSpellCheckConfiguration(
                                    spellCheckService: spellCfg.spellCheckService,
                                    misspelledTextStyle: spellCfg.misspelledTextStyle,
                                  )
                                : null;
                            final bodyStyle = theme.typography.body;
                            final spanBuilder = InputFieldRichSpanBuilder(
                              accentColor: theme.accentColor,
                              chipBackground: theme.accentColor.withValues(alpha: 0.14),
                              linkColor: theme.accentColor,
                              baseStyle: TextStyle(
                                fontSize: bodyStyle?.fontSize ?? 14,
                                color: bodyStyle?.color,
                              ),
                            );
                            return ExtendedTextField(
                              autofocus: true,
                              focusNode: promptTextFocusNode,
                              controller: ChatProvider.messageControllerGlobal,
                              minLines: 3,
                              maxLines: 30,
                              onChanged: (_) => countTokensInInputField(),
                              onSubmitted: widget.onSubmit,
                              textInputAction: TextInputAction.done,
                              specialTextSpanBuilder: spanBuilder,
                              extendedSpellCheckConfiguration: extendedSpell,
                              extendedContextMenuBuilder: (ctx, state) =>
                                  ContextMenuBuilders.spellCheckContextMenuBuilder(
                                ctx,
                                state as EditableTextState,
                              ),
                              style: TextStyle(
                                fontSize: bodyStyle?.fontSize ?? 14,
                                height: 1.35,
                                color: bodyStyle?.color,
                              ),
                              cursorColor: theme.accentColor,
                              decoration: InputDecoration(
                                hintText: 'Use "/" or type your message here'.tr,
                                hintStyle: TextStyle(
                                  color: theme.typography.caption?.color?.withValues(alpha: 0.65),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                isDense: true,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: const AddFileButton(),
                  ),
                  Focus(
                    skipTraversal: true,
                    canRequestFocus: false,
                    descendantsAreFocusable: false,
                    descendantsAreTraversable: false,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10, right: 4, bottom: 6),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Tooltip(
                            richMessage: WidgetSpan(
                              child: ModelsTooltipContainer(),
                              alignment: PlaceholderAlignment.top,
                            ),
                            style: const TooltipThemeData(waitDuration: Duration.zero),
                            child: const ChooseModelDropdownButton(),
                          ),
                          const SizedBox(width: 4),
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
                                controller.messageController.text =
                                    prompt.getPromptText(controller.messageController.text);
                                promptTextFocusNode.requestFocus();
                              }
                            },
                            isSmall: true,
                          ),
                        ],
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
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: Selector<ChatProvider, int>(
                      selector: (context, chatProvider) => chatProvider.totalTokensByMessages,
                      builder: (context, totalTokens, child) {
                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (totalTokens >= 0.4 * selectedChatRoom.maxTokenLength)
                              ContextUsageRing(
                                totalTokens: totalTokens,
                                maxTokenLength: selectedChatRoom.maxTokenLength,
                                onTap: () {
                                  context.read<ChatProvider>().scrollToLastOverflowMessage();
                                },
                              ),
                            if (tokensInInputField > 0)
                              Tooltip(
                                  message: 'Tokens in field'.tr,
                                  style: TooltipThemeData(waitDuration: Duration.zero),
                                  child: Text('T:$tokensInInputField', style: theme.typography.caption)),
                          ],
                        );
                      },
                    ),
                  ),
                  const MicrophoneButton(),
                  if (ChatProvider.messageControllerGlobal.text.isNotEmpty)
                    ImproveTextSparkleButton(
                      onStateChange: (state) {
                        if (state == ImproveTextSparkleButtonState.improving) {
                          setState(() {
                            useShimmer = true;
                          });
                        }
                        if (state == ImproveTextSparkleButtonState.improved) {
                          setState(() {
                            useShimmer = false;
                          });
                        }
                      },
                      onTextImproved: (text) {
                        ChatProvider.messageControllerGlobal.text = text;
                      },
                      input: () => ChatProvider.messageControllerGlobal.text.trim(),
                    ),
                ],
              )
            ],
          ),
        ),
      ),
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
