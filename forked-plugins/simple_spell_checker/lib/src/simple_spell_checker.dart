import 'dart:async' show Stream, StreamController;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show LongPressGestureRecognizer;
import 'package:flutter/material.dart'
    show Colors, TextDecoration, TextDecorationStyle, TextSpan, TextStyle;
import 'package:simple_spell_checker/src/common/extensions.dart';
import 'package:simple_spell_checker/src/common/language_identifier.dart';
import 'package:simple_spell_checker/src/spell_checker_interface/abtract_checker.dart';
import 'package:simple_spell_checker/src/utils.dart';
import 'package:simple_spell_checker/src/word_tokenizer.dart';
import 'common/strategy_language_search_order.dart';
import 'common/tokenizer.dart';

/// A simple spell checker that split on different spans
/// the wrong words from the right ones.
///
/// SimpleSpellchecker automatically make a cache of the dictionary and languages
/// to avoid always reload a bigger text file with too much words to be parsed to a valid
/// format checking it.
class SimpleSpellChecker extends Checker<String, String, List<TextSpan>> {
  /// By default we only have support for the most used languages
  /// but, we cannot cover all the cases. By this, you can use [customLanguages]
  /// adding the key of the language and your words
  ///
  /// Note: [words] param must be have every element separated by a new line
  @Deprecated(
      'customLanguages is no longer used and will be removed in future releases.')
  List<LanguageIdentifier>? customLanguages;
  late Tokenizer<List<String>> _wordTokenizer;
  SimpleSpellChecker({
    required super.language,
    Tokenizer<List<String>>? wordTokenizer,
    List<String> whiteList = const [],
    super.caseSensitive = false,
    @Deprecated(
        'safeLanguageName since customLanguages are no longer used and will be removed in future releases.')
    super.safeLanguageName,
    @Deprecated(
        'autoAddLanguagesFromCustomDictionaries since customLanguages are no longer used and will be removed in future releases.')
    bool autoAddLanguagesFromCustomDictionaries = false,
    @Deprecated(
        'safeDictionaryLoad is no longer used and will be removed in future releases.')
    super.safeDictionaryLoad,
    @Deprecated(
        'worksWithoutDictionary is no longer used and will be removed in future releases.')
    super.worksWithoutDictionary,
    @Deprecated(
        'strategy is no longer used and will be removed in future releases.')
    super.strategy = StrategyLanguageSearchOrder.byPackage,
    @Deprecated(
        'customLanguages is no longer used and will be removed in future releases.')
    this.customLanguages,
  }) {
    _wordTokenizer = wordTokenizer ?? WordTokenizer();
    initializeChecker(
      language: getCurrentLanguage(),
      caseSensitive: caseSensitive,
    );
  }

  /// Check if your line wrong words
  ///
  /// [removeEmptyWordsOnTokenize] this remove empty strings that was founded while splitting the text
  /// [customLongPressRecognizerOnWrongSpan] let you add a custom recognizer for when you need to show suggestions
  /// or make some custom action for wrong words
  @override
  List<TextSpan>? check(
    String text, {
    TextStyle? wrongStyle,
    TextStyle? commonStyle,
    LongPressGestureRecognizer Function(String)?
        customLongPressRecognizerOnWrongSpan,
  }) {
    if (!isActiveChecking) {
      return null;
    }
    verifyState();

    if (dictionaries[getCurrentLanguage()] == null) {
      return null;
    }
    if (!_wordTokenizer.canTokenizeText(text)) return null;
    final spans = <TextSpan>[];
    final words = _wordTokenizer.tokenize(text);
    for (int i = 0; i < words.length; i++) {
      final word = words.elementAt(i);
      final nextIndex = (i + 1) < words.length - 1 ? i + 1 : -1;
      if (isWordHasNumber(word) ||
          isWordValid(word) ||
          word.contains(' ') ||
          word.noWords) {
        if (nextIndex != -1) {
          final nextWord = words.elementAt(nextIndex);
          if (nextWord.contains(' ')) {
            spans.add(TextSpan(text: '$word$nextWord', style: commonStyle));
            // ignore the next since it was already passed
            i++;
            continue;
          }
        }
        spans.add(TextSpan(text: word, style: commonStyle));
      } else if (!isWordValid(word)) {
        final longTap = customLongPressRecognizerOnWrongSpan?.call(word);
        spans.add(
          TextSpan(
            text: word,
            recognizer: longTap,
            style: wrongStyle ??
                const TextStyle(
                  decorationColor: Colors.red,
                  decoration: TextDecoration.underline,
                  decorationStyle: TextDecorationStyle.wavy,
                  decorationThickness: 1.75,
                ),
          ),
        );
      }
    }
    return [...spans];
  }

  /// a custom implementation for check if your line wrong words and return a custom list of widgets
  ///
  /// [removeEmptyWordsOnTokenize] this remove empty strings that was founded while splitting the text
  @override
  List<O>? checkBuilder<O>(
    String text, {
    required O Function(String, bool) builder,
  }) {
    if (!isActiveChecking) {
      return null;
    }
    verifyState();
    if (dictionaries[getCurrentLanguage()] == null) {
      throw UnsupportedError(
          'The ${getCurrentLanguage()} is not supported or registered. Please, first add your new language using [setLanguage] to avoid this message.');
    }
    if (!_wordTokenizer.canTokenizeText(text)) return null;
    final spans = <O>[];
    final words = _wordTokenizer.tokenize(text);
    for (int i = 0; i < words.length; i++) {
      final word = words.elementAt(i);
      final nextIndex = (i + 1) < words.length - 1 ? i + 1 : -1;
      if (isWordHasNumber(word) ||
          isWordValid(word) ||
          word.contains(' ') ||
          word.noWords) {
        if (nextIndex != -1) {
          final nextWord = words.elementAt(nextIndex);
          if (nextWord.contains(' ')) {
            spans.add(builder.call('$word$nextWord', true));
            // ignore the next since it was already passed
            i++;
            continue;
          }
        }
        spans.add(builder.call(word, true));
      } else if (!isWordValid(word)) {
        spans.add(builder.call(word, false));
      }
    }
    return [...spans];
  }

