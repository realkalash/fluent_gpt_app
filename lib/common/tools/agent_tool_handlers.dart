import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:flutter/services.dart';
import 'package:shell/shell.dart';
import 'package:url_launcher/url_launcher_string.dart';

const _agentReadDefaultLineCap = 500;
const _agentReadAbsoluteLineCap = 2500;
const _grepToolMaxOutputChars = 48000;
const _dartGrepMaxBytesPerFile = 512 * 1024;

const _commonIgnoredDirNames = {
  '.git',
  'node_modules',
  '.dart_tool',
  'build',
  'dist',
  '.idea',
  '.gradle',
  'Pods',
  'DerivedData',
  '.svn',
  '__pycache__',
  'target',
};

Set<String> _mergeExcludeNames(List<dynamic>? userExclude, bool skipCommon) {
  final out = <String>{};
  if (skipCommon) {
    out.addAll(_commonIgnoredDirNames);
  }
  if (userExclude != null) {
    for (final e in userExclude) {
      if (e is String && e.isNotEmpty) {
        out.add(e);
      }
    }
  }
  return out;
}

bool _pathHasExcludedSegment(String path, Set<String> exclude) {
  if (exclude.isEmpty) return false;
  for (final part in path.replaceAll('\\', '/').split('/')) {
    if (part.isEmpty) continue;
    if (exclude.contains(part)) return true;
  }
  return false;
}

String _basename(String path) {
  final n = path.replaceAll('\\', '/');
  final i = n.lastIndexOf('/');
  return i < 0 ? n : n.substring(i + 1);
}

RegExp _globToRegExp(String pattern) {
  final sb = StringBuffer('^');
  for (var i = 0; i < pattern.length; i++) {
    final c = pattern[i];
    if (c == '*') {
      sb.write('.*');
    } else if (c == '?') {
      sb.write('.');
    } else {
      sb.write(RegExp.escape(c));
    }
  }
  sb.write(r'$');
  return RegExp(sb.toString(), caseSensitive: false);
}

int _countNonOverlapping(String haystack, String needle) {
  if (needle.isEmpty) return 0;
  var count = 0;
  var start = 0;
  while (true) {
    final i = haystack.indexOf(needle, start);
    if (i < 0) break;
    count++;
    start = i + needle.length;
  }
  return count;
}

String _truncateGrepToolOutput(String stdout, int maxResultLines) {
  var maxLines = max(maxResultLines, 20);
  maxLines = min(maxLines, 500);
  final lines = stdout.split('\n');
  var text = stdout;
  if (lines.length > maxLines) {
    text =
        '${lines.take(maxLines).join('\n')}\n... (${lines.length - maxLines} lines omitted; refine pattern, path, or glob)';
  }
  if (text.length <= _grepToolMaxOutputChars) return text;
  return '${text.substring(0, _grepToolMaxOutputChars)}\n... (output truncated by size)';
}

Future<String> _grepDartFallback({
  required String pattern,
  required String searchPath,
  required String? glob,
  required int maxResults,
  required bool caseSensitive,
  required bool skipCommon,
}) async {
  RegExp re;
  try {
    re = RegExp(pattern, caseSensitive: caseSensitive);
  } catch (e) {
    return 'Error: invalid regular expression: $e';
  }

  final exclude = _mergeExcludeNames(null, skipCommon);
  final globRe = glob != null && glob.isNotEmpty ? _globToRegExp(glob) : null;

  final results = <String>[];
  final maxLinesOut = max(maxResults, 20).clamp(20, 500);

  Future<void> scanFile(File file) async {
    if (results.length >= maxLinesOut) return;
    try {
      final len = await file.length();
      if (len > _dartGrepMaxBytesPerFile) return;
      final raw = await file.readAsBytes();
      if (raw.contains(0)) return;
      final text = utf8.decode(raw, allowMalformed: true);
      final lines = const LineSplitter().convert(text);
      for (var i = 0; i < lines.length; i++) {
        if (re.hasMatch(lines[i])) {
          results.add('${file.path}:${i + 1}:${lines[i]}');
          if (results.length >= maxLinesOut) return;
        }
      }
    } catch (_) {}
  }

  final rootType = FileSystemEntity.typeSync(searchPath);
  if (rootType == FileSystemEntityType.file) {
    final f = File(searchPath);
    if (globRe != null && !globRe.hasMatch(_basename(f.path))) {
      return 'No matches (file path did not match glob)';
    }
    await scanFile(f);
  } else if (rootType == FileSystemEntityType.directory) {
    await for (final entity in Directory(searchPath).list(recursive: true, followLinks: false)) {
      if (results.length >= maxLinesOut) break;
      if (_pathHasExcludedSegment(entity.path, exclude)) continue;
      if (entity is! File) continue;
      final name = _basename(entity.path);
      if (globRe != null && !globRe.hasMatch(name)) continue;
      await scanFile(entity);
    }
  } else {
    return 'Error: Not a file or directory: $searchPath';
  }

  if (results.isEmpty) {
    return 'No matches found (Dart scan; install ripgrep for faster search)';
  }
  return results.join('\n');
}

