
import 'dart:io';

import 'package:fluent_gpt/common/prompts_templates.dart';
import 'package:fluent_gpt/dialogs/ai_prompts_library_dialog.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/pages/new_settings_page.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/custom_list_tile.dart';
import 'package:fluent_gpt/widgets/input_field/input_field.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as ic;

OverlayEntry? aliasesCommandsOverlay;
List<String> quickInputCommandsList = [
  // ...AliasesOverlay.quickInputDefaultCommands,
];
void removeInputFieldQuickCommandsOverlay() {
  if (aliasesCommandsOverlay != null) {
    quickInputCommandsList.clear();
    aliasesCommandsOverlay!.remove();
    aliasesCommandsOverlay!.dispose();
    aliasesCommandsOverlay = null;
  }
}

class AliasesOverlay extends StatefulWidget {
  const AliasesOverlay({super.key});
  static List<String> quickInputDefaultCommands = [
    '/settings',
    '/${TrayCommand.generate_image.name}',
  ];
  @override
  State<AliasesOverlay> createState() => _AliasesOverlayState();
}

class _AliasesOverlayState extends State<AliasesOverlay> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ChatProvider.messageControllerGlobal.addListener(onTextChangedListener);
      escPressedStream.listen(onEscPressedListener);
      loadAllCommands();
    });
  }

  void onEscPressedListener(bool isPressed) {
    if (isPressed) {
      removeInputFieldQuickCommandsOverlay();
    }
  }

  void loadAllCommands() {
    final allPrompts = promptsLibrary.map((e) => e.title).toList();
    final allCustomPrompts = customPrompts.value.map((e) => e.title).toList();
    quickInputAllCommands.clear();
    quickInputAllCommands.addAll(AliasesOverlay.quickInputDefaultCommands);
    quickInputAllCommands.addAll(allCustomPrompts);
    quickInputAllCommands.addAll(allPrompts);
    quickInputCommandsList.addAll(quickInputAllCommands);
    setState(() {});
  }

  @override
  void dispose() {
    ChatProvider.messageControllerGlobal.removeListener(onTextChangedListener);
    super.dispose();
  }

  void onTextChangedListener() {
    final text = ChatProvider.messageControllerGlobal.text;
    if (text.isEmpty) {
      return;
    }
    quickInputCommandsList.clear();
    if (text.length == 1 && text[0] == '/') {
      quickInputCommandsList.clear();
      loadAllCommands();
      return;
    }
    final clearTextLowerCase = text.trim().toLowerCase().replaceAll('/', '');
    for (final command in quickInputAllCommands) {
      final clearTextWords = clearTextLowerCase.split(' ');
      for (final word in clearTextWords) {
        if (word.isEmpty) continue;
        if (command.toLowerCase().contains(word)) {
          quickInputCommandsList.add(command);
          break;
        }
      }
    }
    if (quickInputCommandsList.isNotEmpty) {
      setState(() {});
    }
  }

  List<String> quickInputAllCommands = [
    ...AliasesOverlay.quickInputDefaultCommands,
  ];

  @override
  Widget build(BuildContext context) {
    final isMainWindow = overlayVisibility.value == OverlayStatus.disabled;
    final theme = FluentTheme.of(context);
    return Positioned(
      bottom: isMainWindow ? 86 : null,
      top: isMainWindow ? null : 86,
      left: 60,
      right: 60,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 300),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
        child: Acrylic(
          blurAmount: 10,
          tint: Colors.black,
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: Tooltip(
                      message: 'Close',
                      child: SizedBox(
                        child: Button(
                          onPressed: () {
                            quickInputCommandsList.clear();
                            quickInputAllCommands.clear();
                            removeInputFieldQuickCommandsOverlay();
                          },
                          style: const ButtonStyle(
                            padding: WidgetStatePropertyAll(EdgeInsets.all(4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(ic.FluentIcons.arrow_down_16_filled, size: 16),
                              Text('[esc]'),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Flexible(
                  fit: FlexFit.loose,
                  child: ListView.builder(
                    itemCount: quickInputCommandsList.length,
                    shrinkWrap: true,
                    itemBuilder: (context, i) {
                      final command = quickInputCommandsList[i];
                      bool isHovered = false;
                      return StatefulBuilder(
                        builder: (
                          BuildContext context,
                          void Function(void Function()) setState,
                        ) {
                          return MouseRegion(
                            onHover: (event) {
                              setState(() {
                                isHovered = true;
                              });
                            },
                            onExit: (event) {
                              setState(() {
                                isHovered = false;
                              });
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: BasicListTile(
                                title: Text(command),
                                color: isHovered ? theme.accentColor.withAlpha(51) : Colors.black.withAlpha(26),
                                padding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
                                onTap: () async {
                                  final isGlobalCommand = command[0] == '/';
                                  if (!isGlobalCommand) {
                                    var prompt = promptsLibrary.firstWhereOrNull(
                                      (element) => element.title == command,
                                    );
                                    prompt ??= customPrompts.value.firstWhereOrNull(
                                      (element) => element.title == command,
                                    );
                                    if (prompt == null) return;
                                    final isContainsPlaceHolder = placeholdersRegex.hasMatch(prompt.getPromptText());
                                    if (isContainsPlaceHolder) {
                                      final newText = await showDialog<String>(
                                        context: context,
                                        builder: (context) => ReplaceAllPlaceHoldersDialog(
                                          originalText: prompt!.getPromptText(),
                                        ),
                                      );
                                      if (newText != null) {
                                        ChatProvider.messageControllerGlobal.text = newText;
                                      }
                                    } else {
                                      ChatProvider.messageControllerGlobal.text = '${prompt.getPromptText()} ';
                                    }
                                    removeInputFieldQuickCommandsOverlay();
                                    promptTextFocusNode.requestFocus();
                                    return;
                                  }
                                  if (command == '/settings') {
                                    Navigator.of(context).push(
                                      FluentPageRoute(
                                        builder: (context) => const NewSettingsPage(),
                                      ),
                                    );
                                  } else {
                                    ChatProvider.messageControllerGlobal.text = '$command ';
                                    promptTextFocusNode.requestFocus();
                                    removeInputFieldQuickCommandsOverlay();
                                  }
                                },
                                trailing: i < 9
                                    ? Button(
                                        onPressed: null,
                                        focusable: false,
                                        child: Platform.isMacOS ? Text('⌘${i + 1}') : Text('[ctrl+${i + 1}]'),
                                      )
                                    : null,
                              ),
                            ),
                          );
                        },
                      );
                    },
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
