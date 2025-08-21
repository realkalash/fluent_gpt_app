import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

@Deprecated(
    'CheckOperationsStreams is no longer used and will be removed on future releases.')
mixin CheckOperationsStreams<T extends Object> {
  @Deprecated(
      'checkStream should not be used and will be removed on future releases.')
  Stream<T?> checkStream(
    String text, {
    TextStyle? wrongStyle,
    TextStyle? commonStyle,
    LongPressGestureRecognizer Function(String)?
        customLongPressRecognizerOnWrongSpan,
  });

  @Deprecated(
      'checkBuilderStream should not be used and will be removed on future releases.')
  Stream<List<O>> checkBuilderStream<O>(
    String text, {
    required O Function(String, bool) builder,
  });
}
