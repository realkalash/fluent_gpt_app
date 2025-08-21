<h1 align="center">📝 Simple Spell Checker</h1>

<p align="center">
<img src=https://github.com/CatHood0/resources/blob/Main/simple_spell_checker/clideo_editor_49b21800e993489fa4cdbbd160ffd60c%20(online-video-cutter.com).gif />
</p>

**Simple Spell Checker** is a simple but powerful spell checker, that allows to all developers detect and highlight spelling errors in text. The package also allows customization of languages, providing efficient and adaptable spell-checking for various applications.

## Current languages supported

The package already have a default list of words for these languages:

* [German](https://github.com/CatHood0/simple_spell_checker/tree/master/simple_spell_checker_de_lan) - `de`, `de-ch` 
* [English](https://github.com/CatHood0/simple_spell_checker/tree/master/simple_spell_checker_en_lan) - `en`, `en-gb`
* [Spanish](https://github.com/CatHood0/simple_spell_checker/tree/master/simple_spell_checker_es_lan) - `es`
* [Catalan](https://github.com/CatHood0/simple_spell_checker/tree/master/simple_spell_checker_ca_lan) - `ca`
* [Arabic](https://github.com/CatHood0/simple_spell_checker/tree/master/simple_spell_checker_ar_lan) - `ar`
* [Danish](https://github.com/CatHood0/simple_spell_checker/tree/master/simple_spell_checker_da_lan) - `da`
* [French](https://github.com/CatHood0/simple_spell_checker/tree/master/simple_spell_checker_fr_lan) - `fr`
* [Bulgarian](https://github.com/CatHood0/simple_spell_checker/tree/master/simple_spell_checker_bg_lan) - `bg`
* [Dutch](https://github.com/CatHood0/simple_spell_checker/tree/master/simple_spell_checker_nl_lan) - `nl`
* [Korean](https://github.com/CatHood0/simple_spell_checker/tree/master/simple_spell_checker_ko_lan) - `ko`
* [Estonian](https://github.com/CatHood0/simple_spell_checker/tree/master/simple_spell_checker_et_lan) - `et`
* [Hebrew](https://github.com/CatHood0/simple_spell_checker/tree/master/simple_spell_checker_he_lan) - `he`
* [Italian](https://github.com/CatHood0/simple_spell_checker/tree/master/simple_spell_checker_it_lan) - `it`
* [Norwegian](https://github.com/CatHood0/simple_spell_checker/tree/master/simple_spell_checker_no_lan) - `no`
* [Portuguese](https://github.com/CatHood0/simple_spell_checker/tree/master/simple_spell_checker_pt_lan) - `pt`
* [Russian](https://github.com/CatHood0/simple_spell_checker/tree/master/simple_spell_checker_ru_lan) - `ru`

## Getting Started

**Add the Dependency**:

```yaml
dependencies:
  simple_spell_checker: <latest_version>
```

> [!Note]
> You will need to add some of the available dependencies that contains the supported languages by default. Since the `1.3.0` of the package, all the dictionaries was removed and reimplemented into a separate package. Check [Current languages supported](#-current-languages-supported).
> 
> if you use some of these packages to register a language, please, call register functions before use the `SimpleSpellChecker` to avoid any unexpected behavior.

**Import the necessary components into your `Dart` file and initialize the Spell-Checker**:
 
### SimpleSpellChecker 

`SimpleSpellChecker` is a single language checker.

 ```dart
import 'package:simple_spell_checker/simple_spell_checker.dart';

SimpleSpellChecker spellChecker = SimpleSpellChecker(
   language: 'en', // the current language that the user is using
   whiteList: <String>[],  
   caseSensitive: false,
);
```


**You can set your own dictionary using `setLanguage`:**

 ```dart
import 'package:simple_spell_checker/simple_spell_checker.dart';

SimpleSpellChecker.setLanguage('sk', <String, int>{});
//we can use unlearnWord and learnWord to register/remove a word from a registered language 
// to learn a word
SimpleSpellChecker.learnWord('sk', 'word_that_will_be_registered');
// to unlearn a word
SimpleSpellChecker.unlearnWord('sk', 'word_that_will_be_removed');
```

**Registering the default supported languages:**

```dart
import 'package:simple_spell_checker_en_lan/simple_spell_checker_en_lan.dart';
import 'package:simple_spell_checker_he_lan/simple_spell_checker_he_lan.dart';
import 'package:simple_spell_checker_ru_lan/simple_spell_checker_ru_lan.dart';

// to register the language use
SimpleSpellCheckerHeRegister.registerLan();
SimpleSpellCheckerRuRegister.registerLan();
// for english you can use `en` or `en-ch` 
// by default is `en`
SimpleSpellCheckerEnRegister.registerLan(preferEnglish: 'en');
// to remove the language
SimpleSpellCheckerHeRegister.removeLan();
SimpleSpellCheckerRuRegister.removeLan();
SimpleSpellCheckerEnRegister.removeLan();
```

## Check functions

### Check your text:

Use the `check()` method to analyze a `String` for spelling errors that return a list of spans with misspelled words:

```dart
List<TextSpan>? result = spellChecker.check(
  'Your text here',
  wrongStyle: TextStyle(backgroundColor: Colors.red.withOpacity(0.2)), // set you custom style to the wrong spans 
  commonStyle: TextStyle(your_normal_styles_for_non_wrong_words), 
);
```

### Check your text using a custom builder:

Use the `checkBuilder<T>()` method to analyze a `String` for spelling errors and build your own widget with the text:

```dart
List<Widget>? result = spellChecker.checkBuilder<Widget>(
  'Your text here',
  builder: (word, isValid) {
    return Text(word, style: TextStyle(color: !isValid ? Colors.red : null));
  }
);
```

## Word tokenizer customization

### Creating your custom `Tokenizer`

Use the `wordTokenizer` param from constructor to set a custom instance of your `Tokenizer` or use `setNewTokenizer()` or `setWordTokenizerToDefault()`. _By default on `MultiSpellChecker` and `SimpleSpellChecker` only accept `Tokenizer` implementations with `List<String>` types only_.

#### Example of a custom `Tokenizer`:

```dart
/// custom tokenizer implemented by the package
class CustomWordTokenizer extends Tokenizer<List<String>> {
  CustomWordTokenizer() : super(separatorRegExp: RegExp(r'\S+|\s+'));

  @override
  bool canTokenizeText(String text) {
    return separatorRegExp!.hasMatch(text);
  }

  /// Divides a string into words
  @override
  List<String> tokenize(
    String content, {
    bool removeAllEmptyWords = false,
  }) {
    final List<String> words = separatorRegExp!.allMatches(content).map((match) => match.group(0)!).toList();
    return [...words];
  }
}
```

## Additional Information

### Language Management

* **setNewLanguageToState(String language)**: override the current language into the Spell Checker. _Only available for `SimpleSpellChecker` instances_

### White List Management

* **SetNewWhiteList(List words)**: override the current white list into the Spell Checker.
* **addNewWordToWhiteList(String words)**: add a new word to the white list.
* **whiteList**: return the current white list state.

### State Management 

* **toggleChecker()**: activate or deactivate the spell checking. If it is deactivate `check()` methods always will return null 
* **isActiveChecking()**: return the state of the spell checker.

### Customization Options

* **checkBuilder**: Use the `checkBuilder()` method for a custom widget-based approach to handling spelling errors.
* **customLongPressRecognizerOnWrongSpan**: Attach custom gesture recognizers to wrong words for tailored interactions.

### Stream Updates

The `SimpleSpellChecker` class provides a stream (stream getter) that broadcasts updates whenever the spell-checker state changes (by now, we just pass the current state of the object list that is always updated when add a new object). This is useful for reactive UI updates.

### For listen the changes of the language into SimpleSpellChecker:

```dart
spellChecker.languageStream.listen((event) {
  print("Spell check language state updated.");
});
```

### Disposing of Resources

When the `SimpleSpellChecker` is no longer needed, ensure you dispose of it properly:

```dart
//Avoid reuse this spellchecker after dispose since it will throws error
spellChecker.dispose();
```

Or also, if you don't need listen the StreamControllers then you can dispose them:

```dart
//Avoid reuse the streams of the spellchecker after dispose since it will throws error
spellChecker.disposeControllers();
```

It clears any cached data and closes the internal stream to prevent memory leaks.
