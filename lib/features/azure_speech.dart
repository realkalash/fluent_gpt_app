import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/log.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class AzureSpeech {
  static AzureSpeech? _azureSpeech;
  static AzureSpeech get azureSpeech {
    if (_azureSpeech == null) {
      init();
    }
    return _azureSpeech!;
  }

  static void init() {
    _azureSpeech = AzureSpeech();
  }

  static const listModels = [
    'en-US-AvaMultilingualNeural',
    'en-US-NancyMultilingualNeural',
    'en-US-NancyNeural',
    'en-US-BrianMultilingualNeural',
    'en-US-AriaNeural',
    'en-US-AndrewMultilingualNeural',
  ];

  static bool isValid() {
    return AppCache.azureSpeechApiKey.value!.isNotEmpty &&
        AppCache.azureSpeechRegion.value!.isNotEmpty &&
        AppCache.azureVoiceModel.value!.isNotEmpty;
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
        ('${AppCache.azureVoiceModel.value}$text').hashCode.toString();
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

    final region = AppCache.azureSpeechRegion.value!;
    final key = AppCache.azureSpeechApiKey.value!;
    final model = AppCache.azureVoiceModel.value!;
    final url = 'https://$region.tts.speech.microsoft.com/cognitiveservices/v1';
    final lang = AppCache.speechLanguage.value ?? 'en-US';
    final int speedIntIncreasePerc = AppCache.speedIntIncreasePerc.value ?? 0;
    final String speed = speedIntIncreasePerc == 0
        ? '0.00'
        : (speedIntIncreasePerc / 100).toStringAsFixed(2);

    /// https://learn.microsoft.com/en-us/azure/ai-services/speech-service/speech-synthesis-markup-voice
    final dataRawWithRateAndPitch = '''
<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xmlns:mstts="https://www.w3.org/2001/mstts" xml:lang="$lang">
    <voice name="$model">
      <mstts:express-as style="friendly" styledegree="1">
        <prosody rate="$speed%" pitch="+25%">
            $text
        </prosody>
      </mstts:express-as>
    </voice>
</speak>
''';
    if (kDebugMode) {
      print('request: $dataRawWithRateAndPitch');
    }

    final result = await http.post(
      Uri.parse(url),
      headers: {
        'Ocp-Apim-Subscription-Key': key,
        'Content-Type': 'application/ssml+xml',
        'X-Microsoft-OutputFormat': 'audio-16khz-128kbitrate-mono-mp3',
        'User-Agent': 'curl',
      },
      body: dataRawWithRateAndPitch,
    );
    if (result.statusCode != 200)
      throw Exception(
          'Failed to read aloud: ${result.statusCode} ${result.body} ${result.reasonPhrase}');
    final audio = result.bodyBytes;
    if (FileUtils.temporaryAudioDirectoryPath != null)
      FileUtils.saveFileBytes(audioPath, audio);
    player = AudioPlayer();
    await player!.setSourceBytes(audio, mimeType: 'audio/mpeg');
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
