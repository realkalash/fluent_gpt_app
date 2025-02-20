// ignore_for_file: curly_braces_in_flow_control_structures

import 'dart:async';

import 'package:fluent_gpt/common/custom_prompt.dart';
import 'package:fluent_gpt/dialogs/ai_prompts_library_dialog.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/markdown_builders/code_wrapper.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:provider/provider.dart';
import 'package:shimmer_animation/shimmer_animation.dart';

class FilledRedButton extends StatelessWidget {
  const FilledRedButton({
    super.key,
    this.onPressed,
    required this.child,
    this.onLongPressed,
    this.autofocus = false,
  });
  final void Function()? onPressed;
  final void Function()? onLongPressed;
  final Widget child;
  final bool autofocus;
  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onPressed,
      autofocus: autofocus,
      onLongPress: onLongPressed,
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.all(Colors.white),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.isDisabled) return Colors.red.withAlpha(64);
          if (states.isHovered) return Colors.red['lighter'];
          if (states.isFocused) return Colors.red['light'];
          return Colors.red['normal'];
        }),
      ),
      child: child,
    );
  }
}

class FilledAccentButton extends StatelessWidget {
  const FilledAccentButton({
    super.key,
    this.onPressed,
    required this.child,
    this.onLongPressed,
    this.autofocus = false,
  });
  final void Function()? onPressed;
  final void Function()? onLongPressed;
  final Widget child;
  final bool autofocus;
  @override
  Widget build(BuildContext context) {
    final accentColor = context.theme.accentColor;
    return FilledButton(
      onPressed: onPressed,
      autofocus: autofocus,
      onLongPress: onLongPressed,
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.all(Colors.white),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          if (states.isDisabled) return accentColor.withAlpha(64);
          if (states.isHovered) return accentColor['lighter'];
          if (states.isFocused) return accentColor['light'];
          return accentColor['normal'];
        }),
      ),
      child: child,
    );
  }
}

