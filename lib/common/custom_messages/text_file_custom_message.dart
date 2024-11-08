import 'package:flutter_gpt_tokenizer/flutter_gpt_tokenizer.dart';
import 'package:langchain/langchain.dart';

class TextFileCustomMessage extends CustomChatMessage {
  const TextFileCustomMessage({
    required this.fileName,
    required super.content,
    required this.path,
  }) : super(role: defaultPrefix);
  static const String defaultPrefix = 'textFile';
  final String fileName;
  final String path;
  static Tokenizer tokenizer = Tokenizer();

  @override
  String get contentAsString => '```TextFile\n$fileName\n$content\n```';

  Future<int> get tokensLenght {
    return tokenizer.count(contentAsString, modelName: 'gpt-4');
  }

  Map<String, Object> toJson() {
    return {
      'fileName': fileName,
      'role': role,
      'content': '```TextFile\n$fileName\n$content\n```',
      'path': path,
    };
  }

  static TextFileCustomMessage fromJson(Map<String, dynamic> json) {
    return TextFileCustomMessage(
      fileName: json['fileName'] ?? 'file.txt',
      content: json['content'],
      path: json['path'] ?? '',
    );
  }

  HumanChatMessage toHumanChatMessage() {
    return HumanChatMessage(
      content:
          ChatMessageContentText(text: '```TextFile\n$fileName\n$content\n```'),
    );
  }
}
