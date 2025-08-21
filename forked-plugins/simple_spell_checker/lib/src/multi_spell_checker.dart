import 'dart:async' show Stream, StreamController;
import 'package:flutter/gestures.dart' show LongPressGestureRecognizer;
import 'package:flutter/material.dart';
import 'package:simple_spell_checker/simple_spell_checker.dart'
    show LanguageIdentifier;
import 'package:simple_spell_checker/src/spell_checker_interface/abtract_checker.dart';
import 'package:simple_spell_checker/src/spell_checker_interface/mixin/stream_checks.dart';
import 'package:simple_spell_checker/src/word_tokenizer.dart';
import 'common/cache_object.dart' show CacheObject;
import 'common/tokenizer.dart';

CacheObject<List<LanguageIdentifier>>? _cacheLanguageIdentifiers;

/// add a cache var to avoid always reload all dictionary (it's a heavy task)
/// and it is automatically reloaded when [_cacheLanguageIdentifier] change
CacheObject<Map<String, int>>? _cacheWordDictionary;

/// A multi spell checker that split on different spans
/// the wrong words from the right ones.
///
/// MultiSpellChecker automatically make a cache of the dictionary and languages
/// to avoid always reload a bigger text file with too much words to be parsed to a valid
/// format checking it.
///
/// This checker use a multiple languages into itself
/// you can see this like you spell checker have selected
/// different languages like: "en", "es", "ru" and if you want
/// to use some word from Russian language the checker can
/// check correctly the Russian word from the other ones
//
// if you want to update the language and the directory you will need to use
//
// first:
// [setNewLanguage] method to override the current language from the class
// second:
// [reloadDictionary] or [reloadDictionarySync] methods to set a new state to the directionary
@Deprecated(
    'MultiSpellChecker should not be used and will be removed in future releases.')
class MultiSpellChecker
    extends Checker<List<String>, List<String>, List<TextSpan>>
    implements CheckOperationsStreams<List<TextSpan>> {
  List<LanguageIdentifier>? customLanguages;
  // ignore: unused_field
  late Tokenizer<List<String>> _wordTokenizer;
  MultiSpellChecker({
    required super.language,
    Tokenizer<List<String>>? wordTokenizer,
    super.safeDictionaryLoad,
    super.worksWithoutDictionary,
    super.caseSensitive = false,
    super.safeLanguageName,
    super.strategy,
    List<String> whiteList = const [],
    bool autoAddLanguagesFromCustomDictionaries = false,
    this.customLanguages,
  }) : super(whiteList: whiteList) {
    _cacheWordDictionary = null;
    _cacheLanguageIdentifiers = null;
    if (autoAddLanguagesFromCustomDictionaries) {
      registryLanguagesFromCustomDictionaries();
    }
    initializeChecker(
      language: getCurrentLanguage(),
      safeDictionaryLoad: safeDictionaryLoad,
      whiteList: whiteList,
      worksWithoutDictionary: worksWithoutDictionary,
      safeLanguageName: safeLanguageName,
      strategy: strategy,
      caseSensitive: caseSensitive,
    );
    _wordTokenizer = wordTokenizer ?? WordTokenizer();
  }

  @protected
  void registryLanguagesFromCustomDictionaries() {}

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
    return [];
  }

  /// Check spelling in realtime
  ///
  /// [removeEmptyWordsOnTokenize] this remove empty strings that was founded while splitting the text
  /// [customLongPressRecognizerOnWrongSpan] let you add a custom recognizer for when you need to show suggestions
  /// or make some custom action for wrong words
  @override
  Stream<List<TextSpan>> checkStream(
    String text, {
    TextStyle? wrongStyle,
    TextStyle? commonStyle,
    LongPressGestureRecognizer Function(String)?
        customLongPressRecognizerOnWrongSpan,
  }) async* {
    yield [];
  }

  /// a custom implementation for check if your line wrong words and return a custom list of widgets
  ///
  /// [removeEmptyWordsOnTokenize] this remove empty strings that was founded while splitting the text
  @override
  List<O>? checkBuilder<O>(
    String text, {
    required O Function(String, bool) builder,
  }) {
    return null;
  }

  /// a custom implementation that let us subcribe to it and listen
  /// all changes on realtime the list of wrong and right words
  ///
  /// # Note
  /// By default, this stream not update the default [StreamController] of the spans
  /// implemented in the class
  ///
  /// [removeEmptyWordsOnTokenize] this remove empty strings that was founded while splitting the text
  @override
  Stream<List<T>> checkBuilderStream<T>(
    String text, {
    required T Function(String, bool) builder,
  }) async* {
    yield [];
  }

  /// Check if the word are registered on the dictionary
  ///
  /// This will throw error if the SimpleSpellChecker is non
  /// initilizated
  @override
  @protected
  bool isWordValid(String word) {
    return false;
  }

  (bool, LanguageIdentifier?) _customContainsLanguage(String lan) {
    return (false, null);
  }

  @override
  void reloadDictionarySync() async {}

  /// Set a new cusotm Tokenizer instance to be used by the package
  void setNewTokenizer(Tokenizer<List<String>> tokenizer) {}

  /// Reset the Tokenizer instance to use the default implementation
  /// crated by the package
  void setWordTokenizerToDefault() {}

  @override
  @protected
  void setNewLanguageToState(List<String> language) {
    super.setNewLanguageToState(language);
  }

  /// override the current languages
  void setNewLanState(List<String> languages) {
    super.setNewLanguageToState(List.from(languages));
  }

  /// add a new language keeping the current ones
  void setNewLanguageToCurrentLanguages(String language) {
    super.setNewLanguageToState([language, ...getCurrentLanguage()]);
  }

  @override
  @protected
  void initDictionary(String words) {}

  @override
  void dispose({bool closeDictionary = false}) {
    super.dispose();
    if (closeDictionary) _cacheWordDictionary = null;
    _cacheLanguageIdentifiers = null;
  }

  /// This will return all the words contained on the current state of the dictionary
  Map<String, int>? getDictionary() {
    verifyState();
    return _cacheWordDictionary?.get;
  }

  @override
  @protected
  void verifyState({bool alsoCache = false}) {
    super.verifyState();
    if (alsoCache) {
      assert(_cacheWordDictionary != null);
      assert(_cacheLanguageIdentifiers != null);
    }
  }

  @override
  @protected
  bool checkLanguageRegistry(List<String> language) {
    return true;
  }

  @override
  void addCustomLanguage(LanguageIdentifier language) {}

  /// search if the custom language exist and update if it is founded
  void updateCustomLanguageIfExist(LanguageIdentifier language,
      [bool withException = true]) {}
}