List<String> _parseShellCommand(String command) {
  final parts = <String>[];
  final buffer = StringBuffer();
  bool inQuotes = false;
  bool escape = false;
  for (int i = 0; i < command.length; i++) {
    final char = command[i];
    if (escape) {
      buffer.write(char);
      escape = false;
      continue;
    }
    if (char == '\\') {
      escape = true;
      continue;
    }
    if (char == '"' || char == "'") {
      inQuotes = !inQuotes;
      continue;
    }
    if (char == ' ' && !inQuotes) {
      if (buffer.isNotEmpty) {
        parts.add(buffer.toString());
        buffer.clear();
      }
      continue;
    }
    buffer.write(char);
  }
  if (buffer.isNotEmpty) parts.add(buffer.toString());
  return parts;
}

/// Static handlers for each agent tool. Pure handlers ignore [provider]; the
/// few that need provider state cast it to [ChatProvider].
class AgentToolHandlers {
  static Future<String> readFile(dynamic _, Map<String, dynamic> args) async {
    try {
      final path = args['path'];
      if (path is! String || path.isEmpty) return 'Error: path must be a non-empty string';

      final file = File(path);
      if (!await file.exists()) return 'Error: File not found at $path';
      if (FileSystemEntity.typeSync(path) != FileSystemEntityType.file) {
        return 'Error: Not a file: $path';
      }

      final contents = await file.readAsString();
      final lines = const LineSplitter().convert(contents);
      final totalLines = lines.length;
      if (totalLines == 0) return 'File: $path\nTotal lines: 0\n\n(empty file)';

      int? offset = (args['offset'] as num?)?.toInt();
      int? limit = (args['limit'] as num?)?.toInt();
      if (limit != null && limit <= 0) return 'Error: limit must be positive';

      var startIdx = 0;
      if (offset != null) {
        if (offset == 0) {
          return 'Error: offset uses 1-based line numbers (use 1 for first line, or -1 for last line)';
        }
        if (offset < 0) {
          startIdx = totalLines + offset;
          if (startIdx < 0) startIdx = 0;
        } else {
          startIdx = offset - 1;
        }
      }
      if (startIdx < 0) startIdx = 0;
      if (startIdx >= totalLines) {
        return 'File: $path\nTotal lines: $totalLines\n\nError: offset is past end of file';
      }

      final remaining = totalLines - startIdx;
      final int effectiveLimit;
      var truncatedByDefault = false;
      if (limit != null) {
        effectiveLimit = min(min(limit, _agentReadAbsoluteLineCap), remaining);
      } else {
        if (remaining > _agentReadDefaultLineCap) {
          effectiveLimit = _agentReadDefaultLineCap;
          truncatedByDefault = true;
        } else {
          effectiveLimit = remaining;
        }
      }

      final endIdx = startIdx + effectiveLimit;
      final selected = lines.sublist(startIdx, endIdx);
      final buf = StringBuffer();
      buf.writeln('File: $path');
      buf.writeln('Total lines: $totalLines');
      buf.writeln('Showing lines ${startIdx + 1}-$endIdx');
      if (truncatedByDefault) {
        buf.writeln('(Output capped at $_agentReadDefaultLineCap lines; pass offset and limit to read more)');
      } else if (endIdx < totalLines) {
        buf.writeln('(More lines exist; use offset: ${endIdx + 1} to continue)');
      }
      buf.writeln();
      for (var i = 0; i < selected.length; i++) {
        buf.writeln('${startIdx + i + 1}|${selected[i]}');
      }
      return buf.toString();
    } catch (e) {
      return 'Error reading file: $e';
    }
  }

