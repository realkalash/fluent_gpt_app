import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/widgets/markdown_builders/markdown_utils.dart';
import 'package:fluent_ui/fluent_ui.dart';

class HowToRunLocalModelsDialog extends StatelessWidget {
  const HowToRunLocalModelsDialog({super.key});
  static const instructions = '''
### Instructions to Run the Script
0. Download the gguf model

1. Install the required dependencies (requires ~200 MB):
```bash
pip install flask transformers torch
```

3. Tap 'Add a new model' in the app and select the gguf model.
4. Click on the 'Run' button to run the model.
''';

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('How to run local models'),
      constraints: const BoxConstraints(
        minWidth: 400,
        maxHeight: 600,
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'.tr),
        ),
      ],
      content: ListView(
        children: [
          buildMarkdown(
            context,
            instructions,
            language: null,
            textSize: 16,
          ),
        ],
      ),
    );
  }
}
