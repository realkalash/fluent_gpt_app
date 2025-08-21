// matches with any visible or invisible whitespaces format
const String _whitespaces = r'''\p{Z}''';
// Accept all characters from any languages
const String _allWords =
    r'''\p{L}\p{M}\p{Lm}\p{Lo}\p{Script=Arabic}\p{Script=Armenian}\p{Script=Bengali}\p{Script=Bopomofo}\p{Script=Braille}\p{Script=Buhid}\p{Script=Canadian_Aboriginal}\p{Script=Cherokee}\p{Script=Cyrillic}\p{Script=Devanagari}\p{Script=Ethiopic}\p{Script=Georgian}\p{Script=Greek}\p{Script=Gujarati}\p{Script=Gurmukhi}\p{Script=Han}\p{Script=Hangul}\p{Script=Hanunoo}\p{Script=Hebrew}\p{Script=Hiragana}\p{Script=Inherited}\p{Script=Kannada}\p{Script=Katakana}\p{Script=Khmer}\p{Script=Lao}\p{Script=Latin}\p{Script=Limbu}\p{Script=Malayalam}\p{Script=Mongolian}\p{Script=Myanmar}\p{Script=Ogham}\p{Script=Oriya}\p{Script=Runic}\p{Script=Sinhala}\p{Script=Syriac}\p{Script=Tagalog}\p{Script=Tagbanwa}\p{Script=Tamil}\p{Script=Telugu}\p{Script=Thaana}\p{Script=Thai}\p{Script=Tibetan}\p{Script=Yi}''';
// Accept non letter characters like dots, or emojis
const String _nonWordsCharacters =
    r'''\p{P}\p{N}\p{Pd}\p{Nd}\p{Nl}\p{Pi}\p{No}\p{Pf}\p{Pc}\p{Ps}\p{Cf}\p{Co}\p{Cn}\p{Cs}\p{Pe}\p{S}\p{Sm}\p{Sc}\p{Sk}\p{So}\p{Cc}\p{Po}\p{Mc}''';
//TODO: fix "'" character is taked as a nonWordsCharacters and this could be used by other languages as a part of the word

// All of these unicodes expresions can be verified
// on [unicode categories](https://www.regular-expressions.info/unicode.html#category)

/// A interface with the necessary methods to tokenize words
abstract class Tokenizer<T extends Object> {
  final RegExp defaultSeparatorRegExp = RegExp(
      '''([$_whitespaces]+|[$_allWords]+|[$_nonWordsCharacters])''',
      unicode: true);
  final RegExp? separatorRegExp;
  Tokenizer({this.separatorRegExp});
  bool canTokenizeText(String text);
  T tokenize(String content);
}
