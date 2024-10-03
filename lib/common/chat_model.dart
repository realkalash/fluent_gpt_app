// ignore_for_file: constant_identifier_names

import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class ChatModelAi {
  final String apiKey;
  final String customName;
  final String modelName;
  final String? ownedBy;

  /// Can be path or Url
  final String? uri;

  const ChatModelAi({
    this.apiKey = '',
    required this.modelName,
    this.ownedBy,
    this.uri,
    this.customName = '',
  });

  Widget get modelIcon {
    if (ownedBy == 'openai') {
      return Image.asset(
        'assets/openai_icon.png',
        fit: BoxFit.contain,
      );
    }
    return const Icon(FluentIcons.chat_24_regular);
  }

  static ChatModelAi fromJson(Map<String, dynamic> json) {
    return ChatModelAi(
      apiKey: json['apiKey'],
      modelName: json['name'],
      ownedBy: json['ownedBy'],
      uri: json['uri'],
      customName: json['customName'] ?? 'Custom',
    );
  }

  static ChatModelAi fromServerJson(
    Map<String, dynamic> json, {
    String apiKey = '',
    required String url,
  }) {
    // ['id'] -> '"id" -> "LWDCLS/DarkIdol-Llama-3.1-8B-Instruct-1.2-Uncensored-GGUF-IQ-Imatrix-Request/DarkIdol-Llama-3.1-8B-Instruct-1.2-Uncensored-Q4_K_…"'
    // ['object'] -> 'model'
    // ['owned_by'] -> 'lm_studio'\
    // ['uri'] -> 'C://Users//User//Desktop//DarkIdol-Llama-3.1-8B-Instruct-1.2-Uncensored-GGUF-IQ-Imatrix-Request'
    // or
    // ['uri'] -> 'https://api.openai.com/v1'
    return ChatModelAi(
      apiKey: json['apiKey'] ?? apiKey,
      modelName: json['id'],
      ownedBy: json['owned_by'],
      uri: url,
      customName: json['customName'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'apiKey': apiKey,
      'name': modelName,
      'ownedBy': ownedBy,
      'uri': uri,
      'customName': customName,
    };
  }

  @override
  String toString() {
    return '{"name": "$modelName", "ownedBy": "$ownedBy", "uri": "$uri"}';
  }

  ChatModelAi copyWith({
    String? apiKey,
    String? modelName,
    String? ownedBy,
    String? uri,
    String? customName,
  }) {
    return ChatModelAi(
      apiKey: apiKey ?? this.apiKey,
      modelName: modelName ?? this.modelName,
      ownedBy: ownedBy ?? this.ownedBy,
      uri: uri ?? this.uri,
      customName: customName ?? this.customName,
    );
  }
}

enum OwnedByEnum {
  openai,
  lm_studio,
  gemini,
  claude,
  custom,
}
