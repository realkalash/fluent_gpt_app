// ignore: implementation_imports
import 'package:simple_spell_checker/src/utils.dart';
import '../join_english_words.dart';
import 'en_gb_words1.dart';

final joinBritishWords =
    '${removeUnnecessaryCharacters(britishWords1)}\n$joinEnglishWords';
