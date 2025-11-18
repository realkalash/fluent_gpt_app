import 'dart:async';
import 'dart:io';

import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
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
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document': true,
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
  StreamSubscription<List<String>>? subscription;
  ChatProvider? provider;
  @override
  void initState() {
    super.initState();
    isDraggingOver = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (Platform.isWindows)
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
          final listXFiles = <XFile>[];
          for (final path in paths) {
            final name = path.split('\\').last;
            final mimeType = mime(name);
            final mimeCategory = mimeType?.split('/').first;
            if (HomeDropRegion.allowedFormats[mimeType] != true) {
              isDropOverlayVisible.add(DropOverlayState.dropInvalidFormat);
              displayErrorInfoBar(title: 'Invalid format', message: mimeType);
              await Future.delayed(const Duration(milliseconds: 1000));
              isDropOverlayVisible.add(DropOverlayState.none);
              continue;
            }
            if (mimeCategory == 'image' && selectedModel.imageSupported == false) {
              displayErrorInfoBar(title: 'Invalid format', message: 'This model does not support images');
              continue;
            }
            final file = XFile(path, name: name, mimeType: mimeType);
            log('File dropped: ${file.mimeType} ${await file.length()} bytes');
            listXFiles.add(file);
          }
          provider!.addFilesToInput(listXFiles, clearExisting: false);
          listXFiles.clear();
        });
    });
  }

  @override
  void dispose() {
    subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand();
  }
}
