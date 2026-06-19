import 'dart:convert';

import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:langchain/langchain.dart';
import 'package:langchain_openai/langchain_openai.dart';

/// Translates OCR'd text blocks with the currently selected LLM ([openAI]).
///
/// All blocks go out in a **single** indexed request (not one call per block):
/// it's faster, cheaper, and the model sees every line at once so a sentence
/// split across boxes is translated coherently. The reply is index-tagged JSON
/// so the alignment survives the model merging, reordering, or dropping a line —
/// any index we don't get back keeps its original text.
class TranslationService {
  TranslationService._();
  static final TranslationService instance = TranslationService._();

  /// Translates [texts] into [targetLanguage], returning a list aligned 1:1 with
  /// the input. On any failure (no model, network, bad JSON) the affected slots
  /// fall back to the original string — this never throws to the UI.
  Future<List<String>> translate(
    List<String> texts, {
    required String targetLanguage,
  }) async {
    if (texts.isEmpty) return const [];
    final model = openAI;
    if (model == null) {
      log('[Translate] no model available');
      return List<String>.from(texts);
    }

    final numbered = <String>[];
    for (var i = 0; i < texts.length; i++) {
      numbered.add('[$i] ${texts[i].replaceAll('\n', ' ').trim()}');
    }
    final prompt = '''
Translate each numbered line below into $targetLanguage.
Rules:
- Return ONLY a JSON array, nothing else: [{"i":0,"t":"translation"}, ...]
- Keep the same "i" index for each line; include every line exactly once.
- "t" is the translation only. If a line is already in $targetLanguage or is not translatable (numbers, symbols), return it unchanged.
- Do not add notes, explanations, or markdown fences.

Lines:
${numbered.join('\n')}''';

    try {
      final options = ChatOpenAIOptions(model: selectedModel.modelName);
      final response = await model.call([ChatMessage.humanText(prompt)], options: options);
      return _applyResponse(texts, response.content);
    } catch (e) {
      log('[Translate] failed: $e');
      return List<String>.from(texts);
    }
  }

  /// Parses the index-tagged JSON reply and merges it onto a copy of [original],
  /// so unmatched indices keep their source text.
  List<String> _applyResponse(List<String> original, String raw) {
    final out = List<String>.from(original);
    final jsonStr = _extractJsonArray(raw);
    if (jsonStr == null) {
      log('[Translate] no JSON array in response');
      return out;
    }
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is! List) return out;
      for (final item in decoded) {
        if (item is! Map) continue;
        final i = item['i'];
        final t = item['t'];
        if (i is int && t is String && i >= 0 && i < out.length) {
          out[i] = t;
        }
      }
    } catch (e) {
      log('[Translate] JSON parse failed: $e');
    }
    return out;
  }

  /// Pulls the first top-level `[...]` out of [raw], tolerating ```json fences
  /// or stray prose the model may wrap around it.
  String? _extractJsonArray(String raw) {
    final start = raw.indexOf('[');
    final end = raw.lastIndexOf(']');
    if (start == -1 || end == -1 || end <= start) return null;
    return raw.substring(start, end + 1);
  }
}
