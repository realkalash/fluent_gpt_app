import 'dart:convert';

import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/common/scrapper/web_search_result.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:http/http.dart' as http;

class OpenAiFeatures {
  // curl -X POST "https://api.openai.com/v1/chat/completions" \
  //   -H "Authorization: Bearer $OPENAI_API_KEY" \
  //   -H "Content-type: application/json" \
  //   -d '{
  //       "model": "gpt-4o-search-preview",
  //       "web_search_options": {},
  //       "messages": [{
  //           "role": "user",
  //           "content": "What was a positive news story from today?"
  //       }]
  //   }'
  // ### Output and citations
  // static const sample = {
  //   "id": "chatcmpl-e551b23b-c101-41ef-b9a0-75cc33b2d362",
  //   "object": "chat.completion",
  //   "created": 1646820005,
  //   "model": "gpt-4o-search-preview",
  //   "choices": [
  //     {
  //       "index": 0,
  //       "finish_reason": "stop",
  //       "message": {
  //         "role": "assistant",
  //         "content": "Here are the latest news updates from...",
  //         "refusal": null,
  //         "annotations": [
  //           {
  //             "type": "url_citation",
  //             "url_citation": {
  //               "end_index": 985,
  //               "start_index": 764,
  //               "title": "Page title...",
  //               "url": "https://..."
  //             }
  //           }
  //         ]
  //       },
  //     }
  //   ],
  //   "usage": {"prompt_tokens": 100, "completion_tokens": 20, "total_tokens": 120},
  //   "query": "What was a positive news story from today?"
  // };
  //

  // User location
  // To refine search results based on geography, you can specify an approximate user location using country, city, region, and/or timezone.
  //     The city and region fields are free text strings, like Minneapolis and Minnesota respectively.
  //     The country field is a two-letter ISO country code, like US.
  //     The timezone field is an IANA timezone like America/Chicago.
  // curl -X POST "https://api.openai.com/v1/chat/completions" \
  // -H "Authorization: Bearer $OPENAI_API_KEY" \
  // -H "Content-type: application/json" \
  // -d '{
  //     "model": "gpt-4o-search-preview",
  //     "web_search_options": {
  //         "user_location": {
  //             "type": "approximate",
  //             "approximate": {
  //                 "country": "GB",
  //                 "city": "London",
  //                 "region": "London"
  //             }
  //         }
  //     },
  //     "messages": [{
  //         "role": "user",
  //         "content": "What are the best restaurants around Granary Square?"
  //     }]
  // }'
  static Future<FluentChatMessage> webSearch(
    String query, {
    required String apiKey,
    String? city,
    /// low, medium, high. Higher search context sizes generally provide richer context, resulting in more accurate, comprehensive answers but answers longer
    String? searchContextSize = "medium",
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('open ai apiKey not set!');
    }

    final url = Uri.parse('https://api.openai.com/v1/chat/completions');
    final headers = {
      'Authorization': 'Bearer $apiKey',
      'Content-Type': 'application/json',
    };

    // Create web_search_options with location if city is provided
    final webSearchOptions = <String, dynamic>{};
    if (city != null && city.isNotEmpty) {
      webSearchOptions['user_location'] = {
        'type': 'approximate',
        'approximate': {
          'city': city,
        }
      };
    }
    if (searchContextSize != null) {
      webSearchOptions['search_context_size'] = searchContextSize;
    }

    final body = jsonEncode({
      'model': 'gpt-4o-search-preview',
      'web_search_options': webSearchOptions,
      'messages': [
        {
          'role': 'user',
          'content': query,
        }
      ]
    });

    try {
      final response = await http.post(url, headers: headers, body: body);

      if (response.statusCode != 200) {
        throw Exception('Failed to perform web search: ${response.body}');
      }

      final jsonResponse = jsonDecode(response.body);
      final choices = jsonResponse['choices'] as List<dynamic>;

      if (choices.isEmpty) {
        return FluentChatMessage.ai(
          id: FluentChatMessage.generateId(),
          content: "No results found for your query".tr,
          creator: 'openai search',
          timestamp: DateTime.now().millisecondsSinceEpoch,
        );
      }

      final messageData = choices[0]['message'];
      final content = messageData['content'] as String;
      final annotations = messageData['annotations'] as List<dynamic>?;

      final results = <WebSearchResult>[];

      if (annotations != null) {
        for (final annotation in annotations) {
          if (annotation['type'] == 'url_citation') {
            final citation = annotation['url_citation'];
            results.add(WebSearchResult(
              title: citation['title'] ?? '',
              url: citation['url'] ?? '',
              description: content.substring(
                citation['start_index'] as int,
                citation['end_index'] as int,
              ),
              favicon: null, // API doesn't provide favicon
            ));
          }
        }
      }
      final id = DateTime.now().millisecondsSinceEpoch;
      return FluentChatMessage(
        id: id.toString(),
        content: content,
        creator: 'openai search',
        timestamp: id,
        type: FluentChatMessageType.webResult,
        tokens: jsonResponse['usage']?['total_tokens'] ?? 0,
        webResults: results,
      );
    } catch (e) {
      throw Exception('Error performing web search: $e');
    }
  }
}
