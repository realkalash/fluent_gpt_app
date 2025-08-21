import 'package:meta/meta.dart';

/// This tells to the [SimpleSpellchecker] which should be the priority
/// when we need to search the dictionary for the current language
@experimental
@Deprecated(
    'StrategyLanguageSearchOrder is no longer used and will be removed in future releases.')
enum StrategyLanguageSearchOrder {
  // Will search first if the language implementation is into the
  // custom languages
  byUser,
  // Will search first if the language implementation is into the
  // default languages implemented by the package
  byPackage,
}