  static Future<String> listDirectory(dynamic _, Map<String, dynamic> args) async {
    try {
      final path = args['path'];
      if (path is! String || path.isEmpty) return 'Error: path must be a non-empty string';

      final recursive = args['recursive'] as bool? ?? false;
      final globPattern = args['glob'] as String?;
      final entriesMode = args['entries'] as String? ?? 'all';
      final skipCommon = (args['skipCommonIgnored'] ?? args['skip_common_ignored']) as bool? ?? true;
      final userExclude = args['exclude'] as List<dynamic>?;

      final exclude = _mergeExcludeNames(userExclude, skipCommon);
      RegExp? globRe;
      if (globPattern != null && globPattern.isNotEmpty) {
        globRe = _globToRegExp(globPattern);
      }

      final dir = Directory(path);
      if (!await dir.exists()) return 'Error: Directory not found at $path';

      final files = <String>[];
      final directories = <String>[];

      void considerEntity(FileSystemEntity entity) {
        if (_pathHasExcludedSegment(entity.path, exclude)) return;
        if (entity is File) {
          if (entriesMode == 'directories') return;
          final name = _basename(entity.path);
          if (globRe != null && !globRe.hasMatch(name)) return;
          files.add(entity.path);
        } else if (entity is Directory) {
          if (entriesMode == 'files') return;
          if (globRe != null) return;
          directories.add(entity.path);
        }
      }

      if (recursive) {
        await for (final entity in dir.list(recursive: true, followLinks: false)) {
          considerEntity(entity);
        }
      } else {
        await for (final entity in dir.list(recursive: false, followLinks: false)) {
          if (_pathHasExcludedSegment(entity.path, exclude)) continue;
          if (entity is File) {
            if (entriesMode == 'directories') continue;
            final name = _basename(entity.path);
            if (globRe != null && !globRe.hasMatch(name)) continue;
            files.add(entity.path);
          } else if (entity is Directory) {
            if (entriesMode == 'files') continue;
            if (globRe != null) continue;
            directories.add(entity.path);
          }
        }
      }

      files.sort();
      directories.sort();

      final buffer = StringBuffer();
      buffer.writeln('Directory: $path');
      if (globRe != null) buffer.writeln('Glob filter: $globPattern');
      buffer.writeln('entries=$entriesMode recursive=$recursive');
      buffer.writeln('Directories (${directories.length}):');
      for (final d in directories.take(50)) {
        buffer.writeln('  📁 $d');
      }
      if (directories.length > 50) {
        buffer.writeln('  ... and ${directories.length - 50} more directories');
      }

      buffer.writeln('\nFiles (${files.length}):');
      for (final f in files.take(100)) {
        buffer.writeln('  📄 $f');
      }
      if (files.length > 100) {
        buffer.writeln('  ... and ${files.length - 100} more files');
      }
      return buffer.toString();
    } catch (e) {
      return 'Error listing directory: $e';
    }
  }

  static Future<String> searchFiles(dynamic _, Map<String, dynamic> args) async {
    try {
      final pattern = args['pattern'];
      final directory = args['directory'];
      if (pattern is! String || pattern.isEmpty) return 'Error: pattern must be a non-empty string';
      if (directory is! String || directory.isEmpty) return 'Error: directory must be a non-empty string';

      final maxResults = (args['maxResults'] as num?)?.toInt() ?? 50;
      final skipCommon = (args['skipCommonIgnored'] ?? args['skip_common_ignored']) as bool? ?? true;
      final exclude = _mergeExcludeNames(null, skipCommon);

      final dir = Directory(directory);
      if (!await dir.exists()) return 'Error: Directory not found at $directory';

      final matches = <String>[];
      final regExp = _globToRegExp(pattern);

      await for (final entity in dir.list(recursive: true, followLinks: false)) {
        if (_pathHasExcludedSegment(entity.path, exclude)) continue;
        if (entity is File) {
          final fileName = _basename(entity.path);
          if (regExp.hasMatch(fileName)) {
            matches.add(entity.path);
            if (matches.length >= maxResults) break;
          }
        }
      }

      if (matches.isEmpty) return 'No files found matching pattern "$pattern" in $directory';

      final buffer = StringBuffer();
      buffer.writeln('Found ${matches.length} file(s) matching "$pattern":');
      for (final match in matches) {
        buffer.writeln('  📄 $match');
      }
      return buffer.toString();
    } catch (e) {
      return 'Error searching files: $e';
    }
  }

