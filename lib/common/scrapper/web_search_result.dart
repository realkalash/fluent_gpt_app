class WebSearchResult {
  final String title;
  final String url;
  final String description;
  final String? favicon;

  WebSearchResult({
    required this.title,
    required this.url,
    required this.description,
    this.favicon,
  });

  factory WebSearchResult.fromJson(Map<String, dynamic> json) {
    final favicon = json['favicon'] as String? ?? json['thumbnail']?['src'];
    return WebSearchResult(
      title: json['title'] ?? '',
      url: json['url'] ?? '',
      description: json['description'] ?? '',
      favicon: favicon,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': 'scrapper_result',
      'title': title,
      'url': url,
      'description': description,
      'favicon': favicon,
    };
  }
}
