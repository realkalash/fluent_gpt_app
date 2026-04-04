import 'dart:convert';
import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';
import 'package:docx_to_text/docx_to_text.dart';
import 'package:fluent_gpt/common/attachment.dart';
import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/common/excel_to_json.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/dialogs/ai_lens_dialog.dart';
import 'package:fluent_gpt/features/image_util.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/providers/chat_provider_mixins/chat_provider_base_mixin.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_ui/fluent_ui.dart';

/// Inserts `[path:…]` tokens at the current selection (or caret), replacing any selected range.
void _insertPathTokensAtCursorForChat(List<String> paths) {
  if (paths.isEmpty) return;
  final insertion = paths.map((p) => '[path:$p]').join(' ');
  final controller = ChatProvider.messageControllerGlobal;
  final value = controller.value;
  final text = value.text;
  final sel = value.selection;
  final int start;
  final int end;
  if (sel.isValid) {
    var s = sel.start.clamp(0, text.length);
    var e = sel.end.clamp(0, text.length);
    if (s > e) {
      final t = s;
      s = e;
      e = t;
    }
    start = s;
    end = e;
  } else {
    start = end = text.length;
  }
  final newText = text.replaceRange(start, end, insertion);
  final newOffset = start + insertion.length;
  controller.value = TextEditingValue(
    text: newText,
    selection: TextSelection.collapsed(offset: newOffset),
  );
}

mixin ChatProviderAttachmentsMixin on ChangeNotifier, ChatProviderBaseMixin {
  static const Map<String, bool> allowedFileExtensions = {
    'jpg': true,
    'jpeg': true,
    'png': true,
    'docx': true,
    'xlsx': true,
    'txt': true,
    'csv': true,
    'pdf': true,
  };

  @override
  Future<void> addFilesToInput(List<XFile> files,
      {bool clearExisting = true}) async {
    if (clearExisting) {
      fileInputs.clear();
    }
    final nonImagePaths = <String>[];
    for (var file in files) {
      final mime = file.mimeType ??
          await FileUtils.detectFileTypeFromBytes(await file.readAsBytes());
      if (mime?.startsWith('image') == false) {
        nonImagePaths.add(file.path);
        continue;
      }
      final fileExt = file.path.split('.').last;

      if (allowedFileExtensions.containsKey(fileExt) == false) {
        displayErrorInfoBar(
          title: 'Not Supported'.tr,
          message: "File type '$fileExt' is not supported",
        );
        logError('File ${file.path} is not supported');
        continue;
      }
      final attachment = Attachment.fromFile(file);
      fileInputs.add(attachment);
    }
    if (nonImagePaths.isNotEmpty) {
      _insertPathTokensAtCursorForChat(nonImagePaths);
      notifyListeners();
      return;
    }
    notifyListeners();
  }

  void addAttachmentToInput(List<Attachment> attachments) {
    fileInputs.clear();
    fileInputs = attachments;
    notifyListeners();
  }

  Future<void> addAttachmentAiLens(Uint8List bytes,
      {bool showDialog = true}) async {
    final attachment = Attachment.fromInternalScreenshotBytes(bytes);
    addAttachmentToInput([attachment]);
    if (showDialog) {
      final isSent = await AiLensDialog.show<bool?>(context!, bytes);
      if (isSent != true) {
        removeFilesFromInput();
      }
    }
  }

  Future<void> processFilesBeforeSendingMessage() async {
    if (fileInputs.isEmpty) {
      return;
    }

    for (var file in fileInputs) {
      await Future.delayed(const Duration(milliseconds: 10));
      if (file.isImage == true) {
        final bytes = await file.readAsBytes();
        final newBytes = await ImageUtil.resizeAndCompressImage(
          bytes,
          maxHeight: AppCache.imageShrinkerHeight.value!,
          maxWidth: AppCache.imageShrinkerWidth.value!,
          maxSizeInBytes: AppCache.imageShrinkerMaxSizeInBytes.value!,
        );
        final base64 = base64Encode(newBytes);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        addCustomMessageToList(
          FluentChatMessage.image(
            id: '$timestamp',
            content: base64,
            creator: AppCache.userName.value!,
            timestamp: timestamp,
            path: file.path,
            fileName: file.name,
          ),
        );
      } else if (file.isText == true) {
        final fileName = file.name;
        final bytes = await file.readAsBytes();
        final contentString = utf8.decode(bytes);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        addCustomMessageToList(
          FluentChatMessage(
            id: '$timestamp',
            content: contentString,
            creator: AppCache.userName.value!,
            timestamp: timestamp,
            type: FluentChatMessageType.file,
            fileName: fileName,
            path: file.path,
          ),
        );
      } else if (file.isWord == true) {
        final fileName = file.name;
        final bytes = await file.readAsBytes();
        final contentString = docxToText(bytes);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        addCustomMessageToList(
          FluentChatMessage(
            id: '$timestamp',
            content: contentString,
            creator: AppCache.userName.value!,
            timestamp: timestamp,
            type: FluentChatMessageType.file,
            fileName: fileName,
            path: file.path,
          ),
        );
      } else if (file.isExcel == true) {
        final fileName = file.name;
        final bytes = await file.readAsBytes();
        final excelToJson = ExcelToJson();
        final contentString = await excelToJson.convert(bytes);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        addCustomMessageToList(
          FluentChatMessage(
            id: '$timestamp',
            content: contentString ?? '<No data available>',
            creator: AppCache.userName.value!,
            timestamp: timestamp,
            type: FluentChatMessageType.file,
            fileName: fileName,
            path: file.path,
          ),
        );
      } else if (file.isPdf == true) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        addCustomMessageToList(
          FluentChatMessage.file(
            id: '$timestamp',
            creator: AppCache.userName.value!,
            timestamp: timestamp,
            path: file.path,
            fileName: file.name,
            tokens: 256,
            content:
                'Uploaded file: "${file.path}". Analyse it before the answer',
          ),
        );
      }
    }
    if (fileInputs.isNotEmpty) {
      // wait for the file to be populated. Otherwise addHumanMessage can be sent before the file is populated
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  @override
  void removeFilesFromInput() {
    for (var file in fileInputs) {
      if (file.isInternalScreenshot == true) {
        FileUtils.deleteFile(file.path);
      }
    }
    fileInputs.clear();
    notifyListeners();
  }

  void removeAttachmentFromInput(Attachment attachment) {
    if (fileInputs.isEmpty) return;

    // Delete internal screenshot files if needed
    if (attachment.isInternalScreenshot) {
      FileUtils.deleteFile(attachment.path);
    }

    final index = fileInputs.indexOf(attachment);
    if (index != -1) {
      fileInputs.removeAt(index);
    }

    // If list is empty, set to null
    if (fileInputs.isEmpty) {
      fileInputs.clear();
    }

    notifyListeners();
  }

  Future<void> sendAllAttachmentsToChatSilently() async {
    if (fileInputs.isEmpty) return;
    await processFilesBeforeSendingMessage();
    removeFilesFromInput();
  }
}
