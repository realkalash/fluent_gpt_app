import 'package:fluent_gpt/common/scrapper/web_scrapper.dart';
import 'package:langchain/langchain.dart';

class WebResultCustomMessage extends CustomChatMessage {
  const WebResultCustomMessage({
    required super.content,
    required this.searchResults,
  }) : super(role: defaultPrefix);
  static const String defaultPrefix = 'webResult';

  final List<SearchResult> searchResults;

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
          .map((e) => SearchResult.fromJson(e))
          .toList(),
    );
  }
}