import 'package:langchain/langchain.dart';

class ImageCustomMessage extends CustomChatMessage {
  const ImageCustomMessage({
    required this.fileName,

    /// Base64 image content
    required super.content,
    this.revisedPrompt,
    this.generatedBy = 'DALL-E-3',
  }) : super(role: defaultPrefix);
  static const String defaultPrefix = 'imageMessage';
  final String fileName;
  final String? revisedPrompt;
  final String generatedBy;

  @override
  String get contentAsString => content;

  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'role': role,
      'content': content,
      'revisedPrompt': revisedPrompt,
      'generatedBy': generatedBy,
    };
  }

  static ImageCustomMessage fromJson(Map<String, dynamic> json) {
    return ImageCustomMessage(
      fileName: json['fileName'] ?? 'image.png',
      content: json['content'],
      revisedPrompt: json['revisedPrompt'],
      generatedBy: json['generatedBy'] ?? 'DALL-E-3',
    );
  }

  HumanChatMessage toHumanChatMessage() {
    return HumanChatMessage(
      content: ChatMessageContentImage(
          data: content, detail: ChatMessageContentImageDetail.high),
    );
  }
}
