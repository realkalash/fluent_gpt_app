import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime_type/mime_type.dart';

Future<String> encodeImage(XFile file) async {
  final Uint8List imageBytes = await file.readAsBytes();
  return base64Encode(imageBytes);
}

Uint8List decodeImage(String base64String) {
  return base64.decode(base64String);
}

extension XFileExtension on PlatformFile {
  XFile toXFile() {
    final mimeType = mimeFromExtension(extension ?? '');
    if (bytes != null) {
      return XFile(
        path!,
        bytes: Uint8List.fromList(bytes!),
        length: bytes!.lengthInBytes,
        name: name,
        mimeType: mimeType,
      );
    }
    return XFile(
      path!,
      name: name,
      mimeType: mimeType,
    );
  }
}

class FileUtils {
  /// Saves the provided [data] to a file at the given [path].
  ///
  /// If the file does not exist, it will be created recursively.
  /// Returns `null` if the file is successfully saved, otherwise returns an error message.
  static Future<String?> saveFile(String path, String data) async {
    try {
      final file = File(path);
      if (!file.existsSync()) {
        await file.create(recursive: true);
      }
      await file.writeAsString(data);
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
