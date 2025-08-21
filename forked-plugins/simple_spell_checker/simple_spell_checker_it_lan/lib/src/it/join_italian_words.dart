// ignore: implementation_imports
import 'package:simple_spell_checker/src/utils.dart';
import 'it_words1.dart';
import 'it_words2.dart';

/// we use join functions instead getting dictionaries directly
/// since the dictionaries are too bigger to be used in just one file
final String joinItalianWords =
    '${removeUnnecessaryCharacters(itWords2)}\n$itWords1';