class AiLibraryButton extends StatelessWidget {
  const AiLibraryButton({
    super.key,
    required this.onPressed,
    this.isSmall = false,
  });
  final void Function() onPressed;
  final bool isSmall;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Button(
        style:
            ButtonStyle(backgroundColor: WidgetStateProperty.all(Colors.black)),
        onPressed: onPressed,
        child: isSmall
            ? const Text('AI', style: TextStyle(color: Colors.white))
            : const Text('AI library', style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

enum ImproveTextSparkleButtonState { improving, improved }

class ImproveTextSparkleButton extends StatefulWidget {
  const ImproveTextSparkleButton({
    super.key,
    required this.onTextImproved,
    required this.input,
    this.onStateChange,
    this.customPromptToImprove,
  });
  final void Function(String) onTextImproved;
  final void Function(ImproveTextSparkleButtonState state)? onStateChange;
  final FutureOr<String> Function() input;

  /// By default it will use this prompt to improve the text.
  /// if null [customPromptToImprove] will be used.
  /// You need to use "`{{input}}`" to indicate where the input should be placed.
  final String? customPromptToImprove;
  static const String promptToImprove =
      '''You are very smart prompt generator for ChatGPT.
Do: improve user input to create a better prompt. It should be clear, concise, and comprehendible.
Don't: write anything except the prompt.
Optional: You can use  brackets like \${this} to indicate a variable. Example "Act as \${character}". Currently supported variables are: \${input}, \${lang}, but you can create your own.
User input to improve: """{{input}}"""
''';

  @override
  State<ImproveTextSparkleButton> createState() =>
      _ImproveTextSparkleButtonState();
}

class _ImproveTextSparkleButtonState extends State<ImproveTextSparkleButton> {
  bool isImproving = false;
  @override
  Widget build(BuildContext context) {
    return Shimmer(
      duration: const Duration(milliseconds: 600),
      colorOpacity: 0.5,
      color: context.theme.accentColor,
      enabled: isImproving,
      child: SqueareIconButton(
        icon: Icon(FluentIcons.sparkle_24_filled),
        tooltip: 'Improve',
        onTap: () async {
          try {
            if (isImproving) return;
            final provider = context.read<ChatProvider>();
            setState(() {
              isImproving = true;
            });
            widget.onStateChange?.call(ImproveTextSparkleButtonState.improving);
            final input = await widget.input();

            final improvedText = await provider.retrieveResponseFromPrompt(
              (widget.customPromptToImprove ??
                      ImproveTextSparkleButton.promptToImprove)
                  .replaceAll('{{input}}', input),
            );
            if (improvedText.isNotEmpty) {
              widget.onTextImproved(improvedText);
            }
          } catch (e) {
            logError(e.toString());
          } finally {
            widget.onStateChange?.call(ImproveTextSparkleButtonState.improved);
            if (mounted)
              setState(() {
                isImproving = false;
              });
          }
        },
      ),
    );
  }
}

class PromptLibraryButton extends StatelessWidget {
  const PromptLibraryButton({super.key});

  @override
  Widget build(BuildContext context) {
    return AiLibraryButton(
      onPressed: () async {
        final prompt = await showDialog<CustomPrompt?>(
          context: context,
          builder: (ctx) => const AiPromptsLibraryDialog(),
          barrierDismissible: true,
        );
        if (prompt != null) {
          // ignore: use_build_context_synchronously
          final controller = context.read<ChatProvider>();
          controller.editChatRoom(
            selectedChatRoomId,
            selectedChatRoom.copyWith(systemMessage: prompt.prompt),
          );
          controller.updateUI();
        }
      },
    );
  }
}

class ToggleButtonAdvenced extends StatelessWidget {
  const ToggleButtonAdvenced({
    super.key,
    this.checked = false,
    required this.icon,
    required this.onChanged,
    required this.tooltip,
    this.contextItems = const [],
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    this.maxWidthContextMenu = 200,
    this.maxHeightContextMenu = 300,
    this.shrinkWrapActions = false,
  });
  final bool checked;
  final IconData icon;
  final void Function(bool) onChanged;
  final String tooltip;
  final List<Widget> contextItems;
  final EdgeInsets padding;
  final double maxWidthContextMenu;
  final double maxHeightContextMenu;
  final bool shrinkWrapActions;

  @override
  Widget build(BuildContext context) {
    final controller = FlyoutController();
    return Tooltip(
      message: tooltip,
      child: FlyoutTarget(
        controller: controller,
        child: GestureDetector(
          onSecondaryTap: () {
            if (contextItems.isEmpty) return;
            controller.showFlyout(builder: (context) {
              return FlyoutContent(
                constraints: BoxConstraints(
                  minWidth: 64,
                  minHeight: 64,
                  maxWidth: maxWidthContextMenu,
                  maxHeight: maxHeightContextMenu,
                ),
                child: ListView(
                  shrinkWrap: shrinkWrapActions,
                  children: contextItems,
                ),
              );
            });
          },
          child: ToggleButton(
            checked: checked,
            onChanged: onChanged,
            style: ToggleButtonThemeData(
              checkedButtonStyle: ButtonStyle(
                padding: WidgetStateProperty.all(padding),
                backgroundColor: WidgetStateProperty.all(
                  context.theme.accentColor,
                ),
              ),
              uncheckedButtonStyle: ButtonStyle(
                padding: WidgetStateProperty.all(padding),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 20),
                if (contextItems.isNotEmpty)
                  const Icon(FluentIcons.chevron_down_20_regular),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class FlyoutButton extends StatelessWidget {
  const FlyoutButton({
    super.key,
    required this.icon,
    required this.tooltip,
    this.contextItems = const [],
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
    this.maxWidthContextMenu = 200,
    this.maxHeightContextMenu = 300,
    this.shrinkWrapActions = false,
  });
  final IconData icon;
  final String tooltip;
  final List<Widget> contextItems;
  final EdgeInsets padding;
  final double maxWidthContextMenu;
  final double maxHeightContextMenu;
  final bool shrinkWrapActions;

  @override
  Widget build(BuildContext context) {
    final controller = FlyoutController();
    return Tooltip(
      message: tooltip,
      child: FlyoutTarget(
        controller: controller,
        child: IconButton(
          onPressed: () {
            if (contextItems.isEmpty) return;
            controller.showFlyout(builder: (context) {
              return FlyoutContent(
                constraints: BoxConstraints(
                  minWidth: 100,
                  minHeight: 64,
                  maxWidth: maxWidthContextMenu,
                  maxHeight: maxHeightContextMenu,
                ),
                child: ListView(
                  shrinkWrap: shrinkWrapActions,
                  children: contextItems,
                ),
              );
            });
          },
          icon: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20),
              if (contextItems.isNotEmpty)
                const Icon(FluentIcons.chevron_down_20_regular),
            ],
          ),
        ),
      ),
    );
  }
}
