import 'dart:convert';

import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:cryptography/cryptography.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class ChatRoom {
  String id;
  String chatRoomName;
  ChatModel model;
  double temp;
  int topk;
  int promptBatchSize;
  int repeatPenaltyTokens;
  double topP;
  int maxTokenLength;
  double repeatPenalty;
  int iconCodePoint;
  int indexSort;

  /// Api key for the chat model
  String apiToken;

  String? orgID;

  /// cost in USD
  double? costUSD;

  /// Tokens in all messages
  int? tokens;

  String get securedToken =>
      apiToken.replaceAllMapped(RegExp(r'.{4}'), (match) {
        return '*' * match.group(0)!.length;
      });

  /// <chatcmpl-9QZ8C6NhBc5MBrFCVQRZ2uNhAMAW2, <key, value>>
  Map<String, Map<String, String>> messages;
  String? systemMessage;

  ChatRoom({
    required this.id,
    required this.chatRoomName,
    required this.messages,
    required this.model,
    required this.temp,
    required this.topk,
    required this.promptBatchSize,
    required this.repeatPenaltyTokens,
    required this.topP,
    required this.maxTokenLength,
    required this.repeatPenalty,
    required this.apiToken,
    this.orgID,
    this.systemMessage,
    this.costUSD,
    this.tokens,
    this.indexSort = 1,

    /// 62087 is the code point for the `chat_24_filled` from [FluentIcons]
    this.iconCodePoint = 62087,
  });

  /// Method to encrypt the apiToken
  static Future<SecretBox> encryptApiToken(
      String token, SecretKey secretKey) async {
    final algo = FlutterCryptography.defaultInstance.aesGcm();
    final secretBox = await algo.encrypt(
      token.codeUnits,
      secretKey: secretKey,
    );
    return secretBox;
  }

  /// Method to decrypt the apiToken
  static Future<String> decryptApiToken(
      SecretBox secretBox, SecretKey secretKey) async {
    final algo = FlutterCryptography.defaultInstance.aesGcm();
    final decrypted = await algo.decrypt(
      secretBox,
      secretKey: secretKey,
    );
    return String.fromCharCodes(decrypted);
  }

  @override
  int get hashCode => id.hashCode;

  @override
  bool operator ==(Object other) {
    return other is ChatRoom && other.id == id;
  }

  static Future<ChatRoom> fromMap(Map<String, dynamic> map) async {
    String token = map['token'] as String? ?? '';
    // if (map['token'] == null || map['nonce'] == null || map['token'] == '') {
    //   /// List<int> Encrypted data
    //   final encryptedToken = map['token'] as List<int>;
    //   final nonce = map['nonce'] as List<int>;
    //   final secretKey =
    //       await FlutterCryptography.defaultInstance.aesGcm().newSecretKey();
    //   final secretBox = SecretBox(
    //     encryptedToken,
    //     nonce: nonce,
    //     mac: Mac.empty,
    //   );
    //   token = await decryptApiToken(secretBox, secretKey);
    // }

    return ChatRoom(
      model: allModels.firstWhere(
        (element) => element.toString() == map['model'],
        orElse: () => allModels.first,
      ),
      id: map['id'],
      chatRoomName: map['chatRoomName'],
      temp: map['temp'],
      topk: map['topk'],
      iconCodePoint: map['iconCodePoint'] as int? ?? 62087,
      promptBatchSize: map['promptBatchSize'],
      repeatPenaltyTokens: map['repeatPenaltyTokens'],
      topP: map['topP'],
      maxTokenLength: map['maxLength'],
      repeatPenalty: map['repeatPenalty'],
      apiToken: token,
      orgID: map['orgID'],
      systemMessage: map['commandPrefix'],
      costUSD: map['costUSD'],
      tokens: map['tokens'],
      indexSort: map['indexSort'],
      messages: (map['messages'] as Map).map(
        (key, value) {
          return MapEntry(key, Map<String, String>.from(value));
        },
      ),
    );
  }

  Future<Map<String, dynamic>> toJson() async {
    // final secretKey =
    //     await FlutterCryptography.defaultInstance.aesGcm().newSecretKey();
    // final encryptedTokenBox = await encryptApiToken(apiToken, secretKey);
    return {
      'id': id,
      'model': model.model.toString(),
      'chatRoomName': chatRoomName,
      'messages': messages,
      'temp': temp,
      'topk': topk,
      'iconCode': iconCodePoint,
      'promptBatchSize': promptBatchSize,
      'repeatPenaltyTokens': repeatPenaltyTokens,
      'topP': topP,
      'maxLength': maxTokenLength,
      'repeatPenalty': repeatPenalty,

      /// List<int> Encrypted data
      // 'token': encryptedTokenBox.cipherText,
      'token': apiToken,
      'orgID': orgID,
      'commandPrefix': systemMessage,
      'costUSD': costUSD,
      'tokens': tokens,
      // 'nonce': encryptedTokenBox.nonce,
      'indexSort': indexSort,
    };
  }

  ChatRoom copyWith({
    String? id,
    String? chatRoomName,
    Map<String, Map<String, String>>? messages,
    ChatModel? model,
    double? temp,
    int? topk,
    int? promptBatchSize,
    int? repeatPenaltyTokens,
    double? topP,
    int? maxLength,
    double? repeatPenalty,
    String? token,
    String? orgID,
    String? commandPrefix,
    double? costUSD,
    int? tokens,
    int? iconCodePoint,
    int? indexSort,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      chatRoomName: chatRoomName ?? this.chatRoomName,
      messages: messages ?? this.messages,
      model: model ?? this.model,
      temp: temp ?? this.temp,
      topk: topk ?? this.topk,
      promptBatchSize: promptBatchSize ?? this.promptBatchSize,
      repeatPenaltyTokens: repeatPenaltyTokens ?? this.repeatPenaltyTokens,
      topP: topP ?? this.topP,
      maxTokenLength: maxLength ?? maxTokenLength,
      repeatPenalty: repeatPenalty ?? this.repeatPenalty,
      apiToken: token ?? apiToken,
      orgID: orgID ?? this.orgID,
      systemMessage: commandPrefix ?? systemMessage,
      costUSD: costUSD ?? this.costUSD,
      tokens: tokens ?? this.tokens,
      indexSort: indexSort ?? this.indexSort,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
    );
  }

  static Future<ChatRoom> fromJson(String stringJson) {
    final map = json.decode(stringJson) as Map<String, dynamic>;
    return ChatRoom.fromMap(map);
  }
}

final allModels = [
  GPT4OModel(),
  Gpt4ChatModel(),
  GPT4TurboModel(),
  GptTurboChatModel(),
  GptTurbo0301ChatModel(),
  Gpt4VisionPreviewChatModel(),
];

class GPT4TurboModel extends ChatModelFromValue {
  GPT4TurboModel() : super(model: 'gpt-4-0125-preview');
}

class GPT4OModel extends ChatModelFromValue {
  GPT4OModel() : super(model: 'gpt-4o');
}

class LocalChatModel extends ChatModelFromValue {
  LocalChatModel() : super(model: 'local');
  final url = 'http://localhost:1234/v1/';
}
