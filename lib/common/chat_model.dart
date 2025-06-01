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
  final bool imageSupported;
  final bool reasoningSupported;
  final bool toolSupported;
  final int index;

  const ChatModelAi({
    this.apiKey = '',
    required this.modelName,
    this.ownedBy,
    this.uri,
    this.customName = '',
    this.imageSupported = false,
    this.index = 0,
    this.reasoningSupported = false,
    this.toolSupported = false,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ChatModelAi &&
        other.apiKey == apiKey &&
        other.modelName == modelName &&
        other.ownedBy == ownedBy &&
        other.uri == uri;
  }

  @override
  int get hashCode {
    return apiKey.hashCode ^
        modelName.hashCode ^
        ownedBy.hashCode ^
        uri.hashCode;
  }

  Widget get modelIcon {
    if (ownedBy == OwnedByEnum.openai.name) {
      return Image.asset(
        'assets/openai_icon.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
    }
    if (ownedBy == OwnedByEnum.lm_studio.name) {
      return Image.asset(
        'assets/lmstudio_icon.png',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
    }
    if (ownedBy == OwnedByEnum.deepinfra.name) {
      return Image.asset(
        'assets/deepinfra_icon.webp',
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
      );
    }
    return const Icon(FluentIcons.chat_24_regular);
  }

  static ChatModelAi fromJson(Map<String, dynamic> json) {
    return ChatModelAi(
      apiKey: json['apiKey'],
      modelName: json['name'],
      ownedBy: json['ownedBy'] ?? OwnedByEnum.custom.name,
      uri: json['uri'],
      customName: json['customName'] ?? 'Custom',
      imageSupported: json['imageSupported'] ?? false,
      reasoningSupported: json['reasoningSupported'] ?? false,
      toolSupported: json['toolSupported'] ?? false,
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
      imageSupported: json['imageSupported'] ?? false,
      index: json['i'] ?? 0,
      reasoningSupported: json['reasoningSupported'] ?? false,
      toolSupported: json['toolSupported'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'apiKey': apiKey,
      'name': modelName,
      'ownedBy': ownedBy,
      'uri': uri,
      'customName': customName,
      'imageSupported': imageSupported,
      'i': index,
      'reasoningSupported': reasoningSupported,
      'toolSupported': toolSupported,
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
    bool? imageSupported,
    int? index,
    bool? reasoningSupported,
    bool? toolSupported,
  }) {
    return ChatModelAi(
      apiKey: apiKey ?? this.apiKey,
      modelName: modelName ?? this.modelName,
      ownedBy: ownedBy ?? this.ownedBy,
      uri: uri ?? this.uri,
      customName: customName ?? this.customName,
      imageSupported: imageSupported ?? this.imageSupported,
      index: index ?? this.index,
      reasoningSupported: reasoningSupported ?? this.reasoningSupported,
      toolSupported: toolSupported ?? this.toolSupported,
    );
  }

  ChatModelProviderBase getChatModelProviderBase() {
    for (var element in ChatModelProviderBase.providersList) {
      if (element.ownedBy.name == ownedBy) {
        return element;
      }
    }
    return ChatModelProviderBase('Custom', 'http://localhost:1234/v1',
        ownedBy: OwnedByEnum.custom);
  }
}

class ChatModelProviderBase {
  final String providerName;
  final String apiUrl;
  final OwnedByEnum ownedBy;
  final String? priceUrl;

  const ChatModelProviderBase(this.providerName, this.apiUrl,
      {this.ownedBy = OwnedByEnum.custom, this.priceUrl});

  // equals
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ChatModelProviderBase &&
        other.providerName == providerName &&
        other.apiUrl == apiUrl;
  }

  @override
  int get hashCode => providerName.hashCode ^ apiUrl.hashCode;

  @override
  String toString() =>
      'ChatModelProviderBase(providerName: $providerName, apiUrl: $apiUrl)';

  static const List<ChatModelProviderBase> providersList = [
    ChatModelProviderBase(
      'OpenAI',
      'https://api.openai.com/v1',
      ownedBy: OwnedByEnum.openai,
      priceUrl:
          'https://help.openai.com/en/articles/7127956-how-much-does-gpt-4-cost',
    ),
    ChatModelProviderBase('LM Studio', 'http://localhost:1234/v1',
        ownedBy: OwnedByEnum.lm_studio),
    ChatModelProviderBase(
      'Deepinfra',
      'https://api.deepinfra.com/v1/openai',
      ownedBy: OwnedByEnum.deepinfra,
      priceUrl: 'https://deepinfra.com/pricing',
    ),
    // ChatModelProviderBase('Claude', 'https://api.openai.com/v1', OwnedByEnum.claude),
    // ChatModelProviderBase('Gemini', '', OwnedByEnum.custom, priceUrl: 'https://cloud.google.com/vertex-ai/generative-ai/pricing'),
    ChatModelProviderBase('Custom', 'http://localhost:1234/v1',
        ownedBy: OwnedByEnum.custom),
  ];
}

enum OwnedByEnum {
  openai,
  lm_studio,
  gemini,
  deepinfra,
  claude,
  custom,
}
