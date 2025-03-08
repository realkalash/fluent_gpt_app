import 'dart:convert';
import 'dart:developer';
import 'package:fluent_gpt/common/custom_messages/image_custom_message.dart';
import 'package:http/http.dart' as http;

class DeepinfraImageGenerator {
  /// Native deepinfra API
  static Future<ImageCustomMessage> generateImage({
    required String prompt,
    required String apiKey,
    String model = "black-forest-labs/FLUX-1.1-pro",
    int n = 1,
    String size = "1024x1024",
  }) async {
    if (prompt.isEmpty) {
      throw Exception("Prompt cannot be empty");
    }
    final sizeSplit = size.split("x");
    final int width = int.parse(sizeSplit[0]);
    final int height = int.parse(sizeSplit[1]); 

    final requestBody = {
      "prompt": prompt,
      "n": n,
      "width": width,
      "height": height,
    };

    log("Deepinfra Image Generation Request to model $model: $requestBody");

    final response = await http.post(
      Uri.parse(
          "https://api.deepinfra.com/v1/inference/$model"), // Use the direct inference endpoint
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $apiKey"
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception(
          "Deepinfra Image Generation Failed: ${response.statusCode} ${response.reasonPhrase} ${response.body}");
    }

    final responseBody = jsonDecode(response.body);

    if (responseBody['status'] != 'ok') {
      throw Exception(
          "Deepinfra Image Generation Failed: Status not ok. Response: ${responseBody.toString()}");
    }

    final imageUrl = responseBody['image_url'];

    // Download the image
    final imageResponse = await http.get(Uri.parse(imageUrl));

    if (imageResponse.statusCode != 200) {
      throw Exception(
          "Failed to download image from URL: ${imageResponse.statusCode} ${imageResponse.reasonPhrase}");
    }

    final imageBytes = imageResponse.bodyBytes;
    final String base64Image = base64Encode(imageBytes);

    final ImageCustomMessage imageCustomMessage = ImageCustomMessage(
      fileName: "image.png",
      content: base64Image,
      revisedPrompt: prompt, // Deepinfra doesn't return revised_prompt in this flow
      generatedBy: model,
    );

    return imageCustomMessage;
  }

  // OpenAIlike API (doesnt work because of error on their side) "Content type application/json; charset=utf-8 is unknown"
  static Future<ImageCustomMessage> generateImageOpenAIlike({
    required String prompt,
    required String apiKey,
    String model = "black-forest-labs/FLUX-1.1-pro",
    String size = "1024x1024",
    int n = 1,
  }) async {
    final requestBody = {
      "prompt": prompt,
      "size": size,
      "model": model,
      "n": n
    };

    final response = await http.post(
      Uri.parse("https://api.deepinfra.com/v1/openai/images/generations"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $apiKey"
      },
      body: jsonEncode(requestBody),
    );

    if (response.statusCode != 200) {
      throw Exception(
          "Deepinfra Image Generation Failed: ${response.statusCode} ${response.reasonPhrase} ${response.body}");
    }

    final responseBody = jsonDecode(response.body);

    if (responseBody['data'] == null || responseBody['data'].isEmpty) {
      throw Exception(
          "Deepinfra Image Generation Failed: No data returned. Response: ${responseBody.toString()}");
    }

    final b64Json = responseBody['data'][0]['b64_json'];
    final revisedPrompt = responseBody['data'][0]['revised_prompt'];

    final decodedImage = base64Decode(b64Json);

    final String base64Image = base64Encode(decodedImage);

    final ImageCustomMessage imageCustomMessage = ImageCustomMessage(
      fileName: "image.png",
      content: base64Image,
      revisedPrompt: revisedPrompt,
      generatedBy: model,
    );

    return imageCustomMessage;
  }

}