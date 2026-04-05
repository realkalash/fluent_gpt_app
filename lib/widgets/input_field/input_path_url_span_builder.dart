import 'package:extended_text_field/extended_text_field.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

/// Regex-based rich spans for the chat input: `[path:...]` (compact chip) and `https?://...` (link style).
class InputFieldRichSpanBuilder extends RegExpSpecialTextSpanBuilder {
  InputFieldRichSpanBuilder({
    required this.accentColor,
    required this.chipBackground,
    required this.linkColor,
    required this.baseStyle,
  });

  final Color accentColor;
  final Color chipBackground;
  final Color linkColor;
  final TextStyle? baseStyle;

  @override
  List<RegExpSpecialText> get regExps => [
        _PathBracketRegExp(
          accentColor: accentColor,
          chipBackground: chipBackground,
          baseStyle: baseStyle,
        ),
        _HttpUrlRegExp(
          linkColor: linkColor,
          baseStyle: baseStyle,
        ),
      ];
}

String _pathTokenDisplayLabel(String innerPath) {
  final normalized = innerPath.replaceAll('\\', '/');
  final parts = normalized.split('/').where((s) => s.isNotEmpty).toList();
  final name = parts.isEmpty ? innerPath : parts.last;
  if (name.length > 48) {
    return '📁 ${name.substring(0, 45)}…';
  }
  return '📁 $name';
}

class _PathBracketRegExp extends RegExpSpecialText {
  _PathBracketRegExp({
    required this.accentColor,
    required this.chipBackground,
    required this.baseStyle,
  });

  final Color accentColor;
  final Color chipBackground;
  final TextStyle? baseStyle;

  /// Full token `[path:...]`; inner path must not contain `]`.
  @override
  RegExp get regExp => RegExp(r'\[path:[^\]]+\]');

  @override
  InlineSpan finishText(
    int start,
    Match match, {
    TextStyle? textStyle,
    SpecialTextGestureTapCallback? onTap,
  }) {
    final full = match[0]!;
    final inner = full.substring('[path:'.length, full.length - 1);
    final label = _pathTokenDisplayLabel(inner);
    final merged = baseStyle?.merge(textStyle) ?? textStyle;
    return BackgroundTextSpan(
      text: label,
      actualText: full,
      start: start,
      deleteAll: true,
      style: merged?.copyWith(
        color: accentColor,
        fontWeight: FontWeight.w500,
        fontSize: merged.fontSize,
      ),
      background: Paint()..color = chipBackground,
      clipBorderRadius: BorderRadius.circular(4),
    );
  }
}

class _HttpUrlRegExp extends RegExpSpecialText {
  _HttpUrlRegExp({
    required this.linkColor,
    required this.baseStyle,
  });

  final Color linkColor;
  final TextStyle? baseStyle;

  @override
  RegExp get regExp => RegExp(r'https?://[^\s<>\[\]`]+');

  @override
  InlineSpan finishText(
    int start,
    Match match, {
    TextStyle? textStyle,
    SpecialTextGestureTapCallback? onTap,
  }) {
    final url = match[0]!;
    final merged = baseStyle?.merge(textStyle) ?? textStyle;
    return SpecialTextSpan(
      text: '🔗 $url',
      actualText: url,
      start: start,
      deleteAll: true,
      style: merged?.copyWith(
        color: linkColor,
        decoration: TextDecoration.underline,
        decorationColor: linkColor,
      ),
      recognizer: TapGestureRecognizer()
        ..onTap = () {
          launchUrlString(url, mode: LaunchMode.externalApplication);
        },
    );
  }
}
