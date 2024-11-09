import 'package:fluent_gpt/system_messages.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_gpt_tokenizer/flutter_gpt_tokenizer.dart';

class GlobalSystemPromptSampleDialog extends StatefulWidget {
  const GlobalSystemPromptSampleDialog({super.key});

  @override
  State<GlobalSystemPromptSampleDialog> createState() =>
      _GlobalSystemPromptSampleDialogState();
}

class _GlobalSystemPromptSampleDialogState
    extends State<GlobalSystemPromptSampleDialog> {
  String systemPrompt = '';
  int wordsCount = 0;
  int tokensCount = 0;

  Future<void> countWordsAndTokens(String prompt) async {
    final words = prompt.split(' ');
    wordsCount = words.length;
    final tokenizer = Tokenizer();
    tokensCount = await tokenizer.count(prompt, modelName: 'gpt-4');
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      systemPrompt = await getFormattedSystemPrompt(basicPrompt: defaultGlobalSystemMessage);
      await countWordsAndTokens(systemPrompt);
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Global System Prompt'),
      constraints: const BoxConstraints(maxWidth: 800),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This is a full system prompt that will be sent to every new chat room as first system message'),
            Card(
              child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: SelectableText(systemPrompt)),
            ),
            Text('Words: $wordsCount, Tokens: $tokensCount'),
          ],
        ),
      ),
      actions: [
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
