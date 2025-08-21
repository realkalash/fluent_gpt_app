import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

mixin CheckOperations<T extends Object, R> {
  bool isWordValid(String word);
  @Deprecated(
      'reloadDictionary should not be used and will be removed on future releases.')
  Future<void> reloadDictionary();
  @Deprecated(
      'checkLanguageRegistry is no longer used and will be removed in future releases.')
  bool checkLanguageRegistry(R language);
  @Deprecated(
      'reloadDictionarySync is no longer used and will be removed in future releases.')
  void reloadDictionarySync();
  T? check(
    String text, {
    TextStyle? wrongStyle,
    TextStyle? commonStyle,
    LongPressGestureRecognizer Function(String)?
        customLongPressRecognizerOnWrongSpan,
  });

  List<O>? checkBuilder<O>(
    String text, {
    required O Function(String, bool) builder,
  });
}
