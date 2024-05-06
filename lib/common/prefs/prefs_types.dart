import 'package:chatgpt_windows_flutter_app/main.dart';

abstract class _Pref<T> {
  final String key;

  const _Pref(this.key);
  T? get value;
  set value(T? value);
  Future<void> set(T value);
  Future<void>? remove() => prefs?.remove(key);
}

class StringPref extends _Pref<String> {
  const StringPref(super.key);

  @override
  String? get value => prefs?.get(key) as String?;
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
