import 'dart:io';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:spell_check_on_client/spell_check_on_client.dart';

mixin ChatProviderSpellCheckMixin on ChangeNotifier {
  SpellCheck? spellCheck;

  Future<void> initSpellCheck() async {
    if (AppCache.useLocalSpellCheck.value != true) {
      spellCheck = null;
      return;
    }
    String language = 'en';
    final localeFiles = FileUtils.getFilesRecursive(FileUtils.currentAppDirectorypath);
    for (final file in localeFiles) {
      final name = file.path.split(Platform.pathSeparator).last;
      if (name.contains('${language}_words.txt')) {
        String content = await file.readAsString();
        spellCheck = SpellCheck.fromWordsContent(content, letters: LanguageLetters.getLanguageForLanguage(language));
        break;
      }
    }
  }

  Future<void> addWordToDictionary(String word, String locale) async {
    final localeFiles = FileUtils.getFilesRecursive(FileUtils.currentAppDirectorypath);
    for (final file in localeFiles) {
      final name = file.path.split(Platform.pathSeparator).last;
      if (name.contains('${locale}_words.txt')) {
        String content = await file.readAsString();
        content = '$content\n${word.toLowerCase()}';
        await file.writeAsString(content);
        spellCheck = SpellCheck.fromWordsContent(content, letters: LanguageLetters.getLanguageForLanguage(locale));
        spellCheck?.words;
        notifyListeners();
        break;
      }
    }
  }
}

