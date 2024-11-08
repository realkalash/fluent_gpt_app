import 'package:fluent_gpt/common/attachment.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/pages/home_page.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:cross_file/cross_file.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:mime_type/mime_type.dart';
import 'package:provider/provider.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

class HomeDropRegion extends StatelessWidget {
  const HomeDropRegion({super.key});
  static const allowedFormats = [
    'text/plain',
    'text/csv',
    // TODO: we need to add support for .doc, .xls files
    // 'application/msword',
    // 'application/vnd.ms-excel',
    // word
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    // excel
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  ];

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ChatProvider>();
    return DropRegion(
      // Formats this region can accept.
      formats: Formats.standardFormats,
      hitTestBehavior: HitTestBehavior.translucent,
      onDropOver: (event) {
        // This drop region only supports copy operation.
        if (event.session.items.first.platformFormats.first.contains('image')) {
          return DropOperation.copy;
        } else if (event.session.items.first.platformFormats.first ==
            'text/plain') {
          return DropOperation.copy;
        }
        return DropOperation.copy;
      },
      onDropEnter: (event) {
        // This is called when region first accepts a drag. You can use this
        // to display a visual indicator that the drop is allowed.
        if (event.session.items.first.platformFormats.first.contains('image')) {
          isDropOverlayVisible.add(DropOverlayState.dropOver);
        } else if (allowedFormats
            .contains(event.session.items.first.platformFormats.first)) {
          isDropOverlayVisible.add(DropOverlayState.dropOver);
        } else {
          isDropOverlayVisible.add(DropOverlayState.dropInvalidFormat);
          log('Invalid format: ${event.session.items.first.platformFormats.first}');
          displayInfoBar(context, builder: (ctx, close) {
            return InfoBar(
              title: Text('Invalid format'),
              content: Text(event.session.items.first.platformFormats.first),
              severity: InfoBarSeverity.error,
            );
          });
        }
      },
      onDropLeave: (event) {
        // Called when drag leaves the region. Will also be called after
        // drag completion.
        // This is a good place to remove any visual indicators.
        isDropOverlayVisible.add(DropOverlayState.none);
      },
      onPerformDrop: (event) async {
        // Called when user dropped the item. You can now request the data.
        // Note that data must be requested before the performDrop callback
        // is over.
        final item = event.session.items.first;
        // data reader is available now
        final reader = item.dataReader!;

        if (reader.canProvide(Formats.png)) {
          reader.getFile(Formats.png, (file) async {
            final data = await file.readAll();
            final xfile = XFile.fromData(
              data,
              name: file.fileName,
              mimeType: 'image/png',
              length: data.length,
            );
            if (data.lengthInBytes == 0) {
              // ignore: use_build_context_synchronously
              displayInfoBar(context, builder: (ctx, close) {
                return InfoBar(
                  title: Text('File is empty'),
                  content: Text('File is empty or not supported'),
                  severity: InfoBarSeverity.error,
                );
              });
              return;
            }
            log('File dropped: ${xfile.mimeType} ${data.length} bytes');
            provider.addAttachemntAiLens(await xfile.imageToBase64());
          }, onError: (error) {
            log('Error reading value $error');
          });
        } else if (reader.platformFormats.first == 'text/csv') {
          reader.getFile(Formats.csv, (value) async {
            final fileContentBytes = await value.readAll();
            final mimeType = mime(value.fileName);
            final xfile = XFile.fromData(
              fileContentBytes,
              name: value.fileName,
              mimeType: mimeType,
              length: value.fileSize ?? fileContentBytes.length,
              path: value.fileName,
            );
            log('File dropped: ${xfile.mimeType} ${fileContentBytes.length} bytes');
            provider.addAttachmentToInput(
                Attachment(file: xfile, isInternalScreenshot: false));
          }, onError: (error) {
            log('Error reading value $error');
          });
        } else {
          reader.getFile(null, (value) async {
            final fileContentBytes = await value.readAll();
            final mimeType = mime(value.fileName);
            final xfile = XFile.fromData(
              fileContentBytes,
              name: value.fileName,
              mimeType: mimeType,
              length: value.fileSize ?? fileContentBytes.length,
              path: value.fileName,
            );
            log('File dropped: ${xfile.mimeType} ${fileContentBytes.length} bytes');
            provider.addAttachmentToInput(
                Attachment(file: xfile, isInternalScreenshot: false));
          }, onError: (error) {
            log('Error reading value $error');
          });
        }
      },
      child: const SizedBox.expand(),
    );
  }
}
