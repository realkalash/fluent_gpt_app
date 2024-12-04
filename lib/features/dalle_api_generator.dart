import 'dart:convert';
import 'package:fluent_gpt/common/custom_messages/image_custom_message.dart';
import 'package:http/http.dart' as http;

class DalleApiGenerator {
  /* 
  curl https://api.openai.com/v1/images/generations \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -d '{
    "model": "dall-e-3",
    "prompt": "a white siamese cat",
    "n": 1,
    "size": "1024x1024",
    "quality": "hd" // or standard
    "style": "natural" // or vivid
  }'
   */

  static Future<ImageCustomMessage> generateImage({
    required String prompt,
    required String apiKey,
    int n = 1,
    String model = "dall-e-3",
    String size = "1024x1024",
    String quality = "hd",
    String style = "natural",
  }) async {
    if (prompt.isEmpty) {
      throw Exception("Prompt cannot be empty");
    }
    // response_format ('url' or 'b64_json'): The format in which the generated images are returned. Must be one of "url" or "b64_json". Defaults to "url".
    // lets use b64_json
    final requestBody = {
      "model": model,
      "prompt": prompt,
      "n": n,
      "size": size,
      "quality": quality,
      "style": style,
      "response_format": "b64_json",
    };
    final response = await http.post(
      Uri.parse("https://api.openai.com/v1/images/generations"),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $apiKey"
      },
      body: jsonEncode(requestBody),
    );
    /* 
    "{
  "created": 1731627443,
  "data": [
    {
      "revised_prompt": "Imagine a cozy domestic scene featuring an adult cat...",
      "b64_json": "iVBORw0KGgoAAAANSUhEUgAABAAAAAQACAIAA
     */
    if (response.statusCode != 200) {
      throw Exception("Failed to generate image. ${response.body} ${response.statusCode} ${response.reasonPhrase}");
    }
    final responseBody = jsonDecode(response.body);
    final ImageCustomMessage imageCustomMessage = ImageCustomMessage(
      fileName: "image.png",
      content: responseBody["data"][0]["b64_json"],
      revisedPrompt: responseBody["data"][0]["revised_prompt"],
      generatedBy: model,
    );
    return imageCustomMessage;
  }
}
