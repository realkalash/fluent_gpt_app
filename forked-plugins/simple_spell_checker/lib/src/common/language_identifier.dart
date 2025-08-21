import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart' show immutable;

/// [LanguageIdentifier] is a representation of a register of a language with it's dictionary
///   [language] ref to the country code
///   [word] ref to the dictionary
@immutable
@Deprecated(
    'LanguageIdentifier is no longer used and will be removed in future releases.')
class LanguageIdentifier {
  final String language;
  final Map<String, int> words;

  const LanguageIdentifier({
    required this.language,
    required this.words,
  });

  LanguageIdentifier copyWith({
    String? language,
    @Deprecated(
        'words is no longer used since words is map type. Use wordsMap instead')
    String? words,
    Map<String, int>? wordsMap,
  }) {
    return LanguageIdentifier(
      language: language ?? this.language,
      words: wordsMap ?? this.words,
    );
  }

  @override
  bool operator ==(covariant LanguageIdentifier other) {
    if (identical(this, other)) return true;
    return language == other.language &&
        const DeepCollectionEquality().equals(words, other.words);
  }

  @override
  int get hashCode => language.hashCode ^ words.hashCode;
}
