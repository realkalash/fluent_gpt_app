import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:langchain/langchain.dart';

class SearchChatDialog extends StatefulWidget {
  const SearchChatDialog({super.key, required this.query});
  final String query;

  @override
  State<SearchChatDialog> createState() => _SearchChatDialogState();
}

class _SearchChatDialogState extends State<SearchChatDialog> {
  final Map<String, FluentChatMessage> _messages = {};
  final textController = TextEditingController();
  @override
  void initState() {
    textController.text = widget.query;
    super.initState();
  }

  void search() {
    final originalMessages = messages.value;
    _messages.clear();
    for (final entry in originalMessages.entries) {
      final message = entry.value;
      if (message.isTextMessage) {
        if (message.content
            .toLowerCase()
            .contains(textController.text.toLowerCase())) {
          _messages[entry.key] = message;
        }
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Search in chat'),
      constraints: const BoxConstraints(maxWidth: 600, maxHeight: 1200),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          TextBox(
            autocorrect: true,
            autofocus: true,
            controller: textController,
            placeholder: 'Search...',
            onChanged: (value) => search(),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final element = _messages.entries.elementAt(index);
                final message = element.value;
                if (message is CustomChatMessage) {
                  return const SizedBox.shrink();
                }
                if (message is HumanChatMessage &&
                    message.content is ChatMessageContentImage) {
                  return const SizedBox.shrink();
                }
                final words = message.content.split(' ');
                return MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pop(element.key);
                    },
                    child: Card(
                      margin: const EdgeInsets.all(4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (message is HumanChatMessage) const Text('Human'),
                          if (message is AIChatMessage) const Text('AI'),
                          Text.rich(
                            TextSpan(
                              children: [
                                for (final word in words)
                                  TextSpan(
                                    text: '$word ',
                                    style: TextStyle(
                                      backgroundColor: word
                                              .toLowerCase()
                                              .contains(textController.text
                                                  .toLowerCase())
                                          ? Colors.yellow.withAlpha(127)
                                          : null,
                                      // color: word.toLowerCase().contains(
                                      //         textController.text.toLowerCase())
                                      //     ? Colors.black
                                      //     : null,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Dismiss'),
        ),
      ],
    );
  }
}
