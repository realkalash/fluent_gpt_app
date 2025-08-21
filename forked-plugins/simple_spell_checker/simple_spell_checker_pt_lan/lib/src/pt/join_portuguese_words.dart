// ignore: implementation_imports
import 'package:simple_spell_checker/src/utils.dart';

import 'pt_words1.dart';
import 'pt_words2.dart';

/// we use join functions instead getting dictionaries directly
/// since the dictionaries are too bigger to be used in just one file
final String joinPortugueseWords =
    [removeUnnecessaryCharacters(ptWords2), ptWords1].join('\n');
