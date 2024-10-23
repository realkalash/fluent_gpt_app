import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/features/deepgram_speech.dart';
import 'package:fluent_gpt/features/elevenlabs_speech.dart';
import 'package:fluent_gpt/pages/settings_page.dart';

class TextToSpeechService {
  static get serviceName => AppCache.textToSpeechService.value;

  static Future init() async {
    if (AppCache.textToSpeechService.value ==
        TextToSpeechServiceEnum.deepgram.name) {
      DeepgramSpeech.init();
    }
    if (AppCache.textToSpeechService.value ==
        TextToSpeechServiceEnum.elevenlabs.name) {
      await ElevenlabsSpeech.init();
    }
  }

  static bool isValid() {
    if (AppCache.textToSpeechService.value ==
        TextToSpeechServiceEnum.deepgram.name) {
      return DeepgramSpeech.isValid();
    }
    if (AppCache.textToSpeechService.value ==
        TextToSpeechServiceEnum.elevenlabs.name) {
      return ElevenlabsSpeech.isValid();
    }
    return false;
  }

  static Future readAloud(
    String text, {
    Function()? onCompleteReadingAloud,
  }) async {
    if (AppCache.textToSpeechService.value ==
        TextToSpeechServiceEnum.deepgram.name) {
      await DeepgramSpeech.readAloud(text, onCompleteReadingAloud: () {
        onCompleteReadingAloud?.call();
      });
    }
    if (AppCache.textToSpeechService.value ==
        TextToSpeechServiceEnum.elevenlabs.name) {
      await ElevenlabsSpeech.readAloud(text, onCompleteReadingAloud: () {
        onCompleteReadingAloud?.call();
      });
    }
  }

  static Future stopReadingAloud() async {
    if (AppCache.textToSpeechService.value ==
        TextToSpeechServiceEnum.deepgram.name) {
      await DeepgramSpeech.stopReadingAloud();
    }
    if (AppCache.textToSpeechService.value ==
        TextToSpeechServiceEnum.elevenlabs.name) {
      await ElevenlabsSpeech.stopReadingAloud();
    }
  }

  static bool get isReadingAloud {
    if (AppCache.textToSpeechService.value ==
        TextToSpeechServiceEnum.deepgram.name) {
      return DeepgramSpeech.isReadingAloud;
    }
    if (AppCache.textToSpeechService.value ==
        TextToSpeechServiceEnum.elevenlabs.name) {
      return ElevenlabsSpeech.isReadingAloud;
    }
    return false;
  }
}
