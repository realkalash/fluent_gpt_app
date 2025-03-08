import 'package:fluent_gpt/common/custom_messages/image_custom_message.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';

import 'deepinfra_image_generator.dart';
import 'dalle_image_generator.dart';

enum ImageGeneratorEnum {
  dalleGenerator,
  deepinfraGenerator,
}

class ImageGeneratorFeature {
  static ImageGeneratorEnum selectedGenerator =
      ImageGeneratorEnum.values[AppCache.imageGenerator.value ?? 0];

  static Future<ImageCustomMessage> generateImage({
    required String prompt,
    required String apiKey,
    int n = 1,
    String? model,
    String size = '1024x1024',
    String quality = 'hd',
    String style = 'natural',
  }) async {
    prompt = prompt.replaceAll('/generate_image', '').trim();
    if (selectedGenerator == ImageGeneratorEnum.dalleGenerator) {
      return DalleImageGenerator.generateImage(
        prompt: prompt,
        apiKey: apiKey,
        n: n,
        model: model ?? 'dall-e-3',
        size: size,
        quality: quality,
        style: style,
      );
    } else if (selectedGenerator == ImageGeneratorEnum.deepinfraGenerator) {
      return DeepinfraImageGenerator.generateImage(
        prompt: prompt,
        apiKey: apiKey,
        model: model ?? 'black-forest-labs/FLUX-1.1-pro',
        n: n,
        size: size,
      );
    } else {
      throw Exception("Unknown generator selected");
    }
  }

  static Future<void> setGenerator(ImageGeneratorEnum generator) async {
    AppCache.imageGenerator.value = generator.index;
    selectedGenerator = generator;
  }
}
