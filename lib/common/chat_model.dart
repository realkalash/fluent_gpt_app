class ChatModelAi {
  final String apiKey;
  final String name;

  ChatModelAi({this.apiKey = '', required this.name});

  static ChatModelAi fromJson(Map<String, dynamic> json) {
    return ChatModelAi(apiKey: json['apiKey'], name: json['name']);
  }

  Map<String, dynamic> toJson() {
    return {
      'apiKey': apiKey,
      'name': name,
    };
  }
}
