import 'package:simple_spell_checker_es_lan/src/es/es_words3.dart';
// ignore: implementation_imports
import 'package:simple_spell_checker/src/utils.dart';
import 'es_words1.dart';
import 'es_words2.dart';

/// we use join functions instead getting dictionaries directly
/// since the dictionaries are too bigger to be used in just one file
final String joinSpanishWords =
    '$esWords1\n${removeUnnecessaryCharacters(esWords2)}\n$esWords3';
