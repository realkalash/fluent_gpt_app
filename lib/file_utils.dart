import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_gpt/log.dart';
import 'package:mime_type/mime_type.dart';
import 'package:path_provider/path_provider.dart';

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

extension XFileUint8ListExtension on Uint8List {
  XFile toXFile() {
    final bytes = this;
    final randomNumber = DateTime.now().millisecondsSinceEpoch;
    return XFile.fromData(
      bytes,
      length: lengthInBytes,
      mimeType: 'image/png',
      name: '$randomNumber.png',
    );
  }

  Future<XFile> toPNG() async {
    final bytes = this;
    final randomNumber = DateTime.now().millisecondsSinceEpoch;

    // copy from decodeImageFromList of package:flutter/painting.dart
    final codec = await instantiateImageCodec(bytes);
    final frameInfo = await codec.getNextFrame();
    final newImageByte =
        await frameInfo.image.toByteData(format: ImageByteFormat.png);
    return XFile.fromData(
      newImageByte!.buffer.asUint8List(),
      length: newImageByte.lengthInBytes,
      mimeType: 'image/png',
      name: '$randomNumber.png',
    );
  }
}

class FileUtils {
  static String? documentDirectoryPath;

  static Future<void> init() async {
    documentDirectoryPath = (await getApplicationDocumentsDirectory()).path;
  }

  static Future _createTestFileInDir(Future<Directory?> dirFuture) async {
    final dir = await dirFuture;
    if (dir == null) return;
    final path = '${(dir).path}/test.txt';
    await FileUtils.saveFile(path, 'Test');
    await FileUtils.deleteFile(path);
  }

  /// usefull for macos to access permission to all folders
  static Future touchAccessAllFolders() async {
    try {
      /// touch access to Documents, Downloads, Desktop, Pictures
      await _createTestFileInDir(getTemporaryDirectory());
      await _createTestFileInDir(getApplicationDocumentsDirectory());
      await _createTestFileInDir(getApplicationSupportDirectory());
      await _createTestFileInDir(getDownloadsDirectory());
      return true;
    } catch (e) {
      log('touchAccessAllFolders error: $e');
      return false;
    }
  }

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

  /// Delete file
  static Future<bool> deleteFile(String path, {bool recursive = false}) async {
    try {
      final file = File(path);
      if (file.existsSync()) {
        await file.delete(recursive: recursive);
      }
    } catch (e) {
      log('deleteFile error: $e');
    }

    return false;
  }

  static Future<String> getChatRoomPath() async {
    final dir =
        documentDirectoryPath ?? await getApplicationDocumentsDirectory();
    return '$dir/fluent_gpt/chat_rooms';
  }

  static List<File> getFilesRecursive(String dirPath) {
    final files = <File>[];
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return files;
    dir.listSync(recursive: true).forEach((element) {
      if (element is File) {
        if (element.path.contains('.DS_Store') != true) {
          files.add(element);
        }
      }
    });
    return files;
  }

  static Future<String> getArchivedChatRoomPath() async {
    final dir =
        documentDirectoryPath ?? await getApplicationDocumentsDirectory();
    return '$dir/fluent_gpt/archived/chat_rooms';
  }

  static Future moveFile(String fromPath, String toPath) async {
    final file = File(fromPath);
    if (!file.existsSync()) {
      throw Exception('File not found: $fromPath');
    }

    /// check if new path exists
    final newFile = File(toPath);
    if (newFile.existsSync()) {
      await newFile.delete();
    }

    /// if no directory - create
    final newDir = Directory(toPath).parent;
    if (!newDir.existsSync()) {
      await newDir.create(recursive: true);
    }
    await file.copy(toPath);
    await file.delete();
  }

  /// Returns the size of the file at the given [dirPath].
  static Future<double> calculateSizeRecursive(String dirPath) async {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return 0;
    double size = 0;
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) {
        size += await entity.length();
      }
    }
    return size;
  }

  /// Returns the size of the file at the given [dirPath].
  /// Can return KB/MB/bytes
  String getBytesString(double value) {
    // to kilobytes if needed
    if (value > 1024) {
      return '${(value / 1024).toStringAsFixed(2)} KB';
    }
    // to megabytes if needed
    if (value > 1024 * 1024) {
      return '${(value / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${value.toStringAsFixed(2)} bytes';
  }
}
