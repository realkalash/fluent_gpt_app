import 'package:fluent_gpt/common/scrapper/web_search_result.dart';
import 'package:langchain/langchain.dart';

class WebResultCustomMessage extends CustomChatMessage {
  const WebResultCustomMessage({
    required super.content,
    required this.searchResults,
  }) : super(role: defaultPrefix);
  static const String defaultPrefix = 'webResult';

  final List<WebSearchResult> searchResults;

  Map<String, Object> toJson() {
    return {
      'role': role,
      'content': content,
      'searchResults': searchResults.map((e) => e.toJson()).toList(),
    };
  }

  static WebResultCustomMessage fromJson(Map<String, dynamic> json) {
    return WebResultCustomMessage(
      content: json['content'],
      searchResults: (json['searchResults'] as List? ?? [])
          .map((e) => WebSearchResult.fromJson(e))
          .toList(),
    );
  }
}
