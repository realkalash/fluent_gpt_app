import 'dart:io';

import 'package:elevenlabs_flutter/elevenlabs_types.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:elevenlabs_flutter/elevenlabs_flutter.dart';

import 'package:elevenlabs_flutter/elevenlabs_config.dart';

final elevenLabs = ElevenLabsAPI();

void main() {
  const ElevenLabsConfig config = ElevenLabsConfig(
    apiKey: "your_api_key",
  );
  String tom_id = "tom_beal";
  test('Check ElevenLabs listVoices endpoint', () async {
    elevenLabs.init(config: config);
    final voices = await elevenLabs.listVoices();
    for (var voice in voices) {
      print("Voice: ${voice.name}");
      if (voice.name.contains("Tom")) {
        tom_id = voice.voiceId;
      }
      expect(voice, isInstanceOf<Voice>());
    }
    expect(voices, isInstanceOf<List<Voice>>());
  });

  test('Check ElevenLabs synthesize endpoint', () async {
    final request = TextToSpeechRequest(text: "Hello", voiceId: tom_id);
    final synthesized = await elevenLabs.synthesize(request);
    expect(synthesized, isInstanceOf<File>());
  });

  test('Check ElevenLabs userInfo endpoint', () async {
    final userInfo = await elevenLabs.getCurrentUser();
    expect(userInfo, isInstanceOf<ElevenUser>());
  });
}
