import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class ImageUtil {
  /// Resizes and compresses an image to fit within 1280x720 and 1MB max size
  ///
  /// Maintains aspect ratio and minimizes quality loss while meeting size requirements
  /// Returns processed image as Uint8List
  static Future<Uint8List> resizeAndCompressImage(
    Uint8List imageBytes, {
    int maxWidth = 1920,
    int maxHeight = 1080,
    int maxSizeInBytes = 1024 * 1024, // 1MB
  }) async {
    final start = DateTime.now();
    try {
      // Decode the image
      img.Image? decodedImage = img.decodeImage(imageBytes);
      if (decodedImage == null) {
        throw Exception('Failed to decode image');
      }

      // Calculate new dimensions maintaining aspect ratio
      double aspectRatio = decodedImage.width / decodedImage.height;
      int newWidth = maxWidth;
      int newHeight = maxHeight;
      Uint8List processedImage;
      if (decodedImage.width > maxWidth || decodedImage.height > maxHeight) {
        if (aspectRatio > maxWidth / maxHeight) {
          // Width is the limiting factor
          newWidth = maxWidth;
          newHeight = (newWidth / aspectRatio).round();
        } else {
          // Height is the limiting factor
          newHeight = maxHeight;
          newWidth = (newHeight * aspectRatio).round();
        }
        // Resize the image
        final cmd = img.Command()
          ..image(decodedImage)
          ..copyResize(
            width: newWidth,
            height: maxHeight,
            maintainAspect: true,
            interpolation: img.Interpolation.linear,
          );
        // On platforms that support Isolates, execute the image commands asynchronously on an isolate thread.
        // Otherwise, the commands will be executed synchronously.
        final comRes = await cmd.execute();
        decodedImage = comRes.outputImage!;
      }

      // processedImage = comRes.outputBytes!;

      // Try PNG encoding first (lossless)
      processedImage = Uint8List.fromList(img.encodePng(decodedImage));
      // processedImage = decodedImage.getBytes();

      // If size is already under the limit, return the PNG
      if (processedImage.length <= maxSizeInBytes) {
        if (kDebugMode) {
        final end = DateTime.now();
          print(
              'Image processing took: ${end.difference(start).inMilliseconds}ms');
          print('Final image size: ${processedImage.length} bytes');
        }
        return processedImage;
      }

      // If PNG is too large, use JPG with quality reduction
      int quality = 90;
      Uint8List jpgImage =
          Uint8List.fromList(img.encodeJpg(decodedImage, quality: quality));

      // Reduce quality incrementally until file size is acceptable
      while (jpgImage.length > maxSizeInBytes && quality > 10) {
        quality -= 5;
        jpgImage =
            Uint8List.fromList(img.encodeJpg(decodedImage, quality: quality));
      }
      final end = DateTime.now();
      if (kDebugMode) {
        print(
            'Image processing took: ${end.difference(start).inMilliseconds}ms');
        print('Final image size: ${jpgImage.length} bytes');
      }

      return jpgImage;
    } catch (e) {
      throw Exception('Error processing image: $e');
    }
  }
}
