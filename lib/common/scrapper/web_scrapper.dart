import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/common/scrapper/web_search_result.dart';
import 'package:fluent_gpt/log.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:html/parser.dart' show parse;
import 'package:html/dom.dart';

class WebScraper {
  WebScraper();

  Future<List<WebSearchResult>> search(String query) async {
    final url = Uri.parse(
        'https://api.search.brave.com/res/v1/web/search?q=${Uri.encodeComponent(query)}&format=json');
    log('searching for $query');

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
      return results.map((result) => WebSearchResult.fromJson(result)).toList();
    } else {
      throw Exception('Code:${response.statusCode}; Error:${response.body}');
    }
  }

  /// Scrapes the content of a web page and returns it as a string.
  /// returns only the text content of the page, excluding any script or style elements.
  Future<String> extractFormattedContent(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        throw Exception('Failed to load page');
      }

      final document = parse(response.body);

      // Remove unwanted elements
      final elementsToRemove = [
        'header',
        'footer',
        'nav',
        'aside',
        'script',
        'style',
        'noscript',
        'iframe'
      ];
      document
          .querySelectorAll(elementsToRemove.join(', '))
          .forEach((element) => element.remove());

      // Find the main content (you might need to adjust this selector based on the websites you're scraping)
      final mainContent = document.querySelector('main') ??
          document.querySelector('article') ??
          document.body;
      if (mainContent == null) return '';

      return _extractFormattedTextFromElement(mainContent);
    } catch (e) {
      return e.toString();
    }
  }

  String _extractFormattedTextFromElement(Element element) {
    final buffer = StringBuffer();
    final blockElements = [
      'p',
      'div',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
      'ul',
      'ol',
      'li',
      'blockquote'
    ];

    for (var node in element.nodes) {
      if (node is Text) {
        var text = node.text.trim();
        if (text.isNotEmpty) {
          buffer.write(text);
          if (!text.endsWith(' ')) buffer.write(' ');
        }
      } else if (node is Element) {
        var tagName = node.localName?.toLowerCase() ?? '';

        if (blockElements.contains(tagName)) {
          if (buffer.isNotEmpty && !buffer.toString().endsWith('\n')) {
            buffer.write('\n');
          }
        }

        buffer.write(_extractFormattedTextFromElement(node));

        if (blockElements.contains(tagName)) {
          buffer.write('\n');
        }
      }
    }

    return buffer.toString().trim();
  }

  static String clearTextFromTags(String htmlText) {
    final document = parse(htmlText);
    return document.body?.text ?? '';
  }
}

