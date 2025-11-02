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
import 'package:fluent_gpt/providers/chat_provider_mixins/chat_provider_base_mixin.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_ui/fluent_ui.dart';

mixin ChatProviderAttachmentsMixin on ChangeNotifier, ChatProviderBaseMixin {
  List<Attachment>? fileInputs;
  bool isSendingFiles = false;
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

  void addFilesToInput(List<XFile> files) {
    fileInputs?.clear();
    fileInputs ??= <Attachment>[];
    for (var file in files) {
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
      fileInputs?.add(attachment);
    }
    notifyListeners();
  }

  void addAttachmentToInput(List<Attachment> attachments) {
    fileInputs?.clear();
    fileInputs = attachments;
    notifyListeners();
  }

  Future<void> addAttachmentAiLens(Uint8List bytes, {bool showDialog = true}) async {
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
    if (fileInputs == null || fileInputs!.isEmpty) {
      return;
    }

    for (var file in fileInputs!) {
      await Future.delayed(const Duration(milliseconds: 10));
      if (file.isImage == true) {
        final bytes = await file.readAsBytes();
        final newBytes = await ImageUtil.resizeAndCompressImage(bytes);
        final base64 = base64Encode(newBytes);
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        addCustomMessageToList(
          FluentChatMessage.image(
            id: '$timestamp',
            content: base64,
            creator: AppCache.userName.value!,
            timestamp: timestamp,
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
            content: 'Uploaded file: "${file.path}". Analyse it before the answer',
          ),
        );
      }
    }
    if (fileInputs != null) {
      // wait for the file to be populated. Otherwise addHumanMessage can be sent before the file is populated
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  void removeFilesFromInput() {
    for (var file in fileInputs ?? <Attachment>[]) {
      if (file.isInternalScreenshot == true) {
        FileUtils.deleteFile(file.path);
      }
    }
    fileInputs = null;
    notifyListeners();
  }

  Future<void> sendAllAttachmentsToChatSilently() async {
    if (fileInputs == null || fileInputs!.isEmpty) return;
    await processFilesBeforeSendingMessage();
    removeFilesFromInput();
  }
}

