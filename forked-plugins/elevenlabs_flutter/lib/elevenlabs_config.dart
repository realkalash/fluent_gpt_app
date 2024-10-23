import 'package:flutter/material.dart';

@immutable
class ElevenLabsConfig {
  final String apiKey;
  final String baseUrl;

  const ElevenLabsConfig({
    required this.apiKey,
    this.baseUrl = 'https://api.elevenlabs.io',
  });
}
