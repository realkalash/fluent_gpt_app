import 'package:fluent_gpt/features/g_drive_integration.dart';
import 'package:fluent_gpt/features/imgur_integration.dart';

class AdditionalFeatures {
  static initAdditionalFeatures() {
    GDriveIntegration.init();
    ImgurIntegration().init();
  }
}
