## 1.3.1

* Chore!: renamed register functions from internal language packages by @CatHood0 in https://github.com/CatHood0/simple_spell_checker/pull/18
* Fix(changelog): typo where there is a title instead the version where the change was maded by @CatHood0 in https://github.com/CatHood0/simple_spell_checker/pull/17

**Full Changelog**: https://github.com/CatHood0/simple_spell_checker/compare/V1.3.0...V1.3.1

## 1.3.0

* Chore!: first step to improve package by @CatHood0 in https://github.com/CatHood0/simple_spell_checker/pull/16

**Full Changelog**: https://github.com/CatHood0/simple_spell_checker/compare/V1.2.3...V1.3.0

## 1.2.3

* Chore: removed deprecated member from Tokenizer.
* Feat: support for generic return in Tokenizer class by @CatHood0 in https://github.com/CatHood0/simple_spell_checker/pull/7
* Feat: make public Checker API by @CatHood0 in https://github.com/CatHood0/simple_spell_checker/pull/8

**Full Changelog**: https://github.com/CatHood0/simple_spell_checker/compare/V1.2.2...V1.2.3

## 1.2.2

* Fix: some parameters in `MultiSpellChecker` are not used by @CatHood0 in https://github.com/CatHood0/simple_spell_checker/pull/4
* Feat: white list for the checker by @CatHood0 in https://github.com/CatHood0/simple_spell_checker/pull/5

**Full Changelog**: https://github.com/CatHood0/simple_spell_checker/compare/V1.2.1...V1.2.2

## 1.2.1

* Fix: dispose methods show that need to be overrided

## 1.2.0

* Feat: More translations for spell checker by @CatHood0 in https://github.com/CatHood0/simple_spell_checker/pull/2
* Feat: Multi language checker by @CatHood0 in https://github.com/CatHood0/simple_spell_checker/pull/3

**Full Changelog**: https://github.com/CatHood0/simple_spell_checker/compare/V1.1.7...V1.2.0

## 1.1.7

* Feat: improved default separator regexp for accept all languages character and non characters (it includes emojis) by @CatHood0 in https://github.com/CatHood0/simple_spell_checker/pull/1

### New Contributors
* @CatHood0 made their first contribution in https://github.com/CatHood0/simple_spell_checker/pull/1

**Full Changelog**: https://github.com/CatHood0/simple_spell_checker/compare/V1.1.6...V1.1.8

## 1.1.6

* Fix: `isCheckerActive()` return a confuse value

## 1.1.5

* Chore: update documentation 

## 1.1.4

* Feat: support for create common and wrong styles in `check` functions 
* Feat: added example app
* Fix: some characters are losted while typing by wrong regexp match
* Fix: uppercase words with just one char length not is parsed to lowercase
* Chore: change `hasWrongWord` to `isWordValid` to make more sense

## 1.1.3

* Chore: deprecated `removeEmptyWordsOnTokenize` and `removeAllEmptyWords` since are useless
* Chore: deprecated `LanguageDicPriorityOrder` and it was replaced by `StrategyLanguageSearchOrder` 
* Fix: `italian` contains not used english words
* Feat: added more words for `Deutsch` and `Spanish` dictionaries

## 1.1.2

* Fix: bad state after close controllers

## 1.1.1

* Fix: dot (".") characters is lost while typing
* Fix: added missing translations

## 1.1.0

* Fix: avoid spellchecker default behavior when the current language it's no supported (some of the not supported ones can be: chinese, japanese, russian, etc) for now. 
* Feat: added more characteres to add better support for the default implementation 
* Feat: support for custom word tokenizer
* Feat: support for realtime subscription to changes using directly `checkStream` or `checkBuilderStream` instead controllers

## 1.0.9 

* Fix: restore a removed character that is needed to avoid missing character while typing

## 1.0.8

* Fix(de): Deutsch language cause some characters are ignore like: `ẅ`, `ä`, `ë`, `ï`, `ö`, `ÿ`, etc

## 1.0.7

* Fix: words with accents are detected as a special character instead a common word
* Fix: bad updating of cache instances when initalize different instances
* Chore: added some missing translations for english and spanish

## 1.0.6

* Fix: accents are ignored
* Chore: more missing words and sentences for spanish translation

## 1.0.5

* Fix: several language characters are ignored
* Chore: added some missing words for spanish translation

## 1.0.4

* Fix: line is ignored directly if contains a special character (like: "(", "[", etc)
* Feat: improved separator regexp to divide also special chars from the words
* Feat: more translations for `pt`, `de`, `en`, `es`, `it` and `fr` languages
* Feat: ability to close controller if we don't need them
* Feat: ability to override any current language if exist in `customLanguages`
* Feat: added priority order when the directionary is realoding using `LanguageDicPriorityOrder` enum 
* Feat: now we can set a default safeLanguageName to the `SimpleSpellChecker` instead pref `en` translation always

## 1.0.3

* Fix: unable to load assets

## 1.0.2

* Fix: whitespaces are removed or ignored

## 1.0.1

* Fix: typo on `SimpleSpellChecker` class and README 
* Doc: more docs about `LanguageIdentifier` 

## 1.0.0

Initial commit
