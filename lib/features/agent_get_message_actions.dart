import 'dart:convert';

import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/common/custom_prompt.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:nanoid2/nanoid2.dart';

class AgentGetMessageActions {
  final ChatProvider _chatProvider;

  AgentGetMessageActions(this._chatProvider);

  int getRandId() {
    final rand = nanoid(length: 5, alphabet: Alphabet.numbers);
    return int.parse(rand);
  }

  static const String systemPrompt =
      "You are an agent. You answer will be used to generate a buttons with helper prompts of what user might ask/message next, so DON'T WRITE COMMENTS"
      "Write ONLY in JSON format like this: [\"What is the purpose?\", \"How I can implement this?\", \"That's very funny! Thanks\"]";

  Future<List<CustomPrompt>> askForPromptsFromLLM(
      String userContent, String content) async {
    String response = await _chatProvider.retrieveResponseFromPrompt(
      systemPrompt,
      additionalPreMessages: [
        FluentChatMessage.humanText(id: '0', content: userContent),
        FluentChatMessage.ai(id: '1', content: content),
      ],
    );

    final parsed = _parseResponse(response);
    return parsed;
  }

  List<CustomPrompt> _parseResponse(String response) {
    final trimAndClear = response.trim().removeWrappedQuotes;
    final regex = RegExp(r"\[.*\]",dotAll: true);
    // we should have only one match
    if (regex.hasMatch(trimAndClear)) {
      final match = regex.firstMatch(trimAndClear);
      final json = match?.group(0);
      if (json != null) {
        final List<dynamic> prompts = jsonDecode(json);
        return prompts
            .map(
              (e) => CustomPrompt(
                id: getRandId(),
                title: e.toString(),
                prompt: e.toString(),
              ),
            )
            .toList();
      }
    }
    return const [];
  }
}
