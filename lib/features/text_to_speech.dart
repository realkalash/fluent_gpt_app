import 'package:fluent_gpt/common/enums.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/features/azure_speech.dart';
import 'package:fluent_gpt/features/deepgram_speech.dart';
import 'package:fluent_gpt/features/elevenlabs_speech.dart';

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
    if (AppCache.textToSpeechService.value ==
        TextToSpeechServiceEnum.azure.name) {
      AzureSpeech.init();
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
    if (AppCache.textToSpeechService.value ==
        TextToSpeechServiceEnum.azure.name) {
      return AzureSpeech.isValid();
    }
    return false;
  }

  static Future readAloud(
    String text, {
    Function()? onCompleteReadingAloud,
  }) async {
    if (isReadingAloud){
      await stopReadingAloud();
      await Future.delayed(Duration(milliseconds: 100));
    }
    if (AppCache.textToSpeechService.value ==
        TextToSpeechServiceEnum.deepgram.name) {
      await DeepgramSpeech.readAloud(text, onCompleteReadingAloud: () {
        onCompleteReadingAloud?.call();
      });
    } else if (AppCache.textToSpeechService.value ==
        TextToSpeechServiceEnum.elevenlabs.name) {
      await ElevenlabsSpeech.readAloud(text, onCompleteReadingAloud: () {
        onCompleteReadingAloud?.call();
      });
    } else if (AppCache.textToSpeechService.value ==
        TextToSpeechServiceEnum.azure.name) {
      await AzureSpeech.readAloud(text, onCompleteReadingAloud: () {
        onCompleteReadingAloud?.call();
      });
    }
  }

  static Future stopReadingAloud() async {
    if (AppCache.textToSpeechService.value ==
        TextToSpeechServiceEnum.deepgram.name) {
      await DeepgramSpeech.stopReadingAloud();
    } else if (AppCache.textToSpeechService.value ==
        TextToSpeechServiceEnum.elevenlabs.name) {
      await ElevenlabsSpeech.stopReadingAloud();
    } else if (AppCache.textToSpeechService.value ==
        TextToSpeechServiceEnum.azure.name) {
      await AzureSpeech.stopReadingAloud();
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
    if (AppCache.textToSpeechService.value ==
        TextToSpeechServiceEnum.azure.name) {
      return AzureSpeech.isReadingAloud;
    }
    return false;
  }
}
