// import 'package:fluent_gpt/common/attachment.dart';
// import 'package:fluent_gpt/log.dart';
// import 'package:fluent_gpt/pages/home_page.dart';
// import 'package:fluent_gpt/providers/chat_provider.dart';
// import 'package:cross_file/cross_file.dart';
// import 'package:fluent_ui/fluent_ui.dart';
// import 'package:mime_type/mime_type.dart';
// import 'package:provider/provider.dart';
// import 'package:super_drag_and_drop/super_drag_and_drop.dart';

// class HomeDropRegion extends StatelessWidget {
//   const HomeDropRegion({super.key, this.onDrop, this.showAiLens = true});
//   final VoidCallback? onDrop;
//   final bool showAiLens;
//   static const allowedFormats = {
//     'text/plain': true,
//     'text/csv': true,
//     'text/html': true,
//     'PNG': true,
//     // TODO: we need to add support for .doc, .xls files
//     // 'application/msword': true,
//     // 'application/vnd.ms-excel': true,
//     // word
//     'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
//         true,
//     // excel
//     'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet': true,
//     'text/_moz_htmlcontext': true,
//     'text/_moz_htmlinfo': true,
//     'application/octet-stream;extension=url': true,
//   };

//   @override
//   Widget build(BuildContext context) {
//     final provider = context.read<ChatProvider>();
//     return DropRegion(
//       // Formats this region can accept.
//       formats: Formats.standardFormats,
//       hitTestBehavior: HitTestBehavior.translucent,
//       onDropOver: (event) {
//         // This drop region only supports copy operation.
//         if (event.session.items.first.platformFormats.first.contains('image')) {
//           return DropOperation.copy;
//         } else if (event.session.items.first.platformFormats.first ==
//             'text/plain') {
//           return DropOperation.copy;
//         }
//         return DropOperation.copy;
//       },
//       onDropEnter: (event) {
//         // This is called when region first accepts a drag
//         for (final format in event.session.items.first.platformFormats) {
//           if (allowedFormats.containsKey(format)) {
//             isDropOverlayVisible.add(DropOverlayState.dropOver);
//             return;
//           }
//         }

//         isDropOverlayVisible.add(DropOverlayState.dropInvalidFormat);
//         log('Invalid format: ${event.session.items.first.platformFormats.first}');
//         displayInfoBar(context, builder: (ctx, close) {
//           return InfoBar(
//             title: Text('Invalid format'),
//             content: Text(event.session.items.first.platformFormats.first),
//             severity: InfoBarSeverity.error,
//           );
//         });
//       },
//       onDropLeave: (event) {
//         // Called when drag leaves the region. Will also be called after
//         // drag completion.
//         // This is a good place to remove any visual indicators.
//         isDropOverlayVisible.add(DropOverlayState.none);
//       },
//       onPerformDrop: (event) async {
//         // Called when user dropped the item. You can now request the data.
//         // Note that data must be requested before the performDrop callback
//         // is over.
//         final item = event.session.items.first;
//         // data reader is available now
//         final reader = item.dataReader!;
//         final canProvidePng = reader.canProvide(Formats.png);

//         if (canProvidePng) {
//           onDrop?.call();
//           reader.getFile(Formats.png, (file) async {
//             final data = await file.readAll();
//             final xfile = XFile.fromData(
//               data,
//               name: file.fileName,
//               mimeType: 'image/png',
//               length: data.length,
//             );
//             if (data.lengthInBytes == 0) {
//               // ignore: use_build_context_synchronously
//               displayInfoBar(context, builder: (ctx, close) {
//                 return InfoBar(
//                   title: Text('File is empty'),
//                   content: Text('File is empty or not supported'),
//                   severity: InfoBarSeverity.error,
//                 );
//               });
//               return;
//             }
//             log('File dropped: ${xfile.mimeType} ${data.length} bytes');
//             provider.addAttachmentAiLens(data, showDialog: showAiLens);
//           }, onError: (error) {
//             log('Error reading value $error');
//           });
//         } else if (reader.platformFormats.first == 'text/csv') {
//           onDrop?.call();
//           reader.getFile(Formats.csv, (value) async {
//             final fileContentBytes = await value.readAll();
//             final mimeType = mime(value.fileName);
//             final xfile = XFile.fromData(
//               fileContentBytes,
//               name: value.fileName,
//               mimeType: mimeType,
//               length: value.fileSize ?? fileContentBytes.length,
//               path: value.fileName,
//             );
//             log('File dropped: ${xfile.mimeType} ${fileContentBytes.length} bytes');
//             provider.addAttachmentToInput(
//                 Attachment(file: xfile, isInternalScreenshot: false));
//           }, onError: (error) {
//             log('Error reading value $error');
//           });
//         } else if (reader.canProvide(Formats.plainText)) {
//           onDrop?.call();
//           reader.getValue(Formats.plainText, (value) {
//             if (value != null && value.isNotEmpty) {
//               final selection = provider.messageController.selection;
//               final newText = provider.messageController.text.replaceRange(
//                 selection.start,
//                 selection.end,
//                 value,
//               );
//               provider.messageController.text = newText;
//               provider.messageController.selection = TextSelection.collapsed(
//                 offset: selection.start + value.length,
//               );
//             }
//           });
//         } else {
//           onDrop?.call();
//           reader.getFile(null, (value) async {
//             final fileContentBytes = await value.readAll();
//             final mimeType = mime(value.fileName);
//             final xfile = XFile.fromData(
//               fileContentBytes,
//               name: value.fileName,
//               mimeType: mimeType,
//               length: value.fileSize ?? fileContentBytes.length,
//               path: value.fileName,
//             );
//             log('File dropped: ${xfile.mimeType} ${fileContentBytes.length} bytes');
//             provider.addAttachmentToInput(
//                 Attachment(file: xfile, isInternalScreenshot: false));
//           }, onError: (error) {
//             log('Error reading value $error');
//           });
//         }
//       },
//       child: const SizedBox.expand(),
//     );
//   }
// }
