import 'package:fluent_gpt/common/custom_messages/text_file_custom_message.dart';
import 'package:fluent_gpt/common/custom_messages/web_result_custom_message.dart';
import 'package:fluent_gpt/common/scrapper/web_search_result.dart';
import 'package:intl/intl.dart';
import 'package:langchain/langchain.dart';

class FluentChatMessage {
  /// Unique id of the message. For unknown IDs we use millisecondsSinceEpoch string
  final String id;
  final String content;

  /// Only for image AI answer
  final String? imagePrompt;
  final String creator;
  final String? path;
  final String? fileName;
  final List<WebSearchResult>? webResults;
  final int timestamp;

  String formatDate() {
    final formatter = DateFormat('dd/MM/yyyy HH:mm:ss');
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return formatter.format(date);
  }

  final int tokens;
  final FluentChatMessageType type;
  final bool useLowResImage = false;
  final List<String>? buttons;
  final int? indexPin;

  bool get isTextMessage => type == FluentChatMessageType.textHuman || type == FluentChatMessageType.textAi;
  bool get isTextFromMe => type == FluentChatMessageType.textHuman;

  const FluentChatMessage({
    required this.id,
    required this.content,
    this.imagePrompt,
    required this.creator,
    required this.timestamp,
    required this.type,
    this.tokens = 0,
    this.path,
    this.fileName,
    this.webResults,
    this.buttons,
    this.indexPin,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is FluentChatMessage && other.id == id;
  }

  @override
  int get hashCode => id.hashCode ^ content.hashCode ^ creator.hashCode;

  factory FluentChatMessage.system({
    required String id,
    required String content,
    int? timestamp,
    int tokens = 0,
    List<String>? buttons,
  }) {
    return FluentChatMessage(
      id: id,
      content: content,
      creator: 'system',
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      type: FluentChatMessageType.system,
      tokens: tokens,
    );
  }

  factory FluentChatMessage.ai({
    required String id,
    required String content,
    String creator = 'ai',
    int? timestamp,
    int tokens = 0,
    List<String>? buttons,
  }) {
    return FluentChatMessage(
      id: id,
      content: content,
      creator: creator,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      type: FluentChatMessageType.textAi,
      tokens: tokens,
      buttons: buttons,
    );
  }

  factory FluentChatMessage.humanText({
    required String id,
    required String content,
    String creator = 'human',
    int? timestamp,
    tokens = 0,
  }) {
    return FluentChatMessage(
      id: id,
      content: content,
      creator: creator,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      type: FluentChatMessageType.textHuman,
      tokens: tokens,
    );
  }

  factory FluentChatMessage.image({
    required String id,
    required String content,
    String creator = 'human',
    int? timestamp,
    // just a placeholder because we can't calc it yet
    int tokens = 256,
  }) {
    return FluentChatMessage(
      id: id,
      content: content,
      creator: creator,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      type: FluentChatMessageType.image,
      tokens: tokens,
    );
  }
  factory FluentChatMessage.file({
    required String id,
    required String path,
    String? content,
    String creator = 'human',
    int? timestamp,
    // just a placeholder because we can't calc it yet
    int tokens = 256,
    String? fileName,
  }) {
    return FluentChatMessage(
      id: id,
      content: content ?? 'File: $path',
      creator: creator,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      type: FluentChatMessageType.file,
      tokens: tokens,
      fileName: fileName,
      path: path,
    );
  }

  factory FluentChatMessage.imageAi({
    required String id,
    required String content,
    String? imagePrompt,
    String creator = 'human',
    int? timestamp,
    // just a placeholder because we can't calc it yet
    int tokens = 256,
  }) {
    return FluentChatMessage(
      id: id,
      content: content,
      creator: creator,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      type: FluentChatMessageType.imageAi,
      tokens: tokens,
      imagePrompt: imagePrompt,
    );
  }

  FluentChatMessage copyWith({
    String? id,
    String? content,
    String? creator,
    int? timestamp,
    FluentChatMessageType? type,
    int? tokens,
    String? path,
    String? fileName,
    List<WebSearchResult>? webResults,
    String? imagePrompt,
    int? indexPin,
    List<String>? buttons,
  }) {
    return FluentChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      creator: creator ?? this.creator,
      indexPin: indexPin ?? this.indexPin,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      tokens: tokens ?? this.tokens,
      fileName: fileName ?? this.fileName,
      path: path ?? this.path,
      webResults: webResults ?? this.webResults,
      buttons: buttons ?? this.buttons,
      imagePrompt: imagePrompt ?? this.imagePrompt,
    );
  }

  FluentChatMessage newPin({
    required int? indexPin,
  }) {
    return FluentChatMessage(
      id: id,
      content: content,
      creator: creator,
      indexPin: indexPin,
      timestamp: timestamp,
      type: type,
      tokens: tokens,
      fileName: fileName,
      path: path,
      webResults: webResults,
      buttons: buttons,
      imagePrompt: imagePrompt,
    );
  }

  Map<String, Object> toJson() {
    return {
      'id': id,
      'content': content,
      'creator': creator,
      'timestamp': timestamp,
      'type': type.index,
      'tokens': tokens,
      if (indexPin != null) 'pin': indexPin!,
      if (imagePrompt != null) 'imagePrompt': imagePrompt!,
      if (path != null) 'path': path!,
      if (fileName != null) 'fileName': fileName!,
      if (webResults != null) 'webResults': webResults!.map((e) => e.toJson()).toList(),
      if (buttons != null) 'buttons': buttons!,
    };
  }

