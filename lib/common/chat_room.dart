import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography_flutter/cryptography_flutter.dart';
import 'package:fluent_gpt/common/chat_model.dart';
import 'package:fluent_gpt/common/custom_messages/image_custom_message.dart';
import 'package:fluent_gpt/common/custom_messages_src.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:langchain/langchain.dart';

class ChatRoom {
  String id;
  String chatRoomName;
  ChatModelAi model;
  double? temp;
  int? topk;
  int? promptBatchSize;
  double? topP;

  /// Max token length to include for the prompt/chat
  int maxTokenLength;
  int? maxTokensResponseLenght;
  double? repeatPenalty;
  int iconCodePoint;

  /// if pinned, it will be `999999`
  int indexSort;
  bool get isPinned => indexSort != 999999;
  int dateCreatedMilliseconds;
  int? totalSentTokens;
  int? totalReceivedTokens;
  int? seed;
  String? systemMessage;
  int? systemMessageTokensCount;
  String characterName;
  String? characterAvatarPath;
  List<ChatRoom>? children;
  bool get isFolder => children != null;

  ChatRoom({
    required this.id,
    required this.chatRoomName,
    required this.model,
    required this.temp,
    required this.topk,
    required this.promptBatchSize,
    required this.topP,
    this.maxTokenLength = 2048,
    this.maxTokensResponseLenght,
    this.repeatPenalty,
    this.systemMessage,
    this.systemMessageTokensCount,
    required this.dateCreatedMilliseconds,
    this.indexSort = 999999,

    /// 62087 is the code point for the `chat_24_filled` from [FluentIcons]
    this.iconCodePoint = 62087,
    this.totalSentTokens = 0,
    this.totalReceivedTokens = 0,
    this.characterName = 'ai',
    this.characterAvatarPath,
    this.children,
    this.seed,
  });

  factory ChatRoom.folder({
    String? id,
    String? chatRoomName,
    required ChatModelAi model,
    double? temp,
    int? topk,
    int? promptBatchSize,
    int? repeatPenaltyTokens,
    double? topP,
    int? maxLength,
    int? maxTokensResponseLenght,
    double? repeatPenalty,
    String? token,
    String? orgID,
    String? systemMessage,
    String? characterName,
    String? avatarPath,
    double? costUSD,
    int? tokens,
    int? iconCodePoint,
    int? indexSort,
    int? dateCreatedMilliseconds,
    int? totalSentTokens,
    int? totalReceivedTokens,
    int? systemMessageTokensCount,
    List<ChatRoom> children = const [],
  }) {
    return ChatRoom(
      id: id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      chatRoomName: chatRoomName ?? 'New Folder',
      model: model,
      temp: temp,
      topk: topk,
      promptBatchSize: promptBatchSize,
      topP: topP,
      maxTokenLength: maxLength ?? 2048,
      maxTokensResponseLenght: maxTokensResponseLenght,
      systemMessageTokensCount: systemMessageTokensCount,
      repeatPenalty: repeatPenalty,
      systemMessage: systemMessage,
      dateCreatedMilliseconds:
          dateCreatedMilliseconds ?? DateTime.now().millisecondsSinceEpoch,
      indexSort: indexSort ?? 999999,
      iconCodePoint: iconCodePoint ?? 62087,
      totalSentTokens: totalSentTokens ?? 0,
      totalReceivedTokens: totalReceivedTokens ?? 0,
      characterName: characterName ?? 'ai',
      characterAvatarPath: avatarPath,
      children: children,
    );
  }

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

  static ChatRoom fromMap(Map<String, dynamic> map) {
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
      topP: map['topP'],
      maxTokenLength: map['maxLength'],
      repeatPenalty: map['repeatPenalty'],
      systemMessage: map['commandPrefix'],
      maxTokensResponseLenght: map['maxTokensResponseLenght'],
      systemMessageTokensCount: map['systemMessageTokensCount'] ?? 0,
      indexSort: map['indexSort'] ?? 999999,
      totalSentTokens: map['totalSentTokens'] ?? 0,
      totalReceivedTokens: map['totalReceivedTokens'] ?? 0,
      dateCreatedMilliseconds: map['dateCreatedMilliseconds'] ??
          DateTime.now().millisecondsSinceEpoch,
      characterName: map['characterName'] ?? 'ai',
      characterAvatarPath: map['avatarPath'],
      seed: map['seed'],
      children: map['children'] != null
          ? (map['children'] as List)
              .map((e) => ChatRoom.fromMap(e as Map<String, dynamic>))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
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
      'topP': topP,
      'maxLength': maxTokenLength,
      'repeatPenalty': repeatPenalty,
      'totalSentTokens': totalSentTokens ?? 0,
      'totalReceivedTokens': totalReceivedTokens,
      'maxTokensResponseLenght': maxTokensResponseLenght,
      'seed': seed,

      /// List<int> Encrypted data
      // 'token': encryptedTokenBox.cipherText,
      'commandPrefix': systemMessage,
      'systemMessageTokensCount': systemMessageTokensCount,
      // 'nonce': encryptedTokenBox.nonce,
      'indexSort': indexSort,
      'dateCreatedMilliseconds': dateCreatedMilliseconds,
      'characterName': characterName,
      'avatarPath': characterAvatarPath,
      'children': children?.map((e) => e.toJson()).toList(),
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
          content: ChatMessageContentImage(
              data: json['base64'], mimeType: 'image/png'),
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
    if (json['role'] == TextFileCustomMessage.defaultPrefix) {
      return TextFileCustomMessage.fromJson(json);
    }
    if (json['role'] == ImageCustomMessage.defaultPrefix) {
      return ImageCustomMessage.fromJson(json);
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
    int? systemMessageTokensCount,
    String? characterName,
    String? avatarPath,
    double? costUSD,
    int? tokens,
    int? iconCodePoint,
    int? indexSort,
    int? dateCreatedMilliseconds,
    int? totalSentTokens,
    int? totalReceivedTokens,
    int? maxTokensResponseLenght,
    int? seed,
    List<ChatRoom>? children,
  }) {
    return ChatRoom(
      id: id ?? this.id,
      chatRoomName: chatRoomName ?? this.chatRoomName,
      model: model ?? this.model,
      temp: temp ?? this.temp,
      topk: topk ?? this.topk,
      maxTokensResponseLenght:
          maxTokensResponseLenght ?? this.maxTokensResponseLenght,
      promptBatchSize: promptBatchSize ?? this.promptBatchSize,
      topP: topP ?? this.topP,
      maxTokenLength: maxLength ?? maxTokenLength,
      repeatPenalty: repeatPenalty ?? this.repeatPenalty,
      systemMessage: systemMessage ?? this.systemMessage,
      systemMessageTokensCount:
          systemMessageTokensCount ?? this.systemMessageTokensCount,
      indexSort: indexSort ?? this.indexSort,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      dateCreatedMilliseconds:
          dateCreatedMilliseconds ?? this.dateCreatedMilliseconds,
      totalSentTokens: totalSentTokens ?? this.totalSentTokens,
      totalReceivedTokens: totalReceivedTokens ?? this.totalReceivedTokens,
      characterName: characterName ?? this.characterName,
      characterAvatarPath: avatarPath ?? characterAvatarPath,
      seed: seed ?? this.seed,
      children: children ?? this.children,
    );
  }

  static ChatRoom fromJson(String stringJson) {
    final map = json.decode(stringJson) as Map<String, dynamic>;
    return ChatRoom.fromMap(map);
  }
}
