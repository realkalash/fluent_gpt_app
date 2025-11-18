import 'dart:convert';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class Attachment {
  final XFile file;
  final bool isInternalScreenshot;
  String get path => file.path;
  String get name => file.name;
  String? get mimeType => file.mimeType;
  Future<Uint8List> readAsBytes() => file.readAsBytes();

  const Attachment({
    required this.file,
    required this.isInternalScreenshot,
  });

  factory Attachment.fromFile(XFile file) {
    return Attachment(
      file: file,
      isInternalScreenshot: false,
    );
  }

  factory Attachment.fromInternalScreenshot(String stringBase64) {
    final Uint8List uintList = base64Decode(stringBase64);
    return Attachment(
      file: XFile.fromData(
        uintList,
        mimeType: 'image/jpeg',
        length: uintList.length,
        name: 'screenshot-${uintList.length}.jpg',
      ),
      isInternalScreenshot: true,
    );
  }
  factory Attachment.fromInternalScreenshotBytes(Uint8List uintList) {
    return Attachment(
      file: XFile.fromData(
        uintList,
        mimeType: 'image/jpeg',
        length: uintList.length,
        name: 'screenshot-${uintList.length}.jpg',
      ),
      isInternalScreenshot: true,
    );
  }

  bool get isImage => mimeType?.contains('image') == true;
  bool get isText => mimeType?.contains('text') == true;
  bool get isWord => name.endsWith('.docx');
  bool get isExcel => name.endsWith('.xlsx') || name.endsWith('.xls');
  bool get isPdf => name.endsWith('.pdf');
}

extension AttachmentWidgetExtension on Attachment {
  Widget toWidgetThumbnail({void Function(Attachment)? onTap, void Function(Attachment)? onRemove}) {
    if (isImage) {
      return AttachmentImageThumbnail(attachment: this, onTap: onTap, onRemove: onRemove);
    }
    return Text(name);
  }
}

class AttachmentImageThumbnail extends StatefulWidget {
  const AttachmentImageThumbnail({super.key, required this.attachment, required this.onTap, required this.onRemove});
  final Attachment attachment;
  final void Function(Attachment)? onTap;
  final void Function(Attachment)? onRemove;

  @override
  State<AttachmentImageThumbnail> createState() => _AttachmentImageThumbnailState();
}

class _AttachmentImageThumbnailState extends State<AttachmentImageThumbnail> {
  Uint8List? imageBytes;
  @override
  void initState() {
    super.initState();
    widget.attachment.readAsBytes().then((value) {
      if (mounted)
        setState(() {
          imageBytes = value;
        });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (imageBytes == null) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Center(child: Icon(FluentIcons.document_16_filled)),
      );
    }
    return ClipRRect(
      borderRadius: const BorderRadius.all(Radius.circular(8)),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: SizedBox.square(
          dimension: 48,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () {
                    widget.onTap?.call(widget.attachment);
                  },
                  child: Image.memory(
                    imageBytes!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              if (widget.onRemove != null)
                Positioned(
                  top: 0,
                  right: 0,
                  child: GestureDetector(
                    onTap: () {
                      widget.onRemove?.call(widget.attachment);
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Color.fromARGB(206, 0, 0, 0),
                        borderRadius: const BorderRadius.all(Radius.circular(6)),
                      ),
                      child: const Icon(
                        FluentIcons.delete_16_filled,
                        color: Color(0xFFD32F2F),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
