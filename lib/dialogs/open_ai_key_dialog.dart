import 'package:fluent_gpt/providers/chat_gpt_provider.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

class OpenAiTokenDialog extends StatelessWidget {
  const OpenAiTokenDialog({super.key});
  static show(context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      dismissWithEsc: false,
      builder: (ctx) {
        return const OpenAiTokenDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ChatGPTProvider>();
    return ContentDialog(
      title: const Text('OpenAI API key'),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context),
          child: const Text('Done'),
        ),
      ],
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('OpenAI key'),
          TextBox(
            controller: provider.dialogApiKeyController,
            onChanged: (v) {
              provider.setOpenAIKeyForCurrentChatRoom(v);
            },
          ),
          const Text('OpenAI group ID (optional)'),
          TextBox(
            onChanged: (v) {
              provider.setOpenAIGroupIDForCurrentChatRoom(v);
            },
          ),
        ],
      ),
    );
  }
}
