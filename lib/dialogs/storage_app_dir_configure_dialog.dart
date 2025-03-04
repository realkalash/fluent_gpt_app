import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_gpt/common/chat_room.dart';
import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/common/prefs/prefs_types.dart';
import 'package:fluent_gpt/dialogs/prompt_restart_dialog.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/pages/settings_page.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/confirmation_dialog.dart';
import 'package:fluent_gpt/widgets/wiget_constants.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:langchain/langchain.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

class StorageAppDirConfigureDialog extends StatefulWidget {
  const StorageAppDirConfigureDialog({super.key});

  @override
  State<StorageAppDirConfigureDialog> createState() =>
      _StorageAppDirConfigureDialogState();
}

class _StorageAppDirConfigureDialogState
    extends State<StorageAppDirConfigureDialog> {
  final TextEditingController _controller = TextEditingController();
  @override
  initState() {
    super.initState();
    _controller.text = FileUtils.documentDirectoryPath ??
        AppCache.appDocumentsDirectory.value ??
        '';
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Storage directory settings'),
      actions: [
        Button(
          onPressed: () => Navigator.of(context).pop(),
          child:  Text('Dismiss'.tr),
        ),
        FilledButton(
          onPressed: () async {
            final chatProvider = context.read<ChatProvider>();
            if (_controller.text.trim().isNotEmpty) {
              await AppCache.appDocumentsDirectory.set(_controller.text.trim());
            } else {
              await AppCache.appDocumentsDirectory.set('');
            }
            chatProvider.initTimers();
            // ignore: use_build_context_synchronously
            Navigator.of(context).pop();
            await Future.delayed(const Duration(milliseconds: 500));
            await FileUtils.init();
            showDialog(
                context: chatProvider.context!,
                builder: (ctx) => PromptRestartAppDialog());
          },
          child: const Text('Save'),
        ),
      ],
      content: ListView(
        shrinkWrap: true,
        children: [
          LabelText('Choose where to store the app data'),
          TextFormBox(
            controller: _controller,
            suffix: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Button(
                  onPressed: () async {
                    final result = await FilePicker.platform.getDirectoryPath(
                      initialDirectory:
                          AppCache.appDocumentsDirectory.value?.isEmpty == true
                              ? null
                              : AppCache.appDocumentsDirectory.value,
                    );
                    if (result != null) {
                      _controller.text = result;
                    }
                  },
                  child: const Text('Choose'),
                ),
                Button(
                  onPressed: () async {
                    final dir = await getApplicationDocumentsDirectory();
                    _controller.text = dir.path;
                  },
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
          CaptionText(
              'The app will create a folder "fluent_gpt" in the selected directory'),
          LabelText('Fetch data periodically'),
          Row(
            children: [
              Expanded(
                child: Checkbox(
                  content: Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text('Fetch chats every: '),
                      SizedBox(
                        width: 50,
                        child: NumberBox(
                          value: AppCache.fetchChatsPeriodMin.value,
                          mode: SpinButtonPlacementMode.none,
                          clearButton: false,
                          min: 1,
                          placeholder:
                              '${AppCache.fetchChatsPeriodMin.value ?? 10}',
                          onChanged: (value) {
                            AppCache.fetchChatsPeriodMin.value = value ?? 10;
                          },
                        ),
                      ),
                      const Text(' minutes')
                    ],
                  ),
                  checked: AppCache.fetchChatsPeriodically.value,
                  onChanged: (value) {
                    AppCache.fetchChatsPeriodically.value = value;
                    setState(() {});
                  },
                ),
              ),
            ],
          ),
          biggerSpacer,
          LabelText('Export/Import settings'),
          CaptionText(
              'It will export settings like api keys, locale, etc, global system prompt, additional tools, etc. to "fluent_gpt" folder'),
          spacer,
          Wrap(
            spacing: 8,
            children: [
              Button(
                onPressed: () => exportSettings(context),
                child: const Text('Export'),
              ),
              Button(
                onPressed: () => importSettings(context),
                child: const Text('Import'),
              ),
            ],
          ),
          spacer,
          Button(
            onPressed: () => importDeprecatedChats(context),
            child: const Text('Import old chats in deprecated format'),
          ),
        ],
      ),
    );
  }

  Future<void> exportSettings(BuildContext context) async {
    /*   
      static const useGoogleApi = BoolPref("useGoogleApi", false);
  static const useImgurApi = BoolPref("useImgurApi", false);
  static const useSouceNao = BoolPref("useSouceNao", false);
  static const useYandexImageSearch = BoolPref("useYandexImageSearch", false);
   */
    final settingsToExport = AppCache.settingsToExportList;
    final settings = <String, dynamic>{};
    for (final setting in settingsToExport) {
      if (setting is BoolPref) {
        settings[setting.key] = setting.value;
      } else if (setting is StringPref) {
        settings[setting.key] = setting.value;
      } else if (setting is IntPref) {
        settings[setting.key] = setting.value;
      } else if (setting is DoublePref) {
        settings[setting.key] = setting.value;
      }
    }
    final data = jsonEncode(settings);
    final selectedPath = await FilePicker.platform.saveFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
      initialDirectory: FileUtils.documentDirectoryPath,
      fileName: 'fluent_gpt_settings.json',
    );
    if (selectedPath != null) {
      final savedFilePath = await FileUtils.saveFile(selectedPath, data);
      if (savedFilePath != null) {
        displayErrorInfoBar();
      } else {
        displaySuccessInfoBar();
      }
    }
  }

  Future<void> importSettings(BuildContext context) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      initialDirectory: FileUtils.documentDirectoryPath,
    );
    final file = result?.files.single;
    if (file == null) {
      return;
    }
    final settingsFile = File(file.path!);
    if (!settingsFile.existsSync()) {
      return;
    }
    final settings = await settingsFile.readAsString();

    // final settings = await AppCache.exportedGlobalSettings.value();
    if (settings.isEmpty) {
      return;
    }
    final settingsMap = jsonDecode(settings) as Map<String, dynamic>;
    for (final setting in AppCache.settingsToExportList) {
      for (final key in settingsMap.keys) {
        if (setting.key == key) {
          if (setting is BoolPref && setting.key == key) {
            setting.value = settingsMap[key] as bool?;
          } else if (setting is StringPref && setting.key == key) {
            setting.value = settingsMap[key] as String?;
          } else if (setting is IntPref && setting.key == key) {
            setting.value = settingsMap[key] as int?;
          } else if (setting is DoublePref && setting.key == key) {
            setting.value = settingsMap[key] as double?;
          }
        }
      }
    }
    // ignore: use_build_context_synchronously
    PromptRestartAppDialog.show(context);
  }

  Future importDeprecatedChats(BuildContext context) async {
    final confirmed = await ConfirmationDialog.show(
        context: context,
        message:
            'Current chats will be deleted and replaced with the imported ones. Are you sure?');
    if (confirmed) {
      final path = await FileUtils.getChatRoomsPath();
      final chatRoomsFiles = FileUtils.getFilesRecursive(path);

      /// Key is ChatRoom id
      final chats = <String, List<ChatMessage>?>{};
      for (final file in chatRoomsFiles) {
        try {
          await file.readAsString().then((text) {
            final chatRoom = ChatRoom.fromJson(text);
            chats[chatRoom.id] = null;
          });
        } catch (e) {
          logError(e.toString());
        }
      }
      final allChatMessagesFiles = await FileUtils.getAllChatMessagesFiles();
      for (final file in allChatMessagesFiles) {
        try {
          final text = await file.readAsString();
          // ...\fluent_gpt\chat_rooms\xxuuRQT5p7YWbm1u-messages.json
          final fileName = file.path.split(Platform.pathSeparator).last;
          final id = fileName.split('-messages.json').first;
          final messagesRaw = jsonDecode(text) as List<dynamic>;
          final messages = <ChatMessage>[];
          // id is the key
          for (var messageJson in messagesRaw) {
            if (messageJson['creator'] != null){
              continue;
            }
            try {
              final content = messageJson['message'] as Map<String, dynamic>;
              final message = ChatRoom.chatMessageFromJson(content);
              messages.add(message);
            } catch (e) {
              logError('Error while loading message from disk: $e');
            }
          }
          chats[id] = messages;
        } catch (e) {
          logError(e.toString());
        }
      }
      // create a backup of all chats in a new backup folder
      final backupPath = '${await FileUtils.getChatRoomsPath()}-backup';
      final backupDir = Directory(backupPath);
      if (!backupDir.existsSync()) {
        backupDir.createSync();
      }
      for (final file in allChatMessagesFiles) {
        final fileName = file.path.split(Platform.pathSeparator).last;
        await file.copy('$backupPath${Platform.pathSeparator}$fileName');
      }

      // now we need to rewrite all chats from allChatMessagesFiles with a new chats lists
      for (final file in allChatMessagesFiles) {
        try {
          final fileName = file.path.split(Platform.pathSeparator).last;
          final id = fileName.split('-messages.json').first;
          final messages = chats[id];
          if (messages != null) {
            final newMessages = <FluentChatMessage>[];
            for (var message in messages) {
              await Future.delayed(const Duration(milliseconds: 2));
              newMessages.add(FluentChatMessage.fromLangChainChatMessage(message));
            }
            final newMessagesJson = newMessages.map((e) => e.toJson()).toList();
            final newMessagesJsonString = jsonEncode(newMessagesJson);
            await file.writeAsString(newMessagesJsonString);
          }
        } catch (e) {
          logError(e.toString());
        }
      }

      Navigator.maybeOf(navigatorKey.currentContext!);
      await Future.delayed(const Duration(milliseconds: 500));
      PromptRestartAppDialog.show(navigatorKey.currentContext!);
    }
  }
}
