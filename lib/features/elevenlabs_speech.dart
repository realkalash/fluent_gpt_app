import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:elevenlabs_flutter/elevenlabs_config.dart';
import 'package:elevenlabs_flutter/elevenlabs_types.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:elevenlabs_flutter/elevenlabs_flutter.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/log.dart';

import 'package:fluent_gpt/widgets/text_link.dart';
import 'package:fluent_gpt/widgets/wiget_constants.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class ElevenlabsSpeech {
  static ElevenLabsAPI? _elevenLabs;
  static ElevenLabsAPI get elevenLabs {
    if (_elevenLabs == null) {
      init();
    }
    return _elevenLabs!;
  }

  static String selectedVoiceName = 'Aria';

  static String selectedModel = 'eleven_turbo_v2_5';
  static final modelsMap = {
    'eleven_monolingual_v1':
        "very first model, English v1, set the foundation for what's to come. This model was created specifically for English and is the smallest and fastest model we offer. Trained on a focused, English-only dataset, it quickly became the go-to choice for English-based tasks. As our oldest model, it has undergone extensive optimization to ensure reliable performance but it is also the most limited and generally the least accurate",
    'eleven_multilingual_v1':
        "Taking a step towards global access and usage, we introduced Multilingual v1 as our second offering. Has been an experimental model ever since release. To this day, it still remains in the experimental phase. However, it paved the way for the future as we took what we learned to improve the next iteration. Multilingual v1 currently supports a range of languages",
    'eleven_turbo_v2':
        "(50%-Cheaper) Using cutting-edge technology, this is a highly optimized model for real-time applications that require very low latency, but it still retains the fantastic quality offered in our other models. Even if optimized for real-time and more conversational applications, we still recommend testing it out for other applications as it is very versatile and stable",
    'eleven_multilingual_v2':
        "Multilingual v2, which stands as a testament to our dedication to progress. This model is a powerhouse, excelling in stability, language diversity, and accuracy in replicating accents and voices. Its speed and agility are remarkable considering its size. Multilingual v2 supports 29 languages",
    'eleven_turbo_v2_5':
        "(50%-Cheaper) Our high quality, lowest latency model that's great for developer use cases where speed matters.  It supports 32 languages",
  };
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

    selectedVoiceName = AppCache.elevenlabsVoiceModelName.value!;
    selectedModel = AppCache.elevenlabsModel.value ?? selectedModel;
    if (selectedModel.isEmpty) {
      selectedModel = 'eleven_turbo_v2_5';
    }
  }

  static bool isValid() {
    return AppCache.elevenLabsApiKey.value!.isNotEmpty;
  }

  static Future showConfigureDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        content: ElevenLabsConfigContainer(),
        actions: [
          Button(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  static Future readAloud(
    String text, {
    Function()? onCompleteReadingAloud,
  }) async {
    if (!isValid()) {
      return;
    }
    final fileName =
        (AppCache.elevenlabsVoiceModelName.value ?? '') + text.hashCode.toString();
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
    if (_elevenLabs == null) {
      await init();
    }
    final requestObj = TextToSpeechRequest(
      voiceId: AppCache.elevenlabsVoiceModelId.value!,
      text: text,
      // can be "eleven_monolingual_v1"
      modelId: selectedModel,
      voiceSettings: VoiceSettings(
        similarityBoost: 0.75,
        stability: 0.50,
      ),
    );
    final json = requestObj.toJson();
    /* 
    not working:
    Request elevenlabs: {voice_id: eleven_turbo_v2_5, model_id: eleven_turbo_v2, text: Hey User, are you still up for some late-night chatting 🌙, voice_settings: {similarity_boost: 0.75, stability: 0.5}}
    working
    Request elevenlabs: {voice_id: eVItLK1UvXctxuaRV2Oq, model_id: eleven_turbo_v2, text: Hey User, are you still up for some late-night chatting 🌙, voice_settings: {similarity_boost: 0.75, stability: 0.5}}
     */
    log('Request elevenlabs: $json');
    final result = await _elevenLabs!.synthesizeBytes(requestObj,
        voiceId: AppCache.elevenlabsVoiceModelId.value!);
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

  static List loadAiModelVersions() {
    List models = [];
    if (!isValid()) {
      return models;
    }

    return models;
  }
}

class ElevenLabsConfigContainer extends StatefulWidget {
  const ElevenLabsConfigContainer({super.key});

  @override
  State<ElevenLabsConfigContainer> createState() =>
      _ElevenLabsConfigContainerState();
}

class _ElevenLabsConfigContainerState extends State<ElevenLabsConfigContainer> {
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

  bool obscure = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ElevenLabs API Key*'),
        TextFormBox(
          obscureText: obscure,
          onChanged: (value) {
            AppCache.elevenLabsApiKey.value = value;
          },
          initialValue: AppCache.elevenLabsApiKey.value,
          onFieldSubmitted: (value) async {
            AppCache.elevenLabsApiKey.value = value;
            await ElevenlabsSpeech.init();
            loadVoices();
          },
          suffix: IconButton(
              icon: Icon(FluentIcons.eye_20_regular),
              onPressed: () {
                setState(() {
                  obscure = !obscure;
                });
              }),
          validator: (value) {
            if ((value ?? '').isEmpty) {
              return 'Please enter a valid API key';
            }
            return null;
          },
        ),
        const Align(
          alignment: Alignment.centerLeft,
          child: LinkTextButton(
            'https://elevenlabs.io/app/speech-synthesis/text-to-speech',
            url: 'https://elevenlabs.io/app/speech-synthesis/text-to-speech',
          ),
        ),
        if (isLoadingVoices) ProgressBar(),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.end,
          children: [
            Button(
              child: Text('Load voices'),
              onPressed: () async {
                await ElevenlabsSpeech.init();
                loadVoices();
              },
            ),
            if (voices.isNotEmpty) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Voice ID*'),
                  DropDownButton(
                    title: Text(ElevenlabsSpeech.selectedVoiceName),
                    items: [
                      for (final voice in voices)
                        MenuFlyoutItem(
                          text: Text(voice['name']),
                          onPressed: () {
                            AppCache.elevenlabsVoiceModelId.value =
                                voice['voice_id'];
                            AppCache.elevenlabsVoiceModelName.value =
                                voice['name'];
                            ElevenlabsSpeech.selectedVoiceName = voice['name'];
                            setState(() {});
                          },
                        ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Model (Can make voice smarter)'),
                  DropDownButton(
                    title: Text(ElevenlabsSpeech.selectedModel),
                    items: [
                      for (final voice in ElevenlabsSpeech.modelsMap.entries)
                        MenuFlyoutItem(
                          text: Tooltip(
                              message: voice.value, child: Text(voice.key)),
                          trailing: Tooltip(
                            message: voice.value,
                            child: Icon(FluentIcons.question_circle_24_regular),
                          ),
                          onPressed: () {
                            ElevenlabsSpeech.selectedModel = voice.key;
                            AppCache.elevenlabsVoiceModelId.value = voice.key;
                            AppCache.elevenlabsModel.value = voice.key;
                            setState(() {});
                          },
                        ),
                    ],
                  ),
                ],
              )
            ]
          ],
        ),
        spacer,
        Divider(),
        Button(
          child: Text('Usage'),
          onPressed: () {
            loadUsage(context);
          },
        )
      ],
    );
  }
}
