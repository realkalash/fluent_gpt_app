import 'package:meta/meta.dart';

/// This list contains all languages that are supported by 
/// default in [simple_spell_checker]
///
/// If you want to import one of them, check [Current supported languages](https://github.com/CatHood0/simple_spell_checker?tab=readme-ov-file#current-languages-supported)
final List<String> defaultLanguages = List.unmodifiable(
  [
    'pt',
    'de',
    'de-ch',
    'en',
    'en-gb',
    'es',
    'it',
    'ko',
    'fr',
    'no',
    'nl',
    'ru',
    'he',
    'et',
    'ar',
    'bg',
    'ca',
    'da',
  ],
);

@Deprecated(
    'defaultLanguagesDictionaries is no longer used and will be removed in future releases')
final Map<String, String> defaultLanguagesDictionaries = Map.unmodifiable({});

/// This variable is used by the checker to add using [setLanguage]
/// where the key is the language code, and the value is the dictionary
@experimental
@internal
final Map<String, Map<String, int>> dictionaries = {};

@experimental
@internal
bool isWordHasNumber(String s) {
  return s.contains(RegExp(r'[0-9]'));
}

final RegExp _removeDicCharacter = RegExp(r'\/(\S+)?');

/// This is only for internal use and should not be used outside
/// because this is used to remove unnecessary characters into the
/// dictionary string. By now is used, but in future releases
/// will be removed since we need to change the implementation
/// of the dictionaries
@experimental
String removeUnnecessaryCharacters(String original, [Object? replace]) {
  return original
      .replaceAll('-', '${replace ?? '\n'}')
      .replaceAll(_removeDicCharacter, '');
}
