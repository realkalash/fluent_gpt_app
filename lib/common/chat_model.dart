class ChatModelAi {
  final String apiKey;
  final String name;
  final String? ownedBy;

  const ChatModelAi({this.apiKey = '', required this.name, this.ownedBy});

  static ChatModelAi fromJson(Map<String, dynamic> json) {
    return ChatModelAi(
      apiKey: json['apiKey'],
      name: json['name'],
      ownedBy: json['ownedBy'],
    );
  }

  static ChatModelAi fromServerJson(Map<String, dynamic> json,
      {String apiKey = ''}) {
    // ['id'] -> '"id" -> "LWDCLS/DarkIdol-Llama-3.1-8B-Instruct-1.2-Uncensored-GGUF-IQ-Imatrix-Request/DarkIdol-Llama-3.1-8B-Instruct-1.2-Uncensored-Q4_K_…"'
    // ['object'] -> 'model'
    // ['owned_by'] -> 'lm_studio'
    return ChatModelAi(
      apiKey: json['apiKey'] ?? apiKey,
      name: json['id'],
      ownedBy: json['owned_by'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'apiKey': apiKey,
      'name': name,
      'ownedBy': ownedBy,
    };
  }

  @override
  String toString() {
    return '{"name": "$name", "ownedBy": "$ownedBy"}';
  }
}