  static Future<String> grep(dynamic _, Map<String, dynamic> args) async {
    try {
      final pattern = args['pattern'];
      if (pattern is! String || pattern.isEmpty) return 'Error: pattern must be a non-empty string';

      final searchPath = (args['path'] as String?) ?? '.';
      final glob = args['glob'] as String?;
      final maxResults = ((args['max_results'] ?? args['maxResults']) as num?)?.toInt() ?? 80;
      final contextLines = max(0, ((args['context_lines'] ?? args['contextLines']) as num?)?.toInt() ?? 2);
      final caseSensitive = (args['case_sensitive'] ?? args['caseSensitive']) as bool? ?? true;
      final skipCommon = (args['skipCommonIgnored'] ?? args['skip_common_ignored']) as bool? ?? true;

      final type = FileSystemEntity.typeSync(searchPath);
      if (type == FileSystemEntityType.notFound) return 'Error: Path not found: $searchPath';

      final rgArgs = <String>[
        '--line-number',
        '--max-columns',
        '800',
        '--max-filesize',
        '2M',
        if (!caseSensitive) '--ignore-case',
        if (contextLines > 0) ...['-C', '$contextLines'],
        if (glob != null && glob.isNotEmpty) ...['--glob', glob],
        pattern,
        searchPath,
      ];

      try {
        final r = await Process.run('rg', rgArgs, runInShell: false, environment: Platform.environment);

        if (r.exitCode == 127) {
          return _grepDartFallback(
            pattern: pattern,
            searchPath: searchPath,
            glob: glob,
            maxResults: maxResults,
            caseSensitive: caseSensitive,
            skipCommon: skipCommon,
          );
        }
        if (r.exitCode == 2) {
          final err = (r.stderr as String).trim();
          if (err.isNotEmpty) return 'Error (ripgrep): $err';
        }

        final out = (r.stdout as String).trimRight();
        if (out.isEmpty) return 'No matches found for pattern in $searchPath';
        return _truncateGrepToolOutput(out, maxResults);
      } on ProcessException catch (_) {
        // Ripgrep not installed or not on PATH; fall through to Dart fallback.
      }

      return _grepDartFallback(
        pattern: pattern,
        searchPath: searchPath,
        glob: glob,
        maxResults: maxResults,
        caseSensitive: caseSensitive,
        skipCommon: skipCommon,
      );
    } catch (e) {
      return 'Error in grep_tool: $e';
    }
  }

  static Future<String> editFile(dynamic _, Map<String, dynamic> args) async {
    try {
      final path = args['path'];
      final oldString = args['old_string'] ?? args['oldString'];
      final newString = args['new_string'] ?? args['newString'];
      if (path is! String || path.isEmpty) return 'Error: path must be a non-empty string';
      if (oldString is! String) return 'Error: old_string is required';
      if (newString is! String) return 'Error: new_string is required';
      if (oldString.isEmpty) {
        return 'Error: old_string must not be empty (use write_file_tool to create a new file)';
      }

      final file = File(path);
      if (!await file.exists()) return 'Error: File not found at $path';
      if (FileSystemEntity.typeSync(path) != FileSystemEntityType.file) {
        return 'Error: Not a file: $path';
      }

      final contents = await file.readAsString();
      final occurrences = _countNonOverlapping(contents, oldString);
      if (occurrences == 0) {
        return 'Error: old_string not found in file (check exact whitespace and line endings)';
      }
      if (occurrences > 1) {
        return 'Error: old_string is not unique (found $occurrences times); include more surrounding context in old_string';
      }

      final updated = contents.replaceFirst(oldString, newString);
      await file.writeAsString(updated);
      return 'Successfully edited $path (single replacement applied)';
    } catch (e) {
      return 'Error editing file: $e';
    }
  }

  static Future<String> writeFile(dynamic _, Map<String, dynamic> args) async {
    try {
      final path = args['path'];
      final content = args['content'];
      if (path is! String || path.isEmpty) return 'Error: path must be a non-empty string';
      if (content is! String) return 'Error: content is required';

      final append = args['append'] as bool? ?? false;
      final file = File(path);
      await file.parent.create(recursive: true);

      if (append) {
        await file.writeAsString(content, mode: FileMode.append);
        return 'Successfully appended to file: $path';
      } else {
        await file.writeAsString(content);
        return 'Successfully wrote to file: $path';
      }
    } catch (e) {
      return 'Error writing file: $e';
    }
  }

