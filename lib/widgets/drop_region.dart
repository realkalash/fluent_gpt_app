
import 'dart:developer';

import 'package:chatgpt_windows_flutter_app/pages/home_page.dart';
import 'package:chatgpt_windows_flutter_app/providers/chat_gpt_provider.dart';
import 'package:cross_file/cross_file.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';

class HomeDropRegion extends StatelessWidget {
  const HomeDropRegion({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<ChatGPTProvider>();
    return DropRegion(
      // Formats this region can accept.
      formats: Formats.standardFormats,
      hitTestBehavior: HitTestBehavior.translucent,
      onDropOver: (event) {
        // This drop region only supports copy operation.
        if (event.session.allowedOperations.contains(DropOperation.copy)) {
          return DropOperation.copy;
        } else {
          return DropOperation.none;
        }
      },
      onDropEnter: (event) {
        // This is called when region first accepts a drag. You can use this
        // to display a visual indicator that the drop is allowed.
        isDropOverlayVisible.add(true);
      },
      onDropLeave: (event) {
        // Called when drag leaves the region. Will also be called after
        // drag completion.
        // This is a good place to remove any visual indicators.
        isDropOverlayVisible.add(false);
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
            log('File dropped: ${xfile.mimeType} ${data.length} bytes');
            provider.addFileToInput(xfile);
          }, onError: (error) {
            log('Error reading value $error');
          });
        }
      },
      child: const SizedBox.expand(),
    );
  }
}