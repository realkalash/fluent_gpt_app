import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:deepgram_speech_to_text/deepgram_speech_to_text.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/log.dart';

class DeepgramSpeech {
  static Deepgram? _deepgram;
  static Deepgram get deepgram {
    if (_deepgram == null) {
      init();
    }
    return _deepgram!;
  }

  static void init() {
    final deepgramKey = AppCache.deepgramApiKey.value!;
    if (deepgramKey.isEmpty) {
      return;
    }
    _deepgram = Deepgram(deepgramKey, baseQueryParams: {
      'model': 'nova-2-general',
      'language': 'en-US',
      'detect_language': false,
      'filler_words': false,
      'punctuation': true,
      'punctuate': true,
      // more options here : https://developers.deepgram.com/reference/listen-file
    });
  }

  static const listModels = [
    'aura-asteria-en',
    'aura-hera-en',
    'aura-luna-en',
    'aura-stella-en',
    'aura-athena-en',
    'aura-zeus-en',
    'aura-orion-en',
    'aura-arcas-en',
    'aura-perseus-en',
    'aura-angus-en',
    'aura-orpheus-en',
    'aura-helios-en'
  ];

  static bool isValid() {
    return AppCache.deepgramApiKey.value!.isNotEmpty;
  }

  static AudioPlayer? player;
  static Future readAloud(
    String text, {
    Function()? onCompleteReadingAloud,
  }) async {
    if (!isValid()) {
      return;
    }
    final fileName =
        (AppCache.deepgramVoiceModel.value ?? '') + text.hashCode.toString();
    final audioPath = (FileUtils.temporaryAudioDirectoryPath ?? '') + fileName;
    final file = File(audioPath);
    try {
      if (file.existsSync()) {
        player = AudioPlayer();
        final fileBytes = await file.readAsBytes();
        await player!.setSourceBytes(fileBytes, mimeType: 'audio/mpeg');
        player!.onPlayerComplete.listen((onData) {
          player!.dispose();
          player = null;
          onCompleteReadingAloud?.call();
        });
        await player!.resume();
        return;
      }
    } catch (e) {
      logError(e.toString());
    }
    final result = await deepgram.speakFromText(text, queryParams: {
      'model': AppCache.deepgramVoiceModel.value!,
    });
    final audio = result.data;
    player = AudioPlayer();
    await player!.setSourceBytes(audio, mimeType: result.contentType);
    player!.onPlayerComplete.listen((onData) {
      player!.dispose();
      player = null;
      onCompleteReadingAloud?.call();
    });
    await player!.resume();
  }

  static Future stopReadingAloud() async {
    await player!.stop();
    player!.dispose();
    player = null;
  }

  static bool get isReadingAloud => player != null;
}

class DeepgramSttResult {
  /// raw json response
  final String json;

  /// parsed json response into a map
  final Map<String, dynamic> map;

  /// the transcript extracted from the response
  final String? transcript;

  /// the response type (Result, Metadata, ...) non-null for streaming
  final String? type;

  const DeepgramSttResult({
    required this.json,
    required this.map,
    required this.transcript,
    required this.type,
  });
}
