import 'package:deepgram_speech_to_text/deepgram_speech_to_text.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/features/deepgram_speech.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:record/record.dart';
import 'package:rxdart/rxdart.dart';

class PushToTalkTool {
  static final BehaviorSubject<bool> _isRecording =
      BehaviorSubject<bool>.seeded(false);
  static bool get isRecording => _isRecording.value;
  static ValueStream<bool> get isRecordingStream => _isRecording.stream;
  static set isRecording(bool value) {
    if (value == _isRecording.value) return;
    _isRecording.add(value);
  }

  static AudioRecorder? _recorder;
  static Stream<List<int>>? micStream;
  static DeepgramLiveTranscriber? transcriber;
  static String? text;

  static Future<void> start() async {
    if (isRecording) return;
    if (!DeepgramSpeech.isValid()) return;

    isRecording = true;
    text = '';
    try {
      _recorder = AudioRecorder();
      micStream = await _recorder!.startStream(const RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      ));
      final streamParams = {
        'detect_language': false, // not supported by streaming API
        'language': AppCache.speechLanguage.value!,
        // must specify encoding and sample_rate according to the audio stream
        'encoding': 'linear16',
        'sample_rate': 16000,
      };
      transcriber = DeepgramSpeech.deepgram
          .createLiveTranscriber(micStream!, queryParams: streamParams);
      transcriber!.stream.listen((res) {
        if (res.transcript?.isNotEmpty == true) {
          text = '$text${res.transcript!} ';
          ChatProvider.messageControllerGlobal.text = text ?? '';
        }
      });
      await transcriber!.start();
    } catch (e) {
      logError(e.toString());
      isRecording = false;
    }
  }

  static Future<String?> stop() async {
    if (isRecording == false) return null;
    try {
      transcriber!.pause(keepAlive: false);
      await transcriber!.close();
      return text;
    } catch (e) {
      logError(e.toString());
      return null;
    } finally {
      transcriber = null;
      _recorder = null;
      isRecording = false;
    }
  }
}