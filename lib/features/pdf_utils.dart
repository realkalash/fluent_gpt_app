import 'dart:io';
import 'dart:typed_data';
import 'package:printing/printing.dart';

class PdfUtils {
  static Future<List<Uint8List>> getImagesFromPdf(Uint8List pdfBytes) async {
    final List<Uint8List> images = [];
    final result = Printing.raster(pdfBytes, dpi: 72);
    await for (final page in result) {
      final image = page.asImage();
      images.add(image.toUint8List());
    }
    return images;
  }

  static Future<List<Uint8List>> getImagesFromPdfPath(String path) async {
    final file = File(path);
    final pdfBytes = await file.readAsBytes();
    final List<Uint8List> images = [];
    final result = Printing.raster(pdfBytes, dpi: 72);
    await for (final page in result) {
      final image = await page.toPng();
      // print('Converted page: size: ${_bytesToKb(image.lengthInBytes)}. ${page.width}x${page.height}');
      images.add(image);
    }
    return images;
  }

  static double _bytesToKb(int bytes) {
    return bytes / 1024;
  }
}
