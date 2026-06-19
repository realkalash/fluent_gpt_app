import 'dart:typed_data';

import 'package:fluent_gpt/features/imgur_integration.dart';
import 'package:fluent_gpt/log.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher_string.dart';

/// Reverse-image-search providers. Each builds a results URL from a public
/// image URL; the browser does the actual lookup.
enum ReverseSearchEngine {
  googleLens('Google Lens'),
  yandex('Yandex'),
  bing('Bing'),
  tineye('TinEye'),
  sauceNao('SauceNao');

  const ReverseSearchEngine(this.label);

  /// Human-facing name shown in the engine picker.
  final String label;

  /// Brand logo asset shown in the engine picker.
  String get assetLogo {
    switch (this) {
      case ReverseSearchEngine.googleLens:
        return 'assets/google_lens_favicon.png';
      case ReverseSearchEngine.yandex:
        return 'assets/yandex_favicon.png';
      case ReverseSearchEngine.bing:
        return 'assets/bing_favicon.png';
      case ReverseSearchEngine.tineye:
        return 'assets/tineye_favicon.png';
      case ReverseSearchEngine.sauceNao:
        return 'assets/saucenao_favicon.png';
    }
  }

  /// The browser results page for an already-hosted [imageUrl].
  String searchUrl(String imageUrl) {
    final enc = Uri.encodeComponent(imageUrl);
    switch (this) {
      case ReverseSearchEngine.googleLens:
        return 'https://lens.google.com/uploadbyurl?url=$enc';
      case ReverseSearchEngine.yandex:
        return 'https://yandex.com/images/search?rpt=imageview&url=$enc';
      case ReverseSearchEngine.bing:
        return 'https://www.bing.com/images/searchbyimage?cbir=sbi&imgurl=$enc';
      case ReverseSearchEngine.tineye:
        return 'https://tineye.com/search?url=$enc';
      case ReverseSearchEngine.sauceNao:
        return 'https://saucenao.com/search.php?url=$enc';
    }
  }
}

/// Hosts a cropped image on a public URL, then opens a reverse-image-search
/// engine in the browser.
///
/// Default host is the keyless, auto-expiring **litterbox** (catbox) — nothing
/// to configure and the upload self-deletes after an hour. If that fails and
/// the user has set up an Imgur client ID, we fall back to Imgur.
class ReverseImageSearch {
  ReverseImageSearch._();
  static final ReverseImageSearch instance = ReverseImageSearch._();

  static const _litterboxApi = 'https://litterbox.catbox.moe/resources/internals/api.php';

  /// Hosts [bytes] (encoded PNG/JPEG) and opens [engine]'s results page.
  /// Returns `false` if hosting or launching failed (caller surfaces the error).
  Future<bool> launchSearch(Uint8List bytes, ReverseSearchEngine engine) async {
    final url = await hostImage(bytes);
    if (url == null) return false;
    try {
      return await launchUrlString(engine.searchUrl(url));
    } catch (e) {
      logError('[ReverseImageSearch] launch failed: $e');
      return false;
    }
  }

  /// Uploads [bytes] and returns a public URL, or null on failure.
  Future<String?> hostImage(Uint8List bytes) async {
    final litter = await _uploadLitterbox(bytes);
    if (litter != null) return litter;
    // Litterbox unreachable — fall back to Imgur if the user configured it.
    if (ImgurIntegration.isClientIdValid()) {
      try {
        return await ImgurIntegration.uploadImageBytes(bytes);
      } catch (e) {
        logError('[ReverseImageSearch] Imgur fallback failed: $e');
      }
    }
    return null;
  }

  Future<String?> _uploadLitterbox(Uint8List bytes) async {
    try {
      final req = http.MultipartRequest('POST', Uri.parse(_litterboxApi))
        ..headers['User-Agent'] = 'fluent_gpt'
        ..fields['reqtype'] = 'fileupload'
        ..fields['time'] = '1h'
        ..files.add(http.MultipartFile.fromBytes('fileToUpload', bytes, filename: 'lens.png'));
      final resp = await http.Response.fromStream(await req.send());
      final body = resp.body.trim();
      if (resp.statusCode == 200 && body.startsWith('http')) return body;
      logError('[ReverseImageSearch] litterbox ${resp.statusCode}: $body');
    } catch (e) {
      logError('[ReverseImageSearch] litterbox upload failed: $e');
    }
    return null;
  }
}
