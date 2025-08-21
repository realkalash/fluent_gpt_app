import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:spell_check_on_client/spell_check_on_client.dart';

class CustomSpellCheckService extends SpellCheckService {
  final SpellCheck spellCheck;
  
  CustomSpellCheckService({required this.spellCheck});

  @override
  Future<List<SuggestionSpan>?> fetchSpellCheckSuggestions(Locale locale, String text) async {
    if (text.isEmpty) {
      return null;
    }

    final List<SuggestionSpan> suggestionSpans = <SuggestionSpan>[];
    final List<String> words = WordTokenizer.tokenize(text);
    
    if (words.isEmpty) {
      return null;
    }

    int currentIndex = 0;
    
    for (final String word in words) {
      // Find the word's position in the original text
      final int wordStartIndex = text.indexOf(word, currentIndex);
      
      if (wordStartIndex == -1) {
        // Word not found, skip
        continue;
      }
      
      // Check if the word is spelled correctly
      final bool isCorrect = spellCheck.isCorrect(word.toLowerCase());
      
      if (!isCorrect) {
        // Get suggestions for the misspelled word
        final List<String> suggestions = spellCheck.didYouMeanAny(word, maxWords: 5);
        
        if (suggestions.isNotEmpty) {
          suggestionSpans.add(
            SuggestionSpan(
              TextRange(
                start: wordStartIndex,
                end: wordStartIndex + word.length,
              ),
              suggestions,
            ),
          );
        }
      }
      
      currentIndex = wordStartIndex + word.length;
    }
    
    return suggestionSpans.isEmpty ? null : suggestionSpans;
  }
}