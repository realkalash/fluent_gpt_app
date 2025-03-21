import 'package:fluent_gpt/features/annoy_feature.dart';
import 'package:fluent_gpt/features/imgur_integration.dart';
import 'package:fluent_gpt/features/screenshot_tool.dart';
import 'package:fluent_gpt/features/text_to_speech.dart';
import 'package:fluent_gpt/features/open_ai_features.dart';

class AdditionalFeatures {
  static void initAdditionalFeatures({bool isStorageAccessGranted = false}) {
    // GDriveIntegration.init();
    ImgurIntegration.init();
    TextToSpeechService.init();
    ScreenshotTool.init(isStorageAccessGranted: isStorageAccessGranted);
    AnnoyFeature.init();
  }
}