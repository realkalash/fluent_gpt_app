import 'dart:async';

import 'package:fluent_gpt/common/attachment.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:cross_file/cross_file.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:mime_type/mime_type.dart';
import 'package:drag_and_drop_windows/drag_and_drop_windows.dart';
import 'package:provider/provider.dart';
import 'package:rxdart/subjects.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as ic;

enum DropOverlayState {
  none,
  dropOver,
  dropInvalidFormat,
}

// isDropOverlayVisible is a BehaviorSubject that is used to show the overlay when a drag is over the drop region.
final BehaviorSubject<DropOverlayState> isDropOverlayVisible =
    BehaviorSubject<DropOverlayState>.seeded(DropOverlayState.none);

class HomeDropOverlay extends StatelessWidget {
  const HomeDropOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DropOverlayState>(
      stream: isDropOverlayVisible,
      builder: (context, snapshot) {
        if (snapshot.data == DropOverlayState.dropOver) {
          return Container(
            color: Colors.black.withAlpha(51),
            child: Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: FluentTheme.of(context).accentColor.withAlpha(127),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: const Center(
                  child: Icon(
                    ic.FluentIcons.attach_24_filled,
                    size: 64,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
        }
        if (snapshot.data == DropOverlayState.dropInvalidFormat) {
          return Container(
            color: Colors.black.withAlpha(51),
            child: Center(
              child: Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(128),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: const Center(
                  child: Icon(
                    ic.FluentIcons.warning_24_filled,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class HomeDropRegion extends StatefulWidget {
  const HomeDropRegion({super.key, this.onDrop, this.showAiLens = true});
  final VoidCallback? onDrop;
  final bool showAiLens;
  static const allowedFormats = {
    'text/plain': true,
    'text/csv': true,
    'text/html': true,
    'png': true,
    'image/png': true,
    'image/jpeg': true,
    'image/jpg': true,
    'image/webp': true,
    'image/gif': true,
    'image/bmp': true,
    'image/tiff': true,
    'image/ico': true,
    // TODO: we need to add support for .doc, .xls files
    // 'application/msword': true,
    // 'application/vnd.ms-excel': true,
    // word
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
        true,
    // excel
    'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': true,
    'text/_moz_htmlcontext': true,
    'text/_moz_htmlinfo': true,
    'application/octet-stream;extension=url': true,
  };

  @override
  State<HomeDropRegion> createState() => _HomeDropRegionState();
}

class _HomeDropRegionState extends State<HomeDropRegion> {
  bool isDraggingOver = false;
  late StreamSubscription<List<String>> subscription;
  ChatProvider? provider;
  @override
  void initState() {
    super.initState();
    isDraggingOver = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      subscription = dropEventStream.listen((paths) async {
        log('Dropped files: $paths');
        try {
          // ignore: use_build_context_synchronously
          provider = context.read<ChatProvider>();
        } catch (e) {
          logError('Error dropping files: $e');
        }

        if (paths.isEmpty) {
          logError('No provider or paths');
          return;
        }
        for (final path in paths) {
          final name = path.split('\\').last;
          final mimeType = mime(name);
          if (HomeDropRegion.allowedFormats[mimeType] != true) {
            isDropOverlayVisible.add(DropOverlayState.dropInvalidFormat);
            displayErrorInfoBar(title: 'Invalid format', message: mimeType);
            await Future.delayed(const Duration(milliseconds: 1000));
            isDropOverlayVisible.add(DropOverlayState.none);
            continue;
          }
          final file = XFile(path, name: name, mimeType: mime(name));
          log('File dropped: ${file.mimeType} ${await file.length()} bytes');
          provider!.addFileToInput(file);
        }
      });
    });
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand();
    // return DropRegion(
    //   // Formats this region can accept.
    //   formats: Formats.standardFormats,
    //   hitTestBehavior: HitTestBehavior.translucent,
    //   onDropOver: (event) {
    //     // This drop region only supports copy operation.
    //     if (event.session.items.first.platformFormats.first.contains('image')) {
    //       return DropOperation.copy;
    //     } else if (event.session.items.first.platformFormats.first ==
    //         'text/plain') {
    //       return DropOperation.copy;
    //     }
    //     return DropOperation.copy;
    //   },
    //   onDropEnter: (event) {
    //     // This is called when region first accepts a drag
    //     for (final format in event.session.items.first.platformFormats) {
    //       if (allowedFormats.containsKey(format)) {
    //         isDropOverlayVisible.add(DropOverlayState.dropOver);
    //         return;
    //       }
    //     }

    //     isDropOverlayVisible.add(DropOverlayState.dropInvalidFormat);
    //     log('Invalid format: ${event.session.items.first.platformFormats.first}');
    //     displayInfoBar(context, builder: (ctx, close) {
    //       return InfoBar(
    //         title: Text('Invalid format'),
    //         content: Text(event.session.items.first.platformFormats.first),
    //         severity: InfoBarSeverity.error,
    //       );
    //     });
    //   },
    //   onDropLeave: (event) {
    //     // Called when drag leaves the region. Will also be called after
    //     // drag completion.
    //     // This is a good place to remove any visual indicators.
    //     isDropOverlayVisible.add(DropOverlayState.none);
    //   },
    //   onPerformDrop: (event) async {
    //     // Called when user dropped the item. You can now request the data.
    //     // Note that data must be requested before the performDrop callback
    //     // is over.
    //     final item = event.session.items.first;
    //     // data reader is available now
    //     final reader = item.dataReader!;
    //     final canProvidePng = reader.canProvide(Formats.png);

    //     if (canProvidePng) {
    //       onDrop?.call();
    //       reader.getFile(Formats.png, (file) async {
    //         final data = await file.readAll();
    //         final xfile = XFile.fromData(
    //           data,
    //           name: file.fileName,
    //           mimeType: 'image/png',
    //           length: data.length,
    //         );
    //         if (data.lengthInBytes == 0) {
    //           // ignore: use_build_context_synchronously
    //           displayInfoBar(context, builder: (ctx, close) {
    //             return InfoBar(
    //               title: Text('File is empty'),
    //               content: Text('File is empty or not supported'),
    //               severity: InfoBarSeverity.error,
    //             );
    //           });
    //           return;
    //         }
    //         log('File dropped: ${xfile.mimeType} ${data.length} bytes');
    //         provider.addAttachmentAiLens(data, showDialog: showAiLens);
    //       }, onError: (error) {
    //         log('Error reading value $error');
    //       });
    //     } else if (reader.platformFormats.first == 'text/csv') {
    //       onDrop?.call();
    //       reader.getFile(Formats.csv, (value) async {
    //         final fileContentBytes = await value.readAll();
    //         final mimeType = mime(value.fileName);
    //         final xfile = XFile.fromData(
    //           fileContentBytes,
    //           name: value.fileName,
    //           mimeType: mimeType,
    //           length: value.fileSize ?? fileContentBytes.length,
    //           path: value.fileName,
    //         );
    //         log('File dropped: ${xfile.mimeType} ${fileContentBytes.length} bytes');
    //         provider.addAttachmentToInput(
    //             Attachment(file: xfile, isInternalScreenshot: false));
    //       }, onError: (error) {
    //         log('Error reading value $error');
    //       });
    //     } else if (reader.canProvide(Formats.plainText)) {
    //       onDrop?.call();
    //       reader.getValue(Formats.plainText, (value) {
    //         if (value != null && value.isNotEmpty) {
    //           final selection = provider.messageController.selection;
    //           final newText = provider.messageController.text.replaceRange(
    //             selection.start,
    //             selection.end,
    //             value,
    //           );
    //           provider.messageController.text = newText;
    //           provider.messageController.selection = TextSelection.collapsed(
    //             offset: selection.start + value.length,
    //           );
    //         }
    //       });
    //     } else {
    //       onDrop?.call();
    //       reader.getFile(null, (value) async {
    //         final fileContentBytes = await value.readAll();
    //         final mimeType = mime(value.fileName);
    //         final xfile = XFile.fromData(
    //           fileContentBytes,
    //           name: value.fileName,
    //           mimeType: mimeType,
    //           length: value.fileSize ?? fileContentBytes.length,
    //           path: value.fileName,
    //         );
    //         log('File dropped: ${xfile.mimeType} ${fileContentBytes.length} bytes');
    //         provider.addAttachmentToInput(
    //             Attachment(file: xfile, isInternalScreenshot: false));
    //       }, onError: (error) {
    //         log('Error reading value $error');
    //       });
    //     }
    //   },
    //   child: const SizedBox.expand(),
    // );
  }
}
