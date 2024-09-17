import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

class AnswerWithTagsDialog extends StatelessWidget {
  const AnswerWithTagsDialog({super.key, required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Answer with tags'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              children: [
                const Text('Your message:'),
                Card(child: Text(text)),
              ],
            ),
          ),
          const Text('Quick Tags:'),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Button(
                  onPressed: () => answerWithTags(context, text, 'Yes'),
                  child: const Text('Answer Yes'),
                ),
                Button(
                  onPressed: () => answerWithTags(context, text, 'No'),
                  child: const Text('Answer No'),
                ),
                Button(
                  onPressed: () => answerWithTags(context, text, 'Explain please'),
                  child: const Text('Answer Explain please'),
                ),
              ],
            ),
          ),
          TextBox(
            autofocus: true,
            placeholder: 'Type your tags here (e.g. yes, no, explain)',
            onSubmitted: (value) {
              if (value.trim().isEmpty) {
                return;
              }
              answerWithTags(context, text, value);
            },
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  static void answerWithTags(BuildContext context, String text, String tags) {
    final chatProvider = context.read<ChatProvider>();
    final formattedText = text.trim();
    final formattedTags = tags.trim();
    chatProvider.sendMessage(
      'Based on the text message: "$formattedText" '
      'and within the context defined by these tags: '
      '"$formattedTags", '
      'please provide an answer like you a real human.',
      false,
    );
    Navigator.of(context).pop();
  }
}
