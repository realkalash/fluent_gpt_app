import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class WebScraper {

  WebScraper();

  Future<List<SearchResult>> search(String query) async {
    final url = Uri.parse('https://api.search.brave.com/res/v1/web/search?q=${Uri.encodeComponent(query)}&format=json');
    
    final response = await http.get(
      url,
      headers: {
        'Accept': 'application/json',
        'X-Subscription-Token': AppCache.braveSearchApiKey.value ?? '',
      },
    );

    if (response.statusCode == 200) {
      final jsonResponse = json.decode(response.body);
      final results = jsonResponse['web']['results'] as List;
      return results.map((result) => SearchResult.fromJson(result)).toList();
    } else {
      throw Exception('Failed to perform search: ${response.statusCode}');
    }
  }

  Future<String> scrapeWebsite(String url) async {
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      // For simplicity, we're just returning the raw HTML content
      // You may want to parse this HTML and extract specific information
      return response.body;
    } else {
      throw Exception('Failed to load webpage');
    }
  }
}
class SearchResult {
  final String title;
  final String url;
  final String description;
  final String? favicon;

  SearchResult({
    required this.title,
    required this.url,
    required this.description,
    this.favicon,
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      description: json['description'] ?? '',
      favicon: json['favicon'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'url': url,
      'description': description,
      'favicon': favicon,
    };
  }
}
