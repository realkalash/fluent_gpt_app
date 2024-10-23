import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:deepgram_speech_to_text/deepgram_speech_to_text.dart';
import 'package:elevenlabs_flutter/elevenlabs_config.dart';
import 'package:elevenlabs_flutter/elevenlabs_types.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:elevenlabs_flutter/elevenlabs_flutter.dart';
import 'package:fluent_ui/fluent_ui.dart';

class ElevenlabsSpeech {
  static ElevenLabsAPI? _elevenLabs;
  static ElevenLabsAPI get elevenLabs {
    if (_elevenLabs == null) {
      init();
    }
    return _elevenLabs!;
  }

  static String? selectedVoiceName;
  static String? selectedVoiceId;
  static String? selectedModel;
  static AudioPlayer? player;

  static Future<void> init() async {
    final elevenLabsApiKey = AppCache.elevenLabsApiKey.value!;
    if (elevenLabsApiKey.isEmpty) {
      return;
    }
    await elevenLabs.init(
      config: ElevenLabsConfig(
        baseUrl: 'https://api.elevenlabs.io',
        apiKey: elevenLabsApiKey,
      ),
    );
  }

  static bool isValid() {
    if (selectedVoiceId == null) {
      return false;
    }
    return AppCache.elevenLabsApiKey.value!.isNotEmpty;
  }

  static Future showConfigureDialog(BuildContext context) async {
    showDialog(context: context, builder: (ctx) => ElevenLabsConfigDialog());
  }

  static Future readAloud(
    String text, {
    Function()? onCompleteReadingAloud,
  }) async {
    if (!isValid()) {
      return;
    }
    final result = await _elevenLabs!.synthesize(
      TextToSpeechRequest(
        voiceId: selectedVoiceId!,
        text: text,
        modelId: selectedModel ?? 'eleven_monolingual_v1',
        voiceSettings: VoiceSettings(
          similarityBoost: 75,
          stability: 50,
        ),
      ),
    );
    final audio = await result.readAsBytes();
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

class ElevenLabsConfigDialog extends StatefulWidget {
  const ElevenLabsConfigDialog({super.key});

  @override
  State<ElevenLabsConfigDialog> createState() => _ElevenLabsConfigDialogState();
}

class _ElevenLabsConfigDialogState extends State<ElevenLabsConfigDialog> {
  bool isLoadingVoices = false;
  List<Voice> voices = [];
  @override
  Future<void> initState() async {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      loadVoices();
    });
  }

  loadVoices() async {
    setState(() {
      isLoadingVoices = true;
    });
    voices = await ElevenlabsSpeech.elevenLabs.listVoices();
    setState(() {
      isLoadingVoices = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: Text('ElevenLabs Configuration'),
      actions: [
        Button(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Ok'),
        ),
      ],
      content: ListView(
        shrinkWrap: true,
        children: [
          Text('ElevenLabs API Key*'),
          TextFormBox(
            onChanged: (value) {
              AppCache.elevenLabsApiKey.value = value;
            },
            initialValue: AppCache.elevenLabsApiKey.value,
            validator: (value) {
              if ((value ?? '').isEmpty) {
                return 'Please enter a valid API key';
              }
              return null;
            },
          ),
          Text('Voice ID*'),
          DropDownButton(
            title: Text(ElevenlabsSpeech.selectedVoiceName ?? 'Select a voice'),
            items: [
              for (final voice in voices)
                MenuFlyoutItem(
                  text: Text(voice.name),
                  onPressed: () {
                    ElevenlabsSpeech.selectedVoiceId = voice.voiceId;
                    ElevenlabsSpeech.selectedVoiceName = voice.name;
                    setState(() {});
                  },
                ),
            ],
          )
        ],
      ),
    );
  }
}
