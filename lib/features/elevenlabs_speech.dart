import 'dart:async';
import 'dart:convert';

import 'package:audioplayers/audioplayers.dart';
import 'package:elevenlabs_flutter/elevenlabs_config.dart';
import 'package:elevenlabs_flutter/elevenlabs_types.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:elevenlabs_flutter/elevenlabs_flutter.dart';
import 'package:fluent_gpt/widgets/wiget_constants.dart';
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
    _elevenLabs = ElevenLabsAPI();
    await _elevenLabs?.init(
      config: ElevenLabsConfig(
        baseUrl: 'https://api.elevenlabs.io',
        apiKey: elevenLabsApiKey,
      ),
    );
    ElevenlabsSpeech.selectedVoiceId = AppCache.elevenlabsVoiceModel.value;
    ElevenlabsSpeech.selectedModel = AppCache.elevenlabsVoiceModelId.value;
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
    final result = await _elevenLabs!.synthesizeBytes(
      TextToSpeechRequest(
        voiceId: selectedVoiceId!,
        text: text,
        // modelId: selectedModel ?? 'eleven_monolingual_v1',
        voiceSettings: VoiceSettings(
          similarityBoost: 0.75,
          stability: 0.50,
        ),
      ),
    );
    final audio = result;
    player = AudioPlayer();
    await player!.setSourceBytes(audio, mimeType: 'audio/wav');
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
  List<Map<String, dynamic>> voices = [];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      loadVoices();
    });
  }

  Future loadVoices() async {
    if (!ElevenlabsSpeech.isValid()) {
      return;
    }
    setState(() {
      isLoadingVoices = true;
    });
    voices = await ElevenlabsSpeech.elevenLabs.listVoicesRaw();
    setState(() {
      isLoadingVoices = false;
    });
  }

  Future loadUsage(BuildContext ctx) async {
    final Map user = await ElevenlabsSpeech.elevenLabs.getCurrentUserRaw();
    // final json = user.subscription.toJson();
    final jsonString = const JsonEncoder.withIndent('  ').convert(user);
    if (mounted)
      showDialog(
        // ignore: use_build_context_synchronously
        context: ctx,
        builder: (ctx) {
          return ContentDialog(
            content: SingleChildScrollView(
              child: Text(jsonString),
            ),
            actions: [
              Button(
                onPressed: () {
                  Navigator.of(ctx).pop();
                },
                child: Text('Ok'),
              ),
            ],
          );
        },
      );
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
            onFieldSubmitted: (value) async {
              AppCache.elevenLabsApiKey.value = value;
              await ElevenlabsSpeech.init();
              loadVoices();
            },
            suffix: Button(
                child: Text('Load voices'),
                onPressed: () async {
                  await ElevenlabsSpeech.init();
                  loadVoices();
                }),
            validator: (value) {
              if ((value ?? '').isEmpty) {
                return 'Please enter a valid API key';
              }
              return null;
            },
          ),
          if (voices.isNotEmpty) ...[
            Text('Voice ID*'),
            if (isLoadingVoices)
              ProgressBar()
            else
              DropDownButton(
                title: Text(
                    ElevenlabsSpeech.selectedVoiceName ?? 'Select a voice'),
                items: [
                  for (final voice in voices)
                    MenuFlyoutItem(
                      text: Text(voice['name']),
                      onPressed: () {
                        ElevenlabsSpeech.selectedVoiceId = voice['voice_id'];
                        ElevenlabsSpeech.selectedVoiceName = voice['name'];
                        setState(() {});
                      },
                    ),
                ],
              ),
          ],
          spacer,
          Divider(),
          Button(
            child: Text('Usage'),
            onPressed: () {
              loadUsage(context);
            },
          )
        ],
      ),
    );
  }
}
