import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';

class Attachment {
  final XFile file;
  final bool isInternalScreenshot;
  String get path => file.path;
  String get name => file.name;
  String? get mimeType => file.mimeType;
  Future<Uint8List> readAsBytes() => file.readAsBytes();

  const Attachment({
    required this.file,
    required this.isInternalScreenshot,
  });

  factory Attachment.fromFile(XFile file) {
    return Attachment(
      file: file,
      isInternalScreenshot: false,
    );
  }

  factory Attachment.fromInternalScreenshot(XFile file) {
    return Attachment(
      file: file,
      isInternalScreenshot: true,
    );
  }
}