  /// Check if the word are registered on the dictionary
  ///
  /// This will throw error if the SimpleSpellChecker is non
  /// initilizated
  @override
  @protected
  bool isWordValid(String word) {
    // if word is just an whitespace then is not wrong
    if (word.trim().isEmpty) return true;
    if (whiteList.contains(word)) return true;
    verifyState();
    final wordsMap = dictionaries[getCurrentLanguage()] ?? {};
    final newWordWithCaseSensitive =
        caseSensitive ? word.toLowerCaseFirst() : word.trim().toLowerCase();
    final int? validWord = wordsMap[newWordWithCaseSensitive];
    return validWord != null && validWord == 1;
  }

  /// Set a new cusotm Tokenizer instance to be used by the package
  void setNewTokenizer(Tokenizer<List<String>> tokenizer) {
    verifyState();
    _wordTokenizer = tokenizer;
  }

  /// Reset the Tokenizer instance to use the default implementation
  /// crated by the package
  void setWordTokenizerToDefault() {
    verifyState();
    _wordTokenizer = WordTokenizer();
  }

  @override
  void dispose({
    @Deprecated(
        'closeDictionary is no longer used and will be removed in future releases.')
    bool closeDictionary = false,
  }) {
    super.dispose();
  }

  /// This will return all the words contained on the current state of the dictionary
  Map<String, int>? getDictionary() {
    verifyState();
    return dictionaries[getCurrentLanguage()];
  }

  @override
  @protected
  void verifyState({
    @Deprecated(
        'alsoCache is no longer used and will be removed in future releases.')
    bool alsoCache = false,
  }) {
    super.verifyState();
  }

  static void setLanguage(String language, Map<String, int> words) {
    assert(language.trim().isNotEmpty,
        'language param cannot be empty or just contain whitespaces. Got [$language]');
    if(dictionaries.containsKey(language)) return;
    dictionaries.addAll({language: words});
  }

  static void unlearnWord(String language, String word) {
    assert(language.trim().isNotEmpty,
        'language param cannot be empty or just contain whitespaces. Got [$language]');
    if (!dictionaries.containsKey(language)) return;
    final dictionary = dictionaries[language] ?? {};
    dictionary.remove(word);
    dictionaries[language] = dictionary;
  }

  static void learnWord(String language, String word) {
    assert(language.trim().isNotEmpty,
        'language param cannot be empty or just contain whitespaces. Got [$language]');
    if (!dictionaries.containsKey(language)) return;
    final dictionary = dictionaries[language] ?? {};
    dictionary.addAll({word: 1});
    dictionaries[language] = dictionary;
  }

  static bool containsLanguage(String language){
    return dictionaries.containsKey(language);
  }

  static void removeLanguage(String language){
    dictionaries.remove(language);
  }

  /// Check spelling in realtime
  ///
  /// [removeEmptyWordsOnTokenize] this remove empty strings that was founded while splitting the text
  /// [customLongPressRecognizerOnWrongSpan] let you add a custom recognizer for when you need to show suggestions
  /// or make some custom action for wrong words
  @Deprecated(
      'checkStream should not be used and will be removed on future releases.')
  Stream<List<TextSpan>> checkStream(
    String text, {
    TextStyle? wrongStyle,
    TextStyle? commonStyle,
    LongPressGestureRecognizer Function(String)?
        customLongPressRecognizerOnWrongSpan,
  }) async* {
    yield [];
  }

  /// a custom implementation that let us subcribe to it and listen
  /// all changes on realtime the list of wrong and right words
  ///
  /// # Note
  /// By default, this stream not update the default [StreamController] of the spans
  /// implemented in the class
  ///
  /// [removeEmptyWordsOnTokenize] this remove empty strings that was founded while splitting the text
  @Deprecated(
      'checkBuilderStream should not be used and will be removed on future releases.')
  Stream<List<T>> checkBuilderStream<T>(
    String text, {
    required T Function(String, bool) builder,
  }) async* {
    yield [];
  }

  @override
  @protected
  @Deprecated(
      'checkLanguageRegistry is no longer stable and should not be used. It will be removed in future releases.')
  bool checkLanguageRegistry(String language) {
    return true;
  }

  @override
  @Deprecated(
      'addCustomLanguage is no longer used and will be removed on future releases')
  void addCustomLanguage(LanguageIdentifier language) {}

  @Deprecated(
      'updateCustomLanguageIfExist is no longer used and will be removed on future releases')
  void updateCustomLanguageIfExist(LanguageIdentifier language) {}

  @protected
  @Deprecated(
      'registryLanguagesFromCustomDictionaries is no longer used and will be removed on future releases')
  void registryLanguagesFromCustomDictionaries() {}

  @override
  @Deprecated(
      'setNewStrategy is no longer used and will be removed on future releases')
  void setNewStrategy(StrategyLanguageSearchOrder strategy) {}

  /// this count about a accidental recursive calling
  @override
  @Deprecated(
      'reloadDictionarySync is no longer used and will be removed in future releases.')
  void reloadDictionarySync() async {}

  @override
  @protected
  @Deprecated(
      'initDictionary is no longer used and will be removed in future releases.')
  void initDictionary(dynamic words) {}
}
