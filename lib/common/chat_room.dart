import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:fluent_gpt/common/chat_model.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:langchain/langchain.dart';

class ChatRoom {
  String id;
  String chatRoomName;
  ChatModelAi model;
  double temp;
  int topk;
  int promptBatchSize;
  int repeatPenaltyTokens;
  double topP;
  int maxTokenLength;
  double repeatPenalty;
  int iconCodePoint;
  int indexSort;

  /// <chatcmpl-9QZ8C6NhBc5MBrFCVQRZ2uNhAMAW2, <key, value>>
  ConversationBufferMemory messages;
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
    this.systemMessage,
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
    final memoryJson = map['messages'] as Map<String, dynamic>;
    final messages = ConversationBufferMemory(
      chatHistory: ChatMessageHistory()
    );
    return ChatRoom(
      model: allModels.value.firstWhere(
        (element) => element.toString() == map['model'],
        orElse: () => allModels.value.first,
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
      systemMessage: map['commandPrefix'],
      indexSort: map['indexSort'],
      messages: messages,
    );
  }

  Future<Map<String, dynamic>> toJson() async {
    // final secretKey =
    //     await FlutterCryptography.defaultInstance.aesGcm().newSecretKey();
    // final encryptedTokenBox = await encryptApiToken(apiToken, secretKey);
    return {
      'id': id,
      'model': model.name.toString(),
      'chatRoomName': chatRoomName,
      'messages': await messages.loadMemoryVariables(),
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
      'commandPrefix': systemMessage,
      // 'nonce': encryptedTokenBox.nonce,
      'indexSort': indexSort,
    };
  }

  ChatRoom copyWith({
    String? id,
    String? chatRoomName,
    ConversationBufferMemory? messages,
    ChatModelAi? model,
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

      systemMessage: commandPrefix ?? systemMessage,

      indexSort: indexSort ?? this.indexSort,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
    );
  }

  static Future<ChatRoom> fromJson(String stringJson) {
    final map = json.decode(stringJson) as Map<String, dynamic>;
    return ChatRoom.fromMap(map);
  }
}
