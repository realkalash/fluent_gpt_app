import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/widgets/custom_buttons.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;

class ToolCallingNotSupportedDialog extends StatelessWidget {
  const ToolCallingNotSupportedDialog({
    super.key,
  });

  static Future<Object?> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const ToolCallingNotSupportedDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      content: const Text(
          'Tool calling is not supported for model. Please use different model or disable all tools'),
      actions: [
        FilledRedButton(
            child: Text('Disable tools'),
            onPressed: () {
              AppCache.gptToolCopyToClipboardEnabled.set(false);
              Navigator.of(context).pop();
            }),
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        )
      ],
    );
  }
}

class MultimodalNotSupportedDialog extends StatelessWidget {
  const MultimodalNotSupportedDialog({super.key});

  static Future<Object?> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const MultimodalNotSupportedDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      content: const Text(
          'Multimodal is not supported for model. Please use different model.'),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        )
      ],
    );
  }
}
