import 'custom_prompt.dart';

class TextSelectionCustomPrompt extends CustomPrompt {
  TextSelectionCustomPrompt({
    required super.title,
    required super.prompt,
    super.id,
    super.index = 0,
    super.showInChatField = false,
    super.showInOverlay = false,
    super.children = const [],
    super.iconCodePoint = 62086,
    super.hotkey,
    super.tags = const [],
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is TextSelectionCustomPrompt &&
        other.title == title &&
        other.prompt == prompt &&
        other.id == id &&
        other.index == index;
  }

  @override
  int get hashCode =>
      title.hashCode ^ prompt.hashCode ^ id.hashCode ^ index.hashCode;
}
