import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/pages/settings_page.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_gpt_tokenizer/flutter_gpt_tokenizer.dart';

class InfoAboutUserDialog extends StatefulWidget {
  const InfoAboutUserDialog({super.key});

  @override
  State<InfoAboutUserDialog> createState() => _InfoAboutUserDialogState();
}

class _InfoAboutUserDialogState extends State<InfoAboutUserDialog> {
  final textController = TextEditingController();
  int tokens = 0;
  int words = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      textController.text = await AppCache.userInfo.value() ?? '';
      if (mounted) {
        words = textController.text.split(' ').length;
        Tokenizer tokenizer = Tokenizer();
        tokens = await tokenizer.count(textController.text, modelName: 'gpt-4');
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('User Info'),
      constraints: const BoxConstraints(maxWidth: 800),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'This information is stored locally on your device and is not shared with anyone.',
          ),
          const SizedBox(height: 10),
          TextFormBox(
            controller: textController,
            placeholder: 'Information will appear here',
            maxLines: 50,
            onTapOutside: (_) {
              FocusScope.of(context).unfocus();
              words = textController.text.split(' ').length;
              Tokenizer tokenizer = Tokenizer();
              tokenizer.count(textController.text, modelName: 'gpt-4').then((value) {
                tokens = value;
                setState(() {});
              });
            },
          ),
          Row(
            children: [
              CaptionText('Words: $words, Tokens: $tokens'),
              IconButton(
                icon: const Icon(FluentIcons.refresh),
                onPressed: () {
                  words = textController.text.split(' ').length;
                  Tokenizer tokenizer = Tokenizer();
                  tokenizer.count(textController.text, modelName: 'gpt-4').then((value) {
                    tokens = value;
                    setState(() {});
                  });
                },
              ),
            ],
          ),
        ],
      ),
      actions: [
        // submit
        FilledButton(
          onPressed: () async {
            await AppCache.userInfo.set(textController.text);
            // ignore: use_build_context_synchronously
            Navigator.of(context).pop();
          },
          child: const Text('Save'),
        ),
        Button(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Close'),
        ),
      ],
    );
  }
}
