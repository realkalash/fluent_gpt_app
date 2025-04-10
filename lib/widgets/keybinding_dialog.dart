import 'dart:io';

import 'package:fluent_gpt/common/custom_prompt.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:fluent_gpt/widgets/custom_buttons.dart';
import 'package:fluent_gpt/widgets/custom_list_tile.dart';
import 'package:fluent_gpt/widgets/wiget_constants.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

class KeybindingDialog extends StatefulWidget {
  const KeybindingDialog({super.key, this.initHotkey, this.title});
  final HotKey? initHotkey;
  final Widget? title;

  static Future<HotKey?> show(
    BuildContext context, {
    HotKey? initHotkey,
    Widget? title,
  }) {
    return showDialog<HotKey>(
      context: context,
      builder: (context) => KeybindingDialog(
        initHotkey: initHotkey,
        title: title,
      ),
    );
  }

  @override
  State<KeybindingDialog> createState() => _KeybindingDialogState();
}

class _KeybindingDialogState extends State<KeybindingDialog> {
  HotKey? hotKey;
  bool canApply = true;
  List<HotKey> listUsedHotkeys = [];
  List<CustomPrompt> prompts = <CustomPrompt>[];

  @override
  void initState() {
    hotKey = widget.initHotkey;
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      updateListHotkeys();
    });
  }

  Future updateListHotkeys() async {
    if (Platform.isMacOS == false) {
      listUsedHotkeys = HotKeyManager.instance.registeredHotKeyList;
    } else {
      // we need to manually get all hotkeys
      listUsedHotkeys.clear();
      prompts = customPrompts.valueOrNull ?? [];
      // final fileString = await AppCache.promptsLibrary.value();

      // if (fileString.isEmpty) {
      //   prompts.addAll(promptsLibrary);
      // } else {
      //   final decoded = jsonDecode(fileString) as List;
      //   prompts = decoded.map((e) => CustomPrompt.fromJsonString(e)).toList();
      // }
      for (var value in prompts) {
        if (value.hotkey != null) {
          listUsedHotkeys.add(value.hotkey!);
        }
      }
      // some native macOS hotkeys
      listUsedHotkeys.addAll([
        openWindowHotkey,
        openSearchOverlayHotkey,
        createNewChat,
        resetChat,
        showOverlayForText,
        if (takeScreenshot != null) takeScreenshot!,
        if (pttScreenshotKey != null) pttScreenshotKey!,
        if (pttKey != null) pttKey!,
      ]);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: widget.title ?? Text('Choose a hotkey'.tr),
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(widget.initHotkey),
          child: Text('Cancel'.tr),
        ),
        canApply
            ? Button(onPressed: apply, child: Text('Apply'.tr))
            : FilledRedButton(child: Text('Apply'.tr)),
      ],
      content: ListView(
        shrinkWrap: true,
        children: [
          if (hotKey == null)
            Text(
                'Press a key combination to set a new hotkey (escape to cancel)'
                    .tr),
          Row(
            children: [
              Text('Current hotkey:'.tr),
              const SizedBox(width: 8),
              HotKeyRecorder(
                onHotKeyRecorded: (pressedKey) async {
                  if (pressedKey.physicalKey == PhysicalKeyboardKey.escape) {
                    cancel();
                    return;
                  }

                  if (Platform.isMacOS == false) {
                    if (listUsedHotkeys.any((element) {
                      final contains =
                          element.identifier == pressedKey.identifier &&
                              element.modifiers == pressedKey.modifiers;
                      if (contains) {
                        log('Hotkey already in use: ${element.debugName}. pressedKey: ${pressedKey.debugName}');
                      }
                      return contains;
                    })) {
                      canApply = false;
                    } else {
                      canApply = true;
                    }
                  }
                  setState(() {
                    hotKey = pressedKey;
                  });
                },
                initalHotKey: hotKey,
              ),
            ],
          ),
          if (!canApply)
            Row(
              children: [
                Expanded(
                  child: Text(
                    'This hotkey is already in use'.tr,
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          spacer,
          Divider(),
          spacer,
          ListTile(
            title: Text('Hotkeys in use (click for details)'.tr),
            onPressed: () {
              showDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (ctx) {
                    return ContentDialog(
                      title: Text('Hotkeys in use'.tr),
                      content: ListView(
                        shrinkWrap: true,
                        children: listUsedHotkeys.map((e) {
                          final stringBuilder = StringBuffer();
                          if (e.modifiers != null && e.modifiers!.isNotEmpty) {
                            for (var element in e.modifiers!) {
                              stringBuilder.write(element
                                  .toString()
                                  .replaceAll('HotKeyModifier.', ''));
                              stringBuilder.write(' + ');
                            }
                            stringBuilder.write(e.physicalKey.keyLabel);
                          } else {
                            stringBuilder.write(e.physicalKey.keyLabel);
                          }

                          return BasicListTile(
                            title: Text(
                              stringBuilder.toString(),
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Divider(),
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            color: Colors.transparent,
                          );
                        }).toList(),
                      ),
                      actions: [
                        Button(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: Text('Close'.tr),
                        ),
                      ],
                    );
                  });
            },
            trailing: Icon(FluentIcons.question_circle_20_filled),
          ),
        ],
      ),
    );
  }

  void cancel() {
    setState(() {
      hotKey = widget.initHotkey;
    });
  }

  void apply() {
    Navigator.of(context).pop(hotKey);
  }
}
