import 'dart:typed_data';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:pasteboard/pasteboard.dart';

class PasteIntent extends Intent {
  const PasteIntent({required this.onPasteText, required this.onPasteImage});
  final void Function(String text) onPasteText;
  final void Function(Uint8List image) onPasteImage;

  Future<void> execute() async {
    final text = await Pasteboard.text;
    final image = await Pasteboard.image;
    if (text != null) {
      onPasteText(text);
    } else if (image != null) {
      onPasteImage(image);
    }
  }
}
final PasteAction pasteAction = PasteAction();

class PasteAction extends Action<PasteIntent> {
  @override
  Future<Object?> invoke(PasteIntent intent) async {
    await intent.execute();
    return null;
  }
}
