import 'package:fluent_gpt/common/custom_messages/text_file_custom_message.dart';
import 'package:fluent_gpt/common/custom_messages/web_result_custom_message.dart';
import 'package:fluent_gpt/common/scrapper/web_scrapper.dart';
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
  final List<SearchResult>? webResults;
  final int timestamp;
  final int tokens;
  final FluentChatMessageType type;

  bool get isTextMessage =>
      type == FluentChatMessageType.textHuman ||
      type == FluentChatMessageType.textAi;

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
  });

  factory FluentChatMessage.system({
    required String id,
    required String content,
    int? timestamp,
    tokens = 0,
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
    tokens = 0,
  }) {
    return FluentChatMessage(
      id: id,
      content: content,
      creator: creator,
      timestamp: timestamp ?? DateTime.now().millisecondsSinceEpoch,
      type: FluentChatMessageType.textAi,
      tokens: tokens,
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
    tokens = 0,
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

  factory FluentChatMessage.imageAi({
    required String id,
    required String content,
    String? imagePrompt,
    String creator = 'human',
    int? timestamp,
    tokens = 0,
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
    List<SearchResult>? webResults,
  }) {
    return FluentChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      creator: creator ?? this.creator,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      tokens: tokens ?? this.tokens,
      fileName: fileName ?? this.fileName,
      path: path ?? this.path,
      webResults: webResults ?? this.webResults,
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
      if (path != null) 'path': path!,
      if (fileName != null) 'fileName': fileName!,
      if (webResults != null)
        'webResults': webResults!.map((e) => e.toJson()).toList(),
    };
  }

  static FluentChatMessage fromJson(Map<String, dynamic> json) {
    return FluentChatMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      creator: json['creator'] as String,
      timestamp: json['timestamp'] as int,
      type: (json['type'] as int?)?.toEnum(FluentChatMessageType.values) ??
          FluentChatMessageType.textHuman,
      tokens: json['tokens'] as int,
      path: json['path'] as String?,
      fileName: json['fileName'] as String?,
      webResults: (json['webResults'] as List?)
          ?.map((e) => SearchResult.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  String toString() {
    return 'FMessage{id: $id, content: $content, creator: $creator, timestamp: $timestamp, prefix: $type}';
  }

  ChatMessage toLangChainChatMessage() {
    switch (type) {
      case FluentChatMessageType.textHuman:
        return HumanChatMessage(content: ChatMessageContentText(text: content));
      case FluentChatMessageType.textAi:
        return AIChatMessage(content: content);
      case FluentChatMessageType.system:
        return SystemChatMessage(content: content);
      case FluentChatMessageType.image:
        return HumanChatMessage(
            content: ChatMessageContentImage(
                data: content,
                detail: ChatMessageContentImageDetail.high,
                mimeType: 'image/png'));
      case FluentChatMessageType.imageAi:
        return HumanChatMessage(
            content: ChatMessageContentImage(
                data: content,
                detail: ChatMessageContentImageDetail.high,
                mimeType: 'image/png'));
      case FluentChatMessageType.file:
        return TextFileCustomMessage(
            fileName: fileName ?? 'temp', content: content, path: path ?? '');
      case FluentChatMessageType.webResult:
        return WebResultCustomMessage(
            content: content, searchResults: webResults ?? []);
      default:
        return HumanChatMessage(content: ChatMessageContentText(text: content));
    }
  }

  /// USE ONLY FOR IMPORTING
  static FluentChatMessage fromLangChainChatMessage(ChatMessage message,
      [String? id]) {
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
    );
  }
}

extension _FluentChatMessageTypeEnum on int? {
  FluentChatMessageType? toEnum(List<FluentChatMessageType> values) {
    if (this == null) return null;
    return this != null && this! >= 0 && this! < values.length
        ? values[this!]
        : FluentChatMessageType.textHuman;
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
