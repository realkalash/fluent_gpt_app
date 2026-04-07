import 'package:collection/collection.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// True when the app should use Apple's Speech framework (macOS) instead of a cloud STT API.
bool useAppleSpeechRecognition() =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

final SpeechToText _sharedAppleSpeech = SpeechToText();

Future<String?> _pickLocaleId() async {
  final code = AppCache.speechLanguage.value ?? 'en';
  final list = await _sharedAppleSpeech.locales();
  if (list.isEmpty) return null;
  final lower = code.toLowerCase();
  final exact = list.firstWhereOrNull(
    (l) =>
        l.localeId.toLowerCase() == lower ||
        l.localeId.toLowerCase().startsWith('$lower-') ||
        l.localeId.toLowerCase().startsWith('${lower}_'),
  );
  if (exact != null) return exact.localeId;
  final prefix = list.firstWhereOrNull(
    (l) => l.localeId.toLowerCase().startsWith(lower),
  );
  return prefix?.localeId ?? list.first.localeId;
}

Future<bool> _initializeAppleSpeech({
  SpeechErrorListener? onError,
  SpeechStatusListener? onStatus,
}) async {
  if (!useAppleSpeechRecognition()) return false;
  return _sharedAppleSpeech.initialize(onError: onError, onStatus: onStatus);
}

/// Starts dictation into [onText]: [initialText] is preserved and recognition is appended (partials + finals).
Future<bool> startAppleSpeechDictation({
  required String initialText,
  required void Function(String text) onText,
  SpeechErrorListener? onError,
  SpeechStatusListener? onStatus,
}) async {
  if (!useAppleSpeechRecognition()) return false;

  final ready = await _initializeAppleSpeech(onError: onError, onStatus: onStatus);
  if (!ready) return false;

  final localeId = await _pickLocaleId();
  var committed = initialText;

  try {
    await _sharedAppleSpeech.listen(
      onResult: (result) {
        if (result.finalResult && result.recognizedWords.isNotEmpty) {
          committed += '${result.recognizedWords} ';
          onText(committed);
        } else {
          onText(committed + result.recognizedWords);
        }
      },
      localeId: localeId,
      listenOptions: SpeechListenOptions(
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
      ),
    );
    if (!_sharedAppleSpeech.isListening) {
      return false;
    }
  } on ListenFailedException {
    return false;
  }
  return true;
}

Future<void> stopAppleSpeechDictation() async {
  if (!useAppleSpeechRecognition()) return;
  if (_sharedAppleSpeech.isListening) {
    await _sharedAppleSpeech.stop();
  }
}
