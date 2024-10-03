import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:fluent_gpt/common/chat_model.dart';
import 'package:fluent_gpt/common/custom_messages_src.dart';
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
  int dateCreatedMilliseconds;

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
    required this.dateCreatedMilliseconds,
    this.indexSort = 999999,

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
    final messages = ConversationBufferMemory(
      chatHistory: ChatMessageHistory(),
    );
    return ChatRoom(
      model: map['model'] is String
          ? ChatModelAi(
              modelName: map['model'],
              ownedBy: map['model'] == 'gpt-4o' ? 'openai' : 'custom',
            )
          : ChatModelAi.fromJson(map['model']),
      id: map['id'],
      chatRoomName: map['chatRoomName'],
      temp: map['temp'],
      topk: map['topk'],
      iconCodePoint: map['iconCode'] as int? ?? 62087,
      promptBatchSize: map['promptBatchSize'],
      repeatPenaltyTokens: map['repeatPenaltyTokens'],
      topP: map['topP'],
      maxTokenLength: map['maxLength'],
      repeatPenalty: map['repeatPenalty'],
      systemMessage: map['commandPrefix'],
      indexSort: map['indexSort'] ?? 999999,
      messages: messages,
      dateCreatedMilliseconds: map['dateCreatedMilliseconds'] ??
          DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<Map<String, dynamic>> toJson() async {
    // final secretKey =
    //     await FlutterCryptography.defaultInstance.aesGcm().newSecretKey();
    // final encryptedTokenBox = await encryptApiToken(apiToken, secretKey);
    return {
      'id': id,
      'model': model.toJson(),
      'chatRoomName': chatRoomName,
      // 'messages': await messages.loadMemoryVariables(),
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
      'dateCreatedMilliseconds': dateCreatedMilliseconds,
    };
  }

  static ChatMessage chatMessageFromJson(Map<String, dynamic> json) {
    if (json['prefix'] == HumanChatMessage.defaultPrefix) {
      if (json['content'] is String) {
        return HumanChatMessage(
          content: ChatMessageContentText(text: json['content']),
        );
      }
      if (json['base64'] is String) {
        return HumanChatMessage(
          content: ChatMessageContentImage(data: json['base64']),
        );
      }
    }
    if (json['prefix'] == AIChatMessage.defaultPrefix) {
      if (json['content'] is String) {
        return AIChatMessage(content: json['content'] as String);
      }
    }
    if (json['prefix'] == SystemChatMessage.defaultPrefix) {
      if (json['content'] is String) {
        return SystemChatMessage(content: json['content'] as String);
      }
    }
    // Extended custom messages should be checked before CustomChatMessage
    // because they are extended from CustomChatMessage
    if (json['role'] == WebResultCustomMessage.defaultPrefix) {
      return WebResultCustomMessage.fromJson(json);
    }
    // custom message
    if (json['prefix'] is String && json['content'] is String) {
      return CustomChatMessage(
        role: json['prefix'] as String,
        content: json['content'] as String,
      );
    }
    throw Exception('Invalid content');
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
    String? systemMessage,
    double? costUSD,
    int? tokens,
    int? iconCodePoint,
    int? indexSort,
    int? dateCreatedMilliseconds,
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
      systemMessage: systemMessage ?? this.systemMessage,
      indexSort: indexSort ?? this.indexSort,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      dateCreatedMilliseconds:
          dateCreatedMilliseconds ?? this.dateCreatedMilliseconds,
    );
  }

  static Future<ChatRoom> fromJson(String stringJson) {
    final map = json.decode(stringJson) as Map<String, dynamic>;
    return ChatRoom.fromMap(map);
  }
}