  static Future<String> executeShellCommand(dynamic provider, Map<String, dynamic> args) async {
    try {
      final String command = args['command'];
      final String? workingDirectory = args['workingDirectory'];

      final lowerCommand = command.toLowerCase();
      const dangerousPatterns = [
        'rm -rf /',
        'del /f /s /q c:\\',
        'format',
        'mkfs',
        ':(){:|:&};:',
      ];
      for (final pattern in dangerousPatterns) {
        if (lowerCommand.contains(pattern)) {
          return 'Error: Dangerous command blocked for safety: $command';
        }
      }

      var shell = Shell();
      if (workingDirectory != null && workingDirectory.isNotEmpty) {
        shell.navigate(workingDirectory);
      }

      final parts = _parseShellCommand(command);
      if (parts.isEmpty) return 'Error: Empty command';

      final commandName = parts.first;
      final commandArgs = parts.length > 1 ? parts.sublist(1) : <String>[];

      String stdout = '';
      String stderr = '';
      int exitCode = 0;

      try {
        final process = await shell.start(commandName, arguments: commandArgs).timeout(const Duration(seconds: 30));
        stdout = await process.stdout.readAsString();
        stderr = await process.stderr.readAsString();
        exitCode = await process.exitCode;

        if (stdout.length > 10240) {
          stdout = '${stdout.substring(0, 10240)}\n... (output truncated)';
        }
        if (stderr.length > 10240) {
          stderr = '${stderr.substring(0, 10240)}\n... (output truncated)';
        }
      } on TimeoutException {
        return 'Error: Command timed out after 30 seconds';
      } catch (e) {
        return 'Error executing command: $e';
      }

      final time = DateTime.now().millisecondsSinceEpoch;
      final shellMessage = FluentChatMessage.shellExec(
        id: '${time}_shell',
        command: command,
        exitCode: exitCode,
        stdout: stdout,
        stderr: stderr,
        timestamp: time,
      );

      (provider as ChatProvider).addCustomMessageToList(shellMessage);

      final summary = StringBuffer();
      summary.writeln('Command: $command');
      summary.writeln('Exit code: $exitCode');
      if (stdout.isNotEmpty) {
        summary.writeln('Output:');
        summary.writeln(stdout.length > 500 ? '${stdout.substring(0, 500)}...' : stdout);
      } else {
        summary.writeln('Output: (empty)');
      }
      if (stderr.isNotEmpty) {
        summary.writeln('Errors:');
        summary.writeln(stderr.length > 500 ? '${stderr.substring(0, 500)}...' : stderr);
      }
      return summary.toString();
    } catch (e) {
      return 'Error: $e';
    }
  }

  static Future<String> copyToClipboard(dynamic _, Map<String, dynamic> args) async {
    final textToCopy = args['clipboard'];
    await Clipboard.setData(ClipboardData(text: textToCopy));
    displayCopiedToClipboard();
    return 'Successfully copied to clipboard: $textToCopy';
  }

  static Future<String> autoOpenUrls(dynamic _, Map<String, dynamic> args) async {
    final url = args['url'];
    if (await canLaunchUrlString(url)) {
      final res = await launchUrlString(url);
      if (res) return 'Successfully opened url: $url';
    }
    return 'Was not able to open url: $url';
  }

  static Future<String> generateImage(dynamic provider, Map<String, dynamic> args) async {
    final prompt = args['prompt'];
    final size = args['size'];
    return (provider as ChatProvider).generateImageFromTool(prompt: prompt, size: size);
  }

  static Future<String> rememberInfo(dynamic provider, Map<String, dynamic> args) async {
    final p = provider as ChatProvider;
    final info = args['info'];
    final responseMessage = args['responseMessage'];
    final time = DateTime.now().millisecondsSinceEpoch;
    final funcText = '```remember\n$info\n```';
    AppCache.userInfo.saveInfoToFile(info);

    p.addBotMessageToList(
      FluentChatMessage.ai(
        id: time.toString(),
        content: '$funcText\n$responseMessage',
        timestamp: time,
        creator: selectedChatRoom.characterName,
        tokens: await p.countTokensString('$funcText\n$responseMessage'),
      ),
    );
    return 'Successfully remembered info: $info';
  }
}
