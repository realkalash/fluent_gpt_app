import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/features/imgur_integration.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:url_launcher/url_launcher_string.dart';

class SauceNaoImageFinder {
  /// Will open the browser with the search results
  ///
  /// Example usage:
  ///
  /// `https://saucenao.com/search.php?url=https://your-image-url.webp`
  static Future launchFindImage(String imageUrl) async {
    // Code to find image
    final fullUrl = 'https://saucenao.com/search.php?url=$imageUrl';
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
