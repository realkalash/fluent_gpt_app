import 'dart:async';
import 'package:meta/meta.dart';
import 'package:simple_spell_checker/src/spell_checker_interface/mixin/disposable.dart';
import '../common/language_identifier.dart';
import '../common/strategy_language_search_order.dart';
import 'mixin/check_ops.dart';

abstract class Checker<T extends Object, R, OP extends Object>
    with CheckOperations<OP, R>, Disposable, DisposableStreams {
  final Set<String> _whiteList = {};
  late T _language;

  /// if it is true the checker always will be return null
  bool _turnOffChecking = false;

  /// If the current language is not founded on [customLanguages] or default ones,
  /// then select one of the existent to avoid conflicts
  @Deprecated(
      '_safeDictionaryLoad is no longer used and will be removed in future releases.')
  late bool _safeDictionaryLoad;

  /// If it is true then the spell checker
  /// ignores if the dictionary or language is not founded
  @Deprecated(
      '_worksWithoutDictionary is no longer used and will be removed in future releases')
  late bool _worksWithoutDictionary;

  final bool caseSensitive;

  /// the state of SimpleSpellChecker and to store to a existent language with its dictionary
  /// If _safeDictionaryLoad is true, this will be used as the default language to update
  final String safeLanguageName;
  @Deprecated(
      'strategy is no longer used and will be removed in future releases.')
  StrategyLanguageSearchOrder strategy;

  /// decide if the checker is disposed
  bool _disposed = false;

  /// this just can be called on closeControllers
  bool _disposedControllers = false;

  @Deprecated(
      '_simpleSpellCheckerWidgetsState is no longer used and will be removed in future releases.')
  final StreamController<Object?> _simpleSpellCheckerWidgetsState =
      StreamController.broadcast();
  final StreamController<T?> _languageState = StreamController.broadcast();
  Checker({
    required T language,
    List<String> whiteList = const [],
    this.caseSensitive = true,
    this.safeLanguageName = 'en',
    @Deprecated(
        'safeDictionaryLoad is no longer used and will be removed in future releases.')
    bool safeDictionaryLoad = false,
    @Deprecated(
        'worksWithoutDictionary is no longer used and will be removed in future releases')
    bool worksWithoutDictionary = false,
    @Deprecated(
        'strategy is no longer used and will be removed in future releases.')
    this.strategy = StrategyLanguageSearchOrder.byPackage,
  }) {
    initializeChecker(
      language: language,
      whiteList: whiteList,
      safeLanguageName: safeLanguageName,
      caseSensitive: caseSensitive,
    );
  }

  @protected
  @Deprecated(
      'safeDictionaryLoad is no longer used and will be removed in future releases.')
  bool get safeDictionaryLoad => _safeDictionaryLoad;

  @protected
  @Deprecated(
      'turnOffChecking is no longer used and will be removed in future releases.'
      'Use isActiveChecking instead')
  bool get turnOffChecking => _turnOffChecking;

  @protected
  bool get isActiveChecking => !_turnOffChecking;

  @protected
  @Deprecated(
      'setRegistryToDefault is no longer used and will be removed in future releases.')
  void setRegistryToDefault() {}

  @protected
  @Deprecated(
      'worksWithoutDictionary is no longer used and will be removed in future releases')
  bool get worksWithoutDictionary => _worksWithoutDictionary;

  List<String> get whiteList => [..._whiteList];

  void addNewWordToWhiteList(String word) {
    assert(word.trim().isNotEmpty, '[$word] cannot be empty');
    assert(!word.contains(RegExp(r'\p{Z}', unicode: true)),
        '[$word] cannot contain whitespaces');
    final words = word.split('\n');
    if (words.length >= 2) {
      _whiteList.addAll(words.map((element) => element.trim()));
    } else {
      _whiteList.add(word.trim());
    }
  }

  void setNewWhiteList(List<String> words) {
    _whiteList.clear();
    _whiteList.addAll(words);
  }

  /// [initDictionary] is a method used when the dictionary need to be
  /// loaded before of use it on [check()] functions
  ///
  /// Here we can place all necessary logic to initalize an valid directionary
  /// used by [isWordValid] method
  ///
  /// You can use [defaultLanguagesDictionarie] that correspond with the current
  /// languages implemented into the package
  @protected
  @Deprecated(
      'initDictionary is no longer used and will be removed in future releases.')
  void initDictionary(String words);

  Stream get languageStream {
    verifyState();
    return _languageState.stream;
  }

  @Deprecated(
      'stream method is not stable at the moment and will removed in future releases')
  Stream get stream {
    verifyState();
    return _simpleSpellCheckerWidgetsState.stream;
  }

  @Deprecated(
      'addCustomLanguage is no longer used and will be removed in future releases.')
  void addCustomLanguage(LanguageIdentifier language);

  @protected
  @mustCallSuper
  void addNewEventToLanguageState(T? language) {
    if (!_languageState.isClosed || !_disposedControllers) {
      _languageState.add(_language);
    }
  }

  @protected
  @mustCallSuper
  @Deprecated(
      'addNewEventToWidgetsState is no longer used and will be removed in future releases')
  void addNewEventToWidgetsState(Object? object) {
    if (!_simpleSpellCheckerWidgetsState.isClosed || !_disposedControllers) {
      _simpleSpellCheckerWidgetsState.add(object);
    }
  }

  /// Use dispose when you don't need the SimpleSpellchecker already
  @override
  @mustCallSuper
  void dispose() {
    // by now we will not removed this line since we need close the [StreamController]
    // ignore: deprecated_member_use_from_same_package
    if (!_simpleSpellCheckerWidgetsState.isClosed)
      _simpleSpellCheckerWidgetsState.close();
    if (!_languageState.isClosed) _languageState.close();
    _disposed = true;
    _disposedControllers = true;
  }

  /// Use disposeControllers is just never will be use the StreamControllers
  @override
  @mustCallSuper
  void disposeControllers() {
    // by now we will not removed this line since we need close the [StreamController]
    // ignore: deprecated_member_use_from_same_package
    if (!_simpleSpellCheckerWidgetsState.isClosed)
      _simpleSpellCheckerWidgetsState.close();
    if (!_languageState.isClosed) _languageState.close();
    _disposedControllers = true;
  }

  /// This will return all the words contained on the current state of the dictionary
  @mustCallSuper
  T getCurrentLanguage() {
    verifyState();
    return _language;
  }

  /// Initialize important parts of the Checker
  @protected
  void initializeChecker({
    required T language,
    List<String> whiteList = const [],
    bool caseSensitive = true,
    @Deprecated(
        'safeLanguageName is no longer used and will be removed in future releases.')
    String safeLanguageName = 'en',
    @Deprecated(
        'safeDictionaryLoad is no longer used and will be removed in future releases.')
    bool safeDictionaryLoad = false,
    @Deprecated(
        'worksWithoutDictionary is no longer used and will be removed in future releases.')
    bool worksWithoutDictionary = false,
    @Deprecated(
        'strategy is no longer used and will be removed in future releases.')
    StrategyLanguageSearchOrder strategy =
        StrategyLanguageSearchOrder.byPackage,
  }) {
    _whiteList.addAll(List.from(whiteList));
    _language = language;
    addNewEventToLanguageState(_language);
  }

  @Deprecated(
      'isCheckerActive is no longer used and will be removed in future releases. Use isActiveChecking instead')
  bool isCheckerActive() {
    return !_turnOffChecking;
  }

  /// **register the language** with the default ones supported
  /// by the package to let you use customLanguages properly since
  /// we always check if the current language is already registered
  /// on [_languagesRegistry]
  @Deprecated(
      'registerLanguage is no longer used and will be removed in future releases. Use setLanguage instead')
  void registerLanguage(String language) {}

  @override
  @Deprecated(
      'registerLanguage is no longer used and will be removed in future releases.')
  Future<void> reloadDictionary() async {}

  void reloadStreamStates() {
    verifyState();
    _languageState.add(null);
  }

  void setNewLanguageToState(T language) {
    verifyState();
    _language = language;
    addNewEventToLanguageState(_language);
  }

  @Deprecated(
      'setNewStrategy is no longer used and will be removed in future releases.')
  void setNewStrategy(StrategyLanguageSearchOrder strategy) {
    verifyState();
    this.strategy = strategy;
  }

  /// toggle the state of the checking
  ///
  /// if the current checking is deactivate when this be called then should activate
  /// if the current checking is activate when this be called then should deactivate
  void toggleChecker() {
    _turnOffChecking = !_turnOffChecking;
  }

  /// Verify if [Checker] is not disposed yet
  @mustCallSuper
  @protected
  @experimental
  void verifyState() {
    if (!_disposedControllers) {
      assert(
        !_disposed && !_languageState.isClosed,
        'You cannot reuse this SimpleSpellchecker since you dispose it before',
      );
      return;
    }
    assert(!_disposed,
        'You cannot reuse this SimpleSpellchecker since you dispose it before');
  }
}
