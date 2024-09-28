import 'package:fluent_gpt/features/deepgram_speech.dart';
import 'package:fluent_gpt/features/g_drive_integration.dart';
import 'package:fluent_gpt/features/imgur_integration.dart';
import 'package:fluent_gpt/features/screenshot_tool.dart';

class AdditionalFeatures {
  static void initAdditionalFeatures({bool isStorageAccessGranted = false}) {
    GDriveIntegration.init();
    ImgurIntegration.init();
    DeepgramSpeech.init();
    ScreenshotTool.init(isStorageAccessGranted: isStorageAccessGranted);
  }
}