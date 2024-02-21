import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

Future<String> encodeImage(String imagePath) async {
  final File imageFile = File(imagePath);
  final Uint8List imageBytes = await imageFile.readAsBytes();
  return base64Encode(imageBytes);
}