  static FluentChatMessage fromJson(Map<String, dynamic> json) {
    return FluentChatMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      creator: json['creator'] as String,
      timestamp: json['timestamp'] as int,
      indexPin: json['pin'] as int?,
      type: (json['type'] as int?)?.toEnum(FluentChatMessageType.values) ?? FluentChatMessageType.textHuman,
      tokens: json['tokens'] as int,
      path: json['path'] as String?,
      fileName: json['fileName'] as String?,
      webResults:
          (json['webResults'] as List?)?.map((e) => WebSearchResult.fromJson(e as Map<String, dynamic>)).toList(),
      imagePrompt: json['imagePrompt'] as String?,
      buttons: (json['buttons'] as List?)?.map((e) => e as String).toList(),
    );
  }

  @override
  String toString() {
    return 'FMessage{id: $id, content: $content, creator: $creator, timestamp: $timestamp, prefix: $type}';
  }

  ChatMessage toLangChainChatMessage({bool shouldCleanReasoning = false}) {
    switch (type) {
      case FluentChatMessageType.textHuman:
        return HumanChatMessage(content: ChatMessageContentText(text: content));
      case FluentChatMessageType.textAi:
        if (shouldCleanReasoning) {
          return AIChatMessage(content: content.replaceAll(RegExp(r'<think>[\s\S]*?</think>'), '').trimLeft());
        }
        return AIChatMessage(content: content);
      case FluentChatMessageType.system:
        return SystemChatMessage(content: content);
      case FluentChatMessageType.image:
        return HumanChatMessage(
            content: ChatMessageContentImage(
                data: content, detail: ChatMessageContentImageDetail.high, mimeType: 'image/png'));
      case FluentChatMessageType.imageAi:
        return HumanChatMessage(
            content: ChatMessageContentImage(
                data: content, detail: ChatMessageContentImageDetail.high, mimeType: 'image/png'));
      case FluentChatMessageType.file:
        return HumanChatMessage(
          // fileName: fileName ?? 'temp',
          content: ChatMessageContentText(text: content),
          // path: path ?? '',
        );
      case FluentChatMessageType.webResult:
        return WebResultCustomMessage(content: content, searchResults: webResults ?? []);
      // ignore: unreachable_switch_default
      default:
        return HumanChatMessage(content: ChatMessageContentText(text: content));
    }
  }

  /// USE ONLY FOR IMPORTING
  static FluentChatMessage fromLangChainChatMessage(ChatMessage message, [String? id]) {
    if (message is HumanChatMessage) {
      if (message.content is ChatMessageContentText) {
        return FluentChatMessage(
          id: id ?? generateId(),
          content: (message.content as ChatMessageContentText).text,
          creator: 'human',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          type: FluentChatMessageType.textHuman,
        );
      } else if (message.content is ChatMessageContentImage) {
        return FluentChatMessage(
          id: id ?? generateId(),
          content: (message.content as ChatMessageContentImage).data,
          creator: 'human',
          timestamp: DateTime.now().millisecondsSinceEpoch,
          type: FluentChatMessageType.image,
        );
      }
    } else if (message is AIChatMessage) {
      return FluentChatMessage(
        id: id ?? generateId(),
        content: message.content,
        creator: 'ai',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        type: FluentChatMessageType.textAi,
      );
    } else if (message is SystemChatMessage) {
      return FluentChatMessage(
        id: id ?? generateId(),
        content: message.content,
        creator: 'system',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        type: FluentChatMessageType.system,
      );
    } else if (message is TextFileCustomMessage) {
      return FluentChatMessage(
        id: id ?? generateId(),
        content: message.content,
        fileName: message.fileName,
        path: message.path,
        creator: 'human',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        type: FluentChatMessageType.file,
      );
    } else if (message is WebResultCustomMessage) {
      return FluentChatMessage(
        id: id ?? generateId(),
        content: message.content,
        webResults: message.searchResults,
        creator: 'human',
        timestamp: DateTime.now().millisecondsSinceEpoch,
        type: FluentChatMessageType.webResult,
      );
    }
    return FluentChatMessage(
      id: id ?? generateId(),
      content: message.contentAsString,
      creator: 'unknown',
      timestamp: DateTime.now().millisecondsSinceEpoch,
      type: FluentChatMessageType.textHuman,
    );
  }

  static String generateId() {
    /// use timestamp as id
    return DateTime.now().millisecondsSinceEpoch.toString();
  }

  /// Create a new message by concatenating the content of the given message
  FluentChatMessage concat(String newContent) {
    return FluentChatMessage(
      id: id,
      content: content + newContent,
      creator: creator,
      timestamp: timestamp,
      type: type,
      tokens: tokens,
      path: path,
      fileName: fileName,
      webResults: webResults,
      buttons: buttons,
      imagePrompt: imagePrompt,
      indexPin: indexPin,
    );
  }
}

extension _FluentChatMessageTypeEnum on int? {
  FluentChatMessageType? toEnum(List<FluentChatMessageType> values) {
    if (this == null) return null;
    return this != null && this! >= 0 && this! < values.length ? values[this!] : FluentChatMessageType.textHuman;
  }
}

enum FluentChatMessageType {
  textHuman,
  textAi,
  system,
  image,
  imageAi,
  file,
  webResult,
}
