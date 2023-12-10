import 'dart:async';
import 'dart:developer';
import 'dart:io';
import 'package:chatgpt_windows_flutter_app/main.dart';
import 'package:file/local.dart';
import 'package:shell/shell.dart';

class ShellDriver {
  static const tempDirTrim = 'temp';
  static const tempDir = 'temp\\';
  static const resultFile = 'result';
  static int currentFileIndex = 0;
  static final _isRunningStreamController = StreamController<bool>.broadcast();

  /// stream for listening is current shell is running
  static Stream<bool> get isRunningStream => _isRunningStreamController.stream;

  /// Should be called after SharedPrefs are initialized
  init() {
    currentFileIndex = prefs?.getInt('currentFileIndex') ?? 0;
  }

  static Future<void> runTest() async {
    var fs = const LocalFileSystem();
    var shell = Shell();
    var password = Platform.environment['PASSWORD'];
    log('Password from env: $password');

    // Pipe results to files, easily.
    var echo = await shell.start('echo', arguments: ['hello world']);
    await echo.stdout.writeToFile(fs.file('hello.txt'));
    await echo.stderr.drain();
    log('Wrote hello.txt to ${fs.currentDirectory}');
  }

  static Future<void> runPythonShellTest() async {
    var fs = const LocalFileSystem();
    var shell = Shell();
    var password = Platform.environment['PASSWORD'];
    log('Password from env: $password');

    // write a simpple python script into temp dir
    // ```
    // print("Hello, World!")
    ///```
    var pythonScript = fs.file('${tempDir}hello.py');
    await pythonScript.create(recursive: true);
    await pythonScript.writeAsString('print("Hello, World!")');
    var python = await shell.start('python', arguments: [pythonScript.path]);
    await python.stdout.writeToFile(fs.file('$tempDir$resultFile.txt'));
    await python.stderr.drain();
    log('Wrote $resultFile to ${fs.currentDirectory}');
  }

  /// returns the output from the python script if it was successful
  /// or an error message if it failed
  static Future<String> runPythonCode(String code) async {
    var fs = const LocalFileSystem();
    var shell = Shell();
    var password = Platform.environment['PASSWORD'];
    _isRunningStreamController.add(true);
    String message;
    final outputPathFile = '$tempDir${currentFileIndex}_$resultFile.txt';
    final pythonPathFile = '$tempDir$currentFileIndex.py';

    try {
      log('Password from env: $password');
      final firstLine = code.split('\n').first;
      var pythonScript = fs.file(pythonPathFile);
      log('Running python code in a temp file: ${pythonScript.path}.\nFirst line:\n $firstLine');
      await pythonScript.create(recursive: true);
      await pythonScript.writeAsString(code);
      var python = await shell.start('python', arguments: [pythonScript.path]);
      message = await python.stdout.readAsString();
      await fs.file(outputPathFile).create(recursive: true);
      await fs.file(outputPathFile).writeAsString(message);
      // await python.stdout
      //     .writeToFile(fs.file('$tempDir${currentFileIndex}_$resultFile.txt'));
      await python.stderr.drain();
      log('Wrote $resultFile to ${fs.currentDirectory}');
      currentFileIndex++;
      prefs?.setInt('currentFileIndex', currentFileIndex);
      await openResultsFolder();
    } catch (e) {
      log('Error running python code: $e');
      // write an error to log file
      var errorFile = fs.file('error_log_$currentFileIndex.txt');
      await errorFile.create(recursive: true);
      await errorFile.writeAsString(e.toString());
      currentFileIndex++;
      prefs?.setInt('currentFileIndex', currentFileIndex);
      message = '[Error]: $e';
    } finally {
      _isRunningStreamController.add(false);
    }

    return message;
  }

  static Future openResultsFolder() async {
    var shell = Shell();
    var fs = const LocalFileSystem();
    var password = Platform.environment['PASSWORD'];
    log('Password from env: $password');
    final resultsFolderFullPath = '${fs.currentDirectory.path}\\$tempDirTrim';
    // final commandWithSelect = '/select, "$resultsFolderFullPath"';
    final command = '$resultsFolderFullPath\\';
    log('Command:\nexplorer $command');
    var python = await shell.start('explorer', arguments: [command]);
    final output = await python.stdout.readAsString();
    log('Explorer output: $output');
    await python.stderr.drain();
  }

  static Future<List<FileSystemEntity>> getTempFiles() async {
    var fs = const LocalFileSystem();
    List<FileSystemEntity> files = [];
    final currDir = fs.currentDirectory.path;
    fs.currentDirectory = fs.directory(currDir);
    for (var file in fs.currentDirectory.listSync()) {
      if (file is File) {
        // log('File: ${file.path}');
        files.add(file);
      } else if (file is Directory) {
        // log('Directory: ${file.path}');
        for (var subFile in (file as Directory).listSync()) {
          // log('SubFile: ${subFile.path}');
          files.add(subFile);
        }
      }
    }
    return files;
  }

  static Future<List<FileSystemEntity>> getTempFilesFromFolder(
      String folder) async {
    var fs = const LocalFileSystem();
    List<FileSystemEntity> files = [];
    final currDir = fs.currentDirectory.path;
    fs.currentDirectory = fs.directory(currDir);
    for (var file in fs.currentDirectory.listSync()) {
      // log('File: ${file.path}');
      files.add(file);
      if (file is Directory) {
        for (var subFile in (file as Directory).listSync()) {
          // log('SubFile: ${subFile.path}');
          files.add(subFile);
        }
      }
    }
    return files;
  }

  static Future<int> calcTempFilesSize() async {
    try {
      final files = await getTempFiles();
      var size = 0;
      for (var file in files) {
        size += (await file.stat()).size;
      }
      return size;
    } catch (e) {
      log('Error calculating temp files size: $e');
    }
    return 0;
  }

  static Future deleteAllTempFiles() async {
    final files = await getTempFiles();
    for (var file in files) {
      await file.delete();
    }
    currentFileIndex = 0;
    await prefs?.setInt('currentFileIndex', currentFileIndex);
  }
}
