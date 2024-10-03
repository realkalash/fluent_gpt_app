// ignore_for_file: avoid_print

import 'dart:io';

import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/main.dart';
import 'package:flutter/gestures.dart';
import 'package:path_provider/path_provider.dart';

abstract class _Pref<T> {
  final String key;

  const _Pref(this.key);
  T? get value;
  set value(T? value);
  Future<void> set(T value);
  Future<void>? remove() => prefs?.remove(key);
}

class StringPref extends _Pref<String> {
  const StringPref(super.key, [this.defaultValue]);
  final String? defaultValue;

  @override
  String? get value => prefs?.get(key) as String? ?? defaultValue;
  @override
  Future<void> set(String value) async => (prefs)?.setString(key, value);

  @override
  set value(String? value) {
    if (value == null) {
      remove();
    } else {
      set(value);
    }
  }
}

// File String pref for saving a file into a app folder
class FileStringPref {
  /// FileName can be a path+filename
  const FileStringPref(this.fileName);
  final String fileName;
  Future<String> appDirectoryPath() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      return dir.path;
    } catch (e) {
      print('Error getting app getApplicationDocumentsDirectory path: $e');
    }
    try {
      final dir = await getApplicationSupportDirectory();
      return dir.path;
    } catch (e) {
      print('Error getting app getApplicationSupportDirectory path: $e');
    }
    try {
      final dir = await getDownloadsDirectory();
      return dir!.path;
    } catch (e) {
      print('Error getting app getDownloadsDirectory path: $e');
    }
    return '';
  }

  Future<String> value() async {
    final path = await appDirectoryPath();
    final filePath = '$path/$fileName';
    //if not exist, create file and return empty string
    final file = File(filePath);
    if (!file.existsSync()) {
      try {
        file.create(recursive: true);
      } catch (e) {
        log('Error creating file: $e');
      }
      return '';
    }
    return file.readAsStringSync();
  }

  Future<void> set(String value) async {
    final path = await appDirectoryPath();
    final filePath = '$path/$fileName';
    final file = File(filePath);
    if (!file.existsSync()) {
      try {
        file.create(recursive: true);
      } catch (e) {
        log('Error creating file: $e');
      }
    }
    try {
      file.writeAsStringSync(value);
    } catch (e) {
      log('Error writing file: $e');
    }
  }

  Future remove() async {
    final path = await appDirectoryPath();
    final filePath = '$path/$fileName';
    final file = File(filePath);
    if (file.existsSync()) {
      try {
        file.delete();
      } catch (e) {
        log('Error deleting file: $e');
      }
    }
  }
}

class IntPref extends _Pref<int> {
  const IntPref(super.key, [this.defaultValue]);
  final int? defaultValue;
  @override
  int? get value => (prefs?.get(key) as int?) ?? defaultValue;
  @override
  Future<void> set(int value) => prefs!.setInt(key, value);

  @override
  set value(int? value) {
    if (value == null) {
      remove();
    } else {
      set(value);
    }
  }
}

class OffsetPref extends _Pref<Offset> {
  const OffsetPref(super.key, [this.defaultValue]);
  final Offset? defaultValue;
  @override
  Offset? get value {
    final value = prefs?.get(key) as String?;
    if (value == null) {
      return defaultValue;
    }
    final parts = value.split(',');
    return Offset(double.parse(parts[0]), double.parse(parts[1]));
  }

  @override
  Future<void> set(Offset value) =>
      prefs!.setString(key, '${value.dx},${value.dy}');

  @override
  set value(Offset? value) {
    if (value == null) {
      remove();
    } else {
      set(value);
    }
  }
}

class DoublePref extends _Pref<double> {
  const DoublePref(super.key);

  @override
  double? get value => prefs?.get(key) as double?;
  @override
  Future<void> set(double value) => prefs!.setDouble(key, value);

  @override
  set value(double? value) {
    if (value == null) {
      remove();
    } else {
      set(value);
    }
  }
}

class BoolPref extends _Pref<bool> {
  const BoolPref(super.key, [this.defaultValue]);
  final bool? defaultValue;

  @override
  bool? get value => (prefs?.get(key) as bool?) ?? defaultValue;
  @override
  Future<void> set(bool value) => prefs!.setBool(key, value);

  @override
  set value(bool? value) {
    if (value == null) {
      remove();
    } else {
      set(value);
    }
  }
}
