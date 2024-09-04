import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:http/http.dart' as http;

class ImgurIntegration {
  static String clientId = 'YOUR_IMGUR_CLIENT_ID';

  void init() {
    clientId = AppCache.imgurClientId.value!;
  }

  static authenticate(String clientId) {
    ImgurIntegration.clientId = clientId;
    AppCache.imgurClientId.value = clientId;
  }

  static Future<String> uploadImage(File imageFile) async {
    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await http.post(
      Uri.parse('https://api.imgur.com/3/image'),
      headers: {
        'Authorization': 'Client-ID $clientId',
      },
      body: {
        'image': base64Image,
        'type': 'base64',
        'privacy':
            'hidden', // Ensure the image is not added to the public gallery
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']['link'];
    } else {
      throw Exception('Failed to upload image: ${response.body}');
    }
  }

  static Future<String> uploadImageBytes(Uint8List bytes) async {
    final base64Image = base64Encode(bytes);

    final response = await http.post(
      Uri.parse('https://api.imgur.com/3/image'),
      headers: {
        'Authorization': 'Client-ID $clientId',
      },
      body: {
        'image': base64Image,
        'type': 'base64',
        'privacy': 'hidden', // Ensure the image is not added to the public gallery
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['data']['link'];
    } else {
      throw Exception('Failed to upload image: ${response.body}');
    }
  }
}
