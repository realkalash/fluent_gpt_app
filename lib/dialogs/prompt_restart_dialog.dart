import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:window_manager/window_manager.dart';

class PromptRestartAppDialog extends StatelessWidget {
  const PromptRestartAppDialog({super.key});

  static Future<Object?> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const PromptRestartAppDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Please, restart the app to apply changes'),
      actions: [
        FilledButton(
          onPressed: () => Platform.isMacOS
              ? windowManager.destroy()
              : windowManager.close(),
          child: const Text('Restart'),
        ),
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Later (not recommended)'),
        ),
      ],
    );
  }
}
