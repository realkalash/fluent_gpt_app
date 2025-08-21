import 'dart:convert';
import 'package:simple_spell_checker/simple_spell_checker.dart'
    show SimpleSpellChecker;
import 'package:simple_spell_checker_pt_lan/src/pt/join_portuguese_words.dart';

class SimpleSpellCheckerPtRegister {
  static const _splitter = LineSplitter();

  /// this can be used to register manually the portuguese
  /// language to be supported by the `SimpleSpellChecker`
  static void registerLan() {
    if (SimpleSpellChecker.containsLanguage('pt')) return;
    SimpleSpellChecker.setLanguage(
        'pt', _createDictionary(joinPortugueseWords));
  }

  static Map<String, int> _createDictionary(String words) {
    if (words.trim().isEmpty) {
      return {};
    }
    final Iterable<MapEntry<String, int>> entries =
        _splitter.convert(words).map(
              (element) => MapEntry(
                element.trim().toLowerCase(),
                1,
              ),
            );
    return {}..addEntries(entries);
  }

  static void removeLan() {
    SimpleSpellChecker.removeLanguage('pt');
  }
}
