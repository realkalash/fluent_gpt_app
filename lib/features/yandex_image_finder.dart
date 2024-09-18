import 'dart:typed_data';

import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/features/imgur_integration.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:url_launcher/url_launcher_string.dart';

class YandexImageFinder {
  /// Will open the browser with the search results
  ///
  /// Example usage:
  ///
  /// `https://yandex.com/images/search?rpt=imageview&url=your_image_url`
  static Future launchFindImage(String imageUrl) async {
    // Code to find image
    final fullUrl = 'https://yandex.com/images/search?rpt=imageview&url=$imageUrl';
    await launchUrlString(fullUrl);
  }

  static uploadToImgurAndFindImageBytes(Uint8List bytes) async {
    if (AppCache.useImgurApi.value != true) {
      throw Exception('Imgur API is not enabled');
    }

    final png = await bytes.toPNG();
    final url =
        await ImgurIntegration.uploadImageBytes(await png.readAsBytes());
    await launchFindImage(url);
  }
}
