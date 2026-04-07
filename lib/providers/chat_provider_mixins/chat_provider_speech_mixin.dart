import 'package:deepgram_speech_to_text/deepgram_speech_to_text.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/features/apple_speech_dictation.dart';
import 'package:fluent_gpt/features/deepgram_speech.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/pages/new_settings_page.dart';
import 'package:fluent_gpt/providers/chat_provider_mixins/chat_provider_base_mixin.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:record/record.dart';

mixin ChatProviderSpeechMixin on ChangeNotifier, ChatProviderBaseMixin {
  Stream<List<int>>? micStream;
  DeepgramLiveListener? transcriber;
  AudioRecorder? recorder;

  Future<bool> startListeningForInput() async {
    if (useAppleSpeechRecognition()) {
      return _startListeningMacOS();
    }
    return _startListeningDeepgram();
  }

  Future<bool> _startListeningMacOS() async {
    try {
      final ok = await startAppleSpeechDictation(
        initialText: messageController.text,
        onText: (t) => messageController.text = t,
        onError: (e) => logError('Apple speech error: ${e.errorMsg}'),
      );
      if (!ok) {
        displayErrorInfoBar(
          title: 'Speech recognition unavailable'.tr,
          message: 'Check Microphone and Speech Recognition in System Settings.'.tr,
        );
      }
      return ok;
    } catch (e, stack) {
      logError('Speech error:\n$e', stack);
      return false;
    }
  }

  Future<bool> _startListeningDeepgram() async {
    try {
      if (!DeepgramSpeech.isValid()) {
        displayInfoBar(context!, builder: (ctx, close) {
          return InfoBar(
            title: Text('Deepgram API key is not set'.tr),
            severity: InfoBarSeverity.warning,
            action: Button(
              onPressed: () async {
                close();
                // ensure its closed
                await Future.delayed(const Duration(milliseconds: 200));
                Navigator.of(context!).push(
                  FluentPageRoute(builder: (ctx) => const NewSettingsPage(initialIndex: 4)),
                );
              },
              child: Text('Settings'.tr),
            ),
          );
        });
        return false;
      }
      recorder = AudioRecorder();
      final devices = await recorder!.listInputDevices();
      if (devices.isEmpty) {
        displayErrorInfoBar(
          title: 'No microphone found'.tr,
        );
        return false;
      }
      micStream = await recorder!.startStream(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: 16000,
          numChannels: 1,
          device: AppCache.micrpohoneDeviceId.value != null
              ? InputDevice(
                  id: AppCache.micrpohoneDeviceId.value!, label: AppCache.micrpohoneDeviceName.value ?? 'Unknown name')
              : devices.first,
        ),
      );

      // https://developers.deepgram.com/reference/listen-live
      final streamParams = <String, dynamic>{
        'model': 'nova-3',
        'language': AppCache.speechLanguage.value!,
      };
      transcriber = DeepgramSpeech.deepgram.listen.liveListener(micStream!, queryParams: streamParams);
      transcriber!.stream.listen((res) {
        if (res.transcript?.isNotEmpty == true) {
          messageController.text += '${res.transcript!} ';
        }
      });
      transcriber!.start();
    } catch (e, stack) {
      logError('Speech error:\n$e', stack);
      return false;
    }
    return true;
  }

  Future<void> stopListeningForInput() async {
    if (useAppleSpeechRecognition()) {
      await stopAppleSpeechDictation();
      return;
    }
    try {
      transcriber!.pause(keepAlive: false);
      await transcriber!.close();
      transcriber = null;
    } catch (e, stack) {
      logError('Error while stopping listening: $e', stack);
    }
    try {
      await recorder!.cancel();
      await Future.delayed(const Duration(milliseconds: 500));
      await recorder!.dispose();
    } catch (e, stack) {
      logError('Error while stopping audio stream: $e', stack);
    }
    micStream = null;
  }
}
