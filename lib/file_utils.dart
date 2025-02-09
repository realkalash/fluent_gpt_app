import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/log.dart';
import 'package:flutter/foundation.dart';
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

  /// Convert to base64
  /// Ensure this bytes is an image!
  String toBase64() => base64Encode(this);
}

extension XFileBaseExtension on XFile {
  /// Converts the image to a base64 string.
  /// Ensure this bytes is an image!
  Future<String> imageToBase64() async {
    final bytes = await readAsBytes();
    return base64Encode(bytes);
  }
}

class FileUtils {
  static String? documentDirectoryPath;
  static String? imageDirectoryPath;
  static String? temporaryDirectoryPath;
  static String? temporaryAudioDirectoryPath;

  static String? get appTemporaryDirectoryPath => temporaryDirectoryPath == null
      ? null
      : '$temporaryDirectoryPath${Platform.pathSeparator}fluent_gpt';

  /// ${documentDirectoryPath}${Platform.pathSeparator}external_tools
  static String? externalToolsPath;
  static String? separatior;

  static Future<void> init() async {
    separatior = Platform.pathSeparator;
    documentDirectoryPath = kDebugMode
        ? await getDebugAppDirectory()
        : AppCache.appDocumentsDirectory.value!.isNotEmpty
            ? AppCache.appDocumentsDirectory.value
            : (await getApplicationDocumentsDirectory()).path;
    imageDirectoryPath =
        '$documentDirectoryPath${separatior}fluent_gpt${separatior}generated_images';

    temporaryDirectoryPath = (await getTemporaryDirectory()).path;
    temporaryAudioDirectoryPath =
        '$temporaryDirectoryPath${separatior}fluent_gpt${separatior}audio';
    externalToolsPath =
        '$documentDirectoryPath${separatior}fluent_gpt${separatior}external_tools';
    log('externalToolsPath: $externalToolsPath');
    log('documentDirectoryPath: $documentDirectoryPath');
    log('imageDirectoryPath: $imageDirectoryPath');
    log('temporaryDirectoryPath: $temporaryDirectoryPath');
    log('temporaryAudioDirectoryPath: $temporaryAudioDirectoryPath');
    log('externalToolsPath: $externalToolsPath');
  }

  static Future<String> getDebugAppDirectory() async {
    return ('${(await getApplicationDocumentsDirectory()).path}${separatior!}debug');
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

  /// Saves the provided [data] to a file at the given [path].
  ///
  /// If the file does not exist, it will be created recursively.
  /// Returns `null` if the file is successfully saved, otherwise returns an error message.
  static Future<String?> saveFileBytes(String path, Uint8List data) async {
    try {
      final file = File(path);
      if (!file.existsSync()) {
        await file.create(recursive: true);
      }
      await file.writeAsBytes(data);
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

  /// key and message.toJson() to json string
  static Future saveChatMessages(String id, String data) async {
    final file = await getChatRoomMessagesFileById(id);
    if (!file.existsSync()) {
      await file.create(recursive: true);
    }
    await file.writeAsString(data);
  }

  static Future<String> getChatRoomsPath() async {
    final dir = documentDirectoryPath ??
        (await getApplicationDocumentsDirectory()).path;
    final sep = Platform.pathSeparator;
    return '$dir${sep}fluent_gpt${sep}chat_rooms';
  }

  static Future<String> getChatRoomFilePath(String chatRoomId) async {
    final dir = documentDirectoryPath ??
        (await getApplicationDocumentsDirectory()).path;
    final sep = Platform.pathSeparator;
    return '$dir${sep}fluent_gpt${sep}chat_rooms$sep$chatRoomId.json';
  }

  /// Returns the file at the given [id] in the chat rooms directory.
  /// The content is a JSON string of the chat room messages.
  ///
  /// Example:
  /// ```json
  /// [
  ///   {
  ///    "id": "1",
  ///    "message": {
  ///       "prefix": "AI",
  ///       "message": "Hello, how can I help you?"
  ///     }
  ///   }
  /// ]
  /// ```
  static Future<File> getChatRoomMessagesFileById(String id) async {
    final path = await getChatRoomsPath();
    return File('$path${Platform.pathSeparator}$id-messages.json');
  }

  /// It will not give messages files `.git` and `.DS_Store` and `-messages.json`
  /// if you want to get messages files use [getFilesRecursiveWithChatMessages]
  static List<File> getFilesRecursive(String dirPath) {
    final files = <File>[];
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return files;
    final list = dir.listSync(recursive: true);
    for (final entity in list) {
      if (entity is File) {
        if (entity.path.contains('.DS_Store') == true) continue;
        if (entity.path.contains('.git') == true) continue;
        if (entity.path.contains('-messages.json') == true) continue;
        files.add(entity);
      }
    }

    return files;
  }

  /// It will not give messages files .git and .DS_Store
  static List<File> getFilesRecursiveWithChatMessages(String dirPath) {
    final files = <File>[];
    final dir = Directory(dirPath);
    if (!dir.existsSync()) return files;
    final list = dir.listSync(recursive: true);
    for (final entity in list) {
      if (entity is File) {
        if (entity.path.contains('.DS_Store') == true) continue;
        if (entity.path.contains('.git') == true) continue;
        files.add(entity);
      }
    }

    return files;
  }

  static Future<List<File>> getAllChatMessagesFiles() async {
    final path = await getChatRoomsPath();
    // get files recursive will not return messages files
    final files = <File>[];
    final dir = Directory(path);
    if (!dir.existsSync()) return files;
    final list = dir.listSync(recursive: true);
    for (final entity in list) {
      if (entity is File) {
        if (entity.path.contains('-messages.json') == true) files.add(entity);
      }
    }
    return files;
  }

  static Future<String> getArchivedChatRoomPath() async {
    final dir =
        documentDirectoryPath ?? await getApplicationDocumentsDirectory();
    final separ = Platform.pathSeparator;
    return '$dir${separ}fluent_gpt${separ}archived${separ}chat_rooms';
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
