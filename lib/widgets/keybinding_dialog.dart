import 'package:fluent_gpt/widgets/custom_buttons.dart';
import 'package:fluent_gpt/widgets/wiget_constants.dart';
import 'package:fluent_ui/fluent_ui.dart';
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
  @override
  void initState() {
    hotKey = widget.initHotkey;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: widget.title ?? const Text('Choose a hotkey'),
      constraints: const BoxConstraints(maxWidth: 400, maxHeight: 280),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(widget.initHotkey),
          child: const Text('Cancel'),
        ),
        canApply
            ? Button(onPressed: apply, child: const Text('Apply'))
            : const FilledRedButton(child: Text('Apply')),
      ],
      content: Center(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (hotKey == null)
              const Text(
                  'Press a key combination to set a new hotkey (escape to cancel)'),
            const Text('Current hotkey:'),
            spacer,
            HotKeyRecorder(
              onHotKeyRecorded: (v) async {
                if (v.physicalKey == PhysicalKeyboardKey.escape) {
                  cancel();
                  return;
                }
                final listHotKeys = HotKeyManager.instance.registeredHotKeyList;
                final pressedKey = v.debugName;
                if (listHotKeys.any((element) => element.debugName == pressedKey)) {
                  canApply = false;
                } else {
                  canApply = true;
                }
                setState(() {
                  hotKey = v;
                });
              },
              initalHotKey: hotKey,
            ),
            if (!canApply)
              Text(
                'This hotkey is already in use',
                style: TextStyle(color: Colors.red),
              ),
          ],
        ),
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
