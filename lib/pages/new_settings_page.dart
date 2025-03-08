import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:fluent_gpt/cities_list.dart';
import 'package:fluent_gpt/common/custom_prompt.dart';
import 'package:fluent_gpt/common/enums.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/dialogs/ai_prompts_library_dialog.dart';
import 'package:fluent_gpt/dialogs/custom_action_dialog.dart';
import 'package:fluent_gpt/dialogs/global_system_prompt_sample_dialog.dart';
import 'package:fluent_gpt/dialogs/info_about_user_dialog.dart';
import 'package:fluent_gpt/dialogs/microphone_settings_dialog.dart';
import 'package:fluent_gpt/dialogs/storage_app_dir_configure_dialog.dart';
import 'package:fluent_gpt/features/annoy_feature.dart';
import 'package:fluent_gpt/features/azure_speech.dart';
import 'package:fluent_gpt/features/deepgram_speech.dart';
import 'package:fluent_gpt/features/elevenlabs_speech.dart';
import 'package:fluent_gpt/features/image_generator_feature.dart';
import 'package:fluent_gpt/features/imgur_integration.dart';
import 'package:fluent_gpt/features/notification_service.dart';
import 'package:fluent_gpt/file_utils.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/native_channels.dart';
import 'package:fluent_gpt/navigation_provider.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/pages/about_page.dart';
import 'package:fluent_gpt/pages/prompts_settings_page.dart';
import 'package:fluent_gpt/pages/welcome/welcome_shortcuts_helper_screen.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/shell_driver.dart';
import 'package:fluent_gpt/system_messages.dart';
import 'package:fluent_gpt/theme.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/confirmation_dialog.dart';
import 'package:fluent_gpt/widgets/custom_buttons.dart';
import 'package:fluent_gpt/widgets/custom_list_tile.dart';
import 'package:fluent_gpt/widgets/keybinding_dialog.dart';
import 'package:fluent_gpt/widgets/markdown_builders/code_wrapper.dart';
import 'package:fluent_gpt/widgets/text_link.dart';
import 'package:fluent_gpt/widgets/wiget_constants.dart';
import 'package:fluent_gpt/widgets/zoom_hover.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/foundation.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_info2/system_info2.dart';
import 'package:window_manager/window_manager.dart';

import 'settings_page.dart';

class NewSettingsPage extends StatefulWidget {
  const NewSettingsPage({super.key, this.initialIndex});
  final int? initialIndex;
  static int generalIndex = 0;
  static int appearanceIndex = 1;
  static int toolsIndex = 2;
  static int userInfoIndex = 3;
  static int apiUrlsIndex = 4;
  static int onResponseEndIndex = 5;
  static int quickPromptsIndex = 6;
  static int permissionsIndex = 7;
  static int overlayIndex = 8;
  static int storageIndex = 9;
  static int hotkeysIndex = 10;

  @override
  State<NewSettingsPage> createState() => _NewSettingsPageState();
}

class _NewSettingsPageState extends State<NewSettingsPage> {
  int selectedIndex = 0;
  late final StreamSubscription<Map<String, String?>> suscr;
  @override
  void initState() {
    super.initState();
    selectedIndex = widget.initialIndex ?? NewSettingsPage.generalIndex;
    suscr = I18n.currentLocalizationStream.listen((event) {
      setState(() {});
    });
  }

  @override
  void dispose() {
    suscr.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return NavigationView(
      appBar: NavigationAppBar(
        title: GestureDetector(
            onPanUpdate: (details) {
              windowManager.startDragging();
            },
            child: Text('Settings'.tr)),
      ),
      pane: NavigationPane(
        displayMode: PaneDisplayMode.open,
        size: NavigationPaneSize(openMaxWidth: 200),
        selected: selectedIndex,
        onChanged: (value) {
          setState(() {
            selectedIndex = value;
          });
        },
        items: [
          PaneItem(
            title: Text('General'.tr),
            body: GeneralSettingsPage(),
            icon: Icon(FluentIcons.settings_32_filled, color: Colors.blue),
          ),
          PaneItem(
            title: Text('Appearance'.tr),
            body: AppearanceSettings(),
            icon: Icon(FluentIcons.paint_bucket_24_filled, color: Colors.teal),
          ),
          PaneItem(
            title: Text('Tools'.tr),
            body: ToolsSettings(),
            icon: Icon(FluentIcons.toolbox_24_filled, color: Colors.green),
          ),
          PaneItem(
            title: Text('User info'.tr),
            body: UserSettignsInfoPage(),
            icon: Icon(FluentIcons.person_32_filled, color: Colors.magenta),
          ),
          PaneItem(
            title: Text('API and URLs'.tr),
            body: APIandUrlsSettingsPage(),
            icon: Icon(FluentIcons.apps_add_in_24_filled, color: Colors.yellow),
          ),
          PaneItem(
            title: Text('On response'.tr),
            body: OnResponseEndSettingsPage(),
            icon: Icon(
              FluentIcons.chat_32_filled,
              color: Color.fromARGB(255, 43, 226, 202),
            ),
          ),
          PaneItem(
            title: Text('Quick prompts'.tr),
            body: QuickPromptsSettingsPage(),
            icon: Icon(FluentIcons.book_toolbox_24_filled,
                color: Color.fromARGB(255, 55, 43, 226)),
          ),
          if (Platform.isMacOS)
            PaneItem(
              title: Text('Permissions'.tr),
              body: PermissionsSettingsPage(),
              icon:
                  Icon(FluentIcons.lock_closed_32_filled, color: Colors.green),
            ),
          PaneItem(
            title: Text('Overlay'.tr),
            body: OverlaySettingsPage(),
            icon: Icon(FluentIcons.oven_32_filled, color: Colors.orange),
          ),
          PaneItem(
            title: Text('Storage'.tr),
            body: StorageSettingsPage(),
            icon: Icon(FluentIcons.storage_32_filled, color: Color(0xFF8A2BE2)),
          ),
          PaneItem(
            title: Text('Hotkeys'.tr),
            body: HotkeysSettingsPage(),
            icon: Icon(
              FluentIcons.key_command_24_filled,
              color: Color.fromARGB(255, 226, 43, 144),
            ),
          ),
          if (kDebugMode)
            PaneItem(
              title: Text('Debug'),
              body: DebugPage(),
              icon: Icon(FluentIcons.accessibility_32_filled,
                  color: Colors.green),
            ),
          PaneItem(
            title: Text('About'.tr),
            body: AboutPage(),
            icon: Icon(FluentIcons.info_32_filled, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class HotkeysSettingsPage extends StatefulWidget {
  const HotkeysSettingsPage({super.key});

  @override
  State<HotkeysSettingsPage> createState() => _HotkeysSettingsPageState();
}

class _HotkeysSettingsPageState extends State<HotkeysSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: FluentTheme.of(context).inactiveBackgroundColor,
      child: ScaffoldPage.scrollable(children: [
        Button(
          onPressed: () async {
            final key = await KeybindingDialog.show(
              context,
              initHotkey: openWindowHotkey,
              title: Text('Open the window keybinding'.tr),
            );
            if (key != null && key != openWindowHotkey) {
              setState(() {
                openWindowHotkey = key;
              });
              await AppCache.openWindowKey.set(jsonEncode(key.toJson()));
              initShortcuts();
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Open the window'.tr),
              const SizedBox(width: 10.0),
              HotKeyVirtualView(hotKey: openWindowHotkey),
            ],
          ),
        ),
        spacer,
        Button(
          onPressed: () async {
            final key = await KeybindingDialog.show(
              context,
              initHotkey: takeScreenshot,
              title: Text('Take a screenshot keybinding'.tr),
            );
            final wasRegistered = HotKeyManager.instance.registeredHotKeyList
                .any((element) => element == key);
            if (key != null && key != takeScreenshot) {
              setState(() {
                takeScreenshot = key;
              });
              if (wasRegistered) {
                await HotKeyManager.instance.unregister(key);
              }
              await AppCache.takeScreenshotKey.set(jsonEncode(key.toJson()));
              initShortcuts();
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Use visual AI'.tr),
              const SizedBox(width: 10.0),
              if (takeScreenshot != null)
                HotKeyVirtualView(hotKey: takeScreenshot!)
              else
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Text('[Not set]'.tr),
                ),
            ],
          ),
        ),
        spacer,
        Button(
          onPressed: () async {
            final key = await KeybindingDialog.show(
              context,
              initHotkey: pttScreenshotKey,
              title: Text('Push-to-talk with screenshot'.tr),
            );
            final wasRegistered = HotKeyManager.instance.registeredHotKeyList
                .any((element) => element == key);
            if (key != null && key != pttScreenshotKey) {
              setState(() {
                pttScreenshotKey = key;
              });
              if (wasRegistered) {
                await HotKeyManager.instance.unregister(key);
              }
              await AppCache.pttScreenshotKey.set(jsonEncode(key.toJson()));
              initShortcuts();
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Push-to-talk with screenshot'.tr),
              const SizedBox(width: 10.0),
              if (pttScreenshotKey != null)
                HotKeyVirtualView(hotKey: pttScreenshotKey!)
              else
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Text('[Not set]'.tr),
                ),
            ],
          ),
        ),
        spacer,
        Button(
          onPressed: () async {
            final key = await KeybindingDialog.show(
              context,
              initHotkey: pttKey,
              title: Text('Push-to-talk'.tr),
            );
            final wasRegistered = HotKeyManager.instance.registeredHotKeyList
                .any((element) => element == key);
            if (key != null && key != pttKey) {
              setState(() {
                pttKey = key;
              });
              if (wasRegistered) {
                await HotKeyManager.instance.unregister(key);
              }
              await AppCache.pttKey.set(jsonEncode(key.toJson()));
              initShortcuts();
            }
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Push-to-talk'.tr),
              const SizedBox(width: 10.0),
              if (pttKey != null)
                HotKeyVirtualView(hotKey: pttKey!)
              else
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: Text('[Not set]'.tr),
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Divider(),
        ),
        Button(
            child: Text('Show all keybindings'.tr),
            onPressed: () {
              Navigator.of(context).push(FluentPageRoute(
                  builder: (context) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            alignment: AlignmentDirectional.centerStart,
                            padding: const EdgeInsets.all(4.0),
                            color: context.theme.cardColor,
                            child: GestureDetector(
                              onTap: () {
                                Navigator.of(context).pop();
                              },
                              child: const SmallIconButton(
                                child: Icon(FluentIcons.arrow_left_20_filled),
                              ),
                            ),
                          ),
                          const Expanded(child: WelcomeShortcutsHelper()),
                        ],
                      )));
            }),
      ]),
    );
  }
}

class StorageSettingsPage extends StatelessWidget {
  const StorageSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: FluentTheme.of(context).inactiveBackgroundColor,
      child: ScaffoldPage.scrollable(children: [
        Button(
            child: Text('Application storage location'.tr),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => const StorageAppDirConfigureDialog(),
              );
            }),
        spacer,
        Button(
            child: Text('Delete all chat rooms'.tr),
            onPressed: () => ConfirmationDialog(
                  isDelete: true,
                  onAcceptPressed: () {
                    context.read<ChatProvider>().deleteAllChatRooms();
                  },
                )),
        spacer,
        Button(
            child: Text('Delete temp cache'.tr),
            onPressed: () async {
              final sizeBytes = await FileUtils.calculateSizeRecursive(
                  FileUtils.appTemporaryDirectoryPath!);
              final sizeMb = sizeBytes == 0 ? 0 : sizeBytes / 1024 / 1024;
              ConfirmationDialog.show(
                // ignore: use_build_context_synchronously
                context: context,
                isDelete: true,
                message:
                    '${'Delete temp cache? Size:'.tr} ${sizeMb.toStringAsFixed(2)} MB',
                onAcceptPressed: () async {
                  ShellDriver.deleteAllTempFiles();
                  AppCache.costTotal.value = 0.0;
                  AppCache.tokensUsedTotal.value = 0;
                  final dir = Directory(FileUtils.appTemporaryDirectoryPath!);
                  if (dir.existsSync()) {
                    await dir.delete(recursive: true);
                    log('${dir.path} deleted');
                  }
                },
              );
            }),
        spacer,
        spacer,
        FilledRedButton(
            child: Text('Clear all data'.tr),
            onPressed: () async {
              final navProvider = context.read<NavigationProvider>();
              final res = await ConfirmationDialog.show(context: context);
              if (!res) return;

              prefs = await SharedPreferences.getInstance();
              await ShellDriver.deleteAllTempFiles();
              await prefs!.clear();
              // ignore: use_build_context_synchronously
              navProvider.welcomeScreenPageController =
                  PageController(keepPage: false);
              navProvider.updateUI();
              // ignore: use_build_context_synchronously
              final navigator = Navigator.of(context);
              if (navigator.canPop()) {
                navigator.pop();
              }
            }),
      ]),
    );
  }
}

class OverlaySettingsPage extends StatefulWidget {
  const OverlaySettingsPage({super.key});

  @override
  State<OverlaySettingsPage> createState() => _OverlaySettingsPageState();
}

class _OverlaySettingsPageState extends State<OverlaySettingsPage> {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: FluentTheme.of(context).inactiveBackgroundColor,
      child: ScaffoldPage.scrollable(children: [
        Text('Overlay settings'.tr,
            style: FluentTheme.of(context).typography.subtitle),
        CheckBoxTile(
          isChecked: AppCache.enableOverlay.value!,
          onChanged: (value) {
            setState(() {
              AppCache.enableOverlay.value = value;
            });
            Provider.of<AppTheme>(context, listen: false).updateUI();
          },
          child: Text('Enable overlay'.tr),
        ),
        CheckBoxTile(
          isChecked: AppCache.showSettingsInOverlay.value!,
          onChanged: (value) {
            setState(() {
              AppCache.showSettingsInOverlay.value = value;
            });
          },
          child: Text('Show settings icon in overlay'.tr),
        ),
        spacer,
        NumberBox(
          value: AppCache.overlayVisibleElements.value == -1
              ? null
              : AppCache.overlayVisibleElements.value,
          placeholder: AppCache.overlayVisibleElements.value == -1
              ? 'Adaptive'.tr
              : null,
          onChanged: (value) {
            AppCache.overlayVisibleElements.value = value ?? -1;
          },
          min: 4,
          mode: SpinButtonPlacementMode.inline,
        ),
      ]),
    );
  }
}

class QuickPromptsSettingsPage extends StatefulWidget {
  const QuickPromptsSettingsPage({super.key});

  @override
  State<QuickPromptsSettingsPage> createState() =>
      _QuickPromptsSettingsPageState();
}

class _QuickPromptsSettingsPageState extends State<QuickPromptsSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
        color: FluentTheme.of(context).inactiveBackgroundColor,
        child: ScaffoldPage(
          content: CustomPromptsSettingsContainer(),
        ));
  }
}

class OnResponseEndSettingsPage extends StatefulWidget {
  const OnResponseEndSettingsPage({super.key});

  @override
  State<OnResponseEndSettingsPage> createState() =>
      _OnResponseEndSettingsPageState();
}

class _OnResponseEndSettingsPageState extends State<OnResponseEndSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: FluentTheme.of(context).inactiveBackgroundColor,
      child: ScaffoldPage.scrollable(children: [
        Card(
          padding: EdgeInsets.zero,
          child: BasicListTile(
            padding: const EdgeInsets.all(8.0),
            title: Text('Show suggestions after ai response'.tr),
            leading: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Checkbox(
                checked: AppCache.enableQuestionHelpers.value == true,
                onChanged: (v) {
                  setState(() {
                    AppCache.enableQuestionHelpers.value = v;
                  });
                },
              ),
            ),
            trailing: Tooltip(
              richMessage: WidgetSpan(
                child: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                          'Will ask AI to produce buttons for each response. It will consume additional tokens in order to generate suggestions'
                              .tr),
                      const SizedBox(height: 10),
                      Image.asset('assets/im_suggestions_tip.png', width: 400),
                    ],
                  ),
                ),
              ),
              child: Icon(FluentIcons.question_circle_20_regular),
            ),
            onTap: () {
              setState(() {
                AppCache.enableQuestionHelpers.value =
                    !(AppCache.enableQuestionHelpers.value ?? false);
              });
            },
          ),
        ),
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: 200.0),
          child: StreamBuilder(
            stream: onMessageActions.stream,
            builder: (ctx, list) => ListView.builder(
              itemCount: list.data?.length ?? 0,
              itemBuilder: (ctx, index) {
                final action = onMessageActions.value[index];
                return Card(
                  padding: EdgeInsets.zero,
                  child: BasicListTile(
                    leading: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Checkbox(
                          checked: action.isEnabled,
                          onChanged: (v) {
                            final edited = action.copyWith(isEnabled: v);
                            final actions = onMessageActions.value;
                            actions[index] = edited;
                            onMessageActions.add(actions);
                            final json =
                                actions.map((e) => e.toJson()).toList();
                            AppCache.customActions.set(jsonEncode(json));
                          }),
                    ),
                    title: Text(action.actionName),
                    padding: const EdgeInsets.all(8.0),
                    onTap: () => showDialog(
                      context: context,
                      builder: (ctx) => CustomActionDialog(action: action),
                    ),
                    trailing: IconButton(
                      icon: const Icon(FluentIcons.delete_20_filled),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => ConfirmationDialog(
                            isDelete: true,
                            onAcceptPressed: () {
                              final actions = onMessageActions.value;
                              actions.removeAt(index);
                              onMessageActions.add(actions);
                              final json =
                                  actions.map((e) => e.toJson()).toList();
                              AppCache.customActions.set(jsonEncode(json));
                            },
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        Button(
          child: Text('Add custom action'.tr),
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => const CustomActionDialog(),
            );
          },
        ),
      ]),
    );
  }
}

class APIandUrlsSettingsPage extends StatefulWidget {
  const APIandUrlsSettingsPage({super.key});

  @override
  State<APIandUrlsSettingsPage> createState() => _APIandUrlsSettingsPageState();
}

class _APIandUrlsSettingsPageState extends State<APIandUrlsSettingsPage> {
  bool obscureBraveText = true;
  bool obscureOpenAiText = true;
  bool obscureimageApi = true;
  final apiKeyTextController =
      TextEditingController(text: AppCache.imageGeneratorApiKey.value);
  final imageModelTextController =
      TextEditingController(text: AppCache.imageGeneratorModel.value);
  @override
  void dispose() {
    apiKeyTextController.dispose();
    imageModelTextController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: FluentTheme.of(context).inactiveBackgroundColor,
      child: ScaffoldPage.scrollable(children: [
        Text(
          'Brave API key (search engine) \$'.tr,
          style: FluentTheme.of(context).typography.subtitle,
        ),
        TextFormBox(
          initialValue: AppCache.braveSearchApiKey.value,
          placeholder: AppCache.braveSearchApiKey.value,
          obscureText: obscureBraveText,
          suffix: IconButton(
            icon: const Icon(FluentIcons.eye_20_regular),
            onPressed: () {
              setState(() {
                obscureBraveText = !obscureBraveText;
              });
            },
          ),
          onChanged: (value) {
            AppCache.braveSearchApiKey.value = value;
          },
        ),
        const Align(
          alignment: Alignment.centerLeft,
          child: LinkTextButton(
            'https://api.search.brave.com/app/keys',
            url: 'https://api.search.brave.com/app/keys',
          ),
        ),
        spacer,
        DropDownButton(
          items: [
            for (var serv in TextToSpeechServiceEnum.values)
              MenuFlyoutItem(
                selected: AppCache.textToSpeechService.value == serv.name,
                onPressed: () {
                  AppCache.textToSpeechService.value = serv.name;
                  setState(() {});
                },
                text: Text(serv.name),
              ),
          ],
          title: Text(
              '${'Text-to-Speech service:'.tr} ${AppCache.textToSpeechService.value}'),
        ),
        if (AppCache.textToSpeechService.value ==
            TextToSpeechServiceEnum.deepgram.name)
          _DeepgramSettings()
        else if (AppCache.textToSpeechService.value ==
            TextToSpeechServiceEnum.azure.name)
          _AzureSettings()
        else if (AppCache.textToSpeechService.value ==
            TextToSpeechServiceEnum.elevenlabs.name)
          _ElevenLabsSettings(),
        spacer,
        LabelText('Image generator'.tr),
        DropDownButton(
          items: [
            for (var gen in ImageGeneratorEnum.values)
              MenuFlyoutItem(
                selected: ImageGeneratorFeature.selectedGenerator == gen,
                onPressed: () async {
                  await ImageGeneratorFeature.setGenerator(gen);
                  setState(() {});
                },
                text: Text(gen.name.tr),
              ),
          ],
          title: Text(ImageGeneratorFeature.selectedGenerator.name.tr),
        ),
        if (ImageGeneratorFeature.selectedGenerator ==
            ImageGeneratorEnum.deepinfraGenerator)
          LinkTextButton('https://deepinfra.com/dash/deployments'),
        spacer,
        TextBox(
          controller: apiKeyTextController,
          placeholder: 'API key for image generator'.tr,
          minLines: 1,
          maxLines: 1,
          obscureText: obscureimageApi,
          suffix: IconButton(
            icon: const Icon(FluentIcons.eye_20_regular),
            onPressed: () {
              setState(() {
                obscureimageApi = !obscureimageApi;
              });
            },
          ),
          onChanged: (value) {
            if (value.isEmpty) return;
            AppCache.imageGeneratorApiKey.value = value;
           },
        ),
        TextBox(
          controller: imageModelTextController,
          placeholder: 'Model'.tr,
          minLines: 1,
          maxLines: 1,
          onChanged: (value) {
            if (value.isEmpty) return;
            AppCache.imageGeneratorModel.value = value;
          },
        ),
        spacer,
        CaptionText('Resolution'.tr),
        DropDownButton(
          items: [
            MenuFlyoutItem(
              selected: AppCache.imageGeneratorSize.value == '768x1366',
              onPressed: () async {
                AppCache.imageGeneratorSize.value = '768x1366';
                setState(() {});
              },
              text: Text('768x1366'),
            ),
            MenuFlyoutItem(
              selected: AppCache.imageGeneratorSize.value == '1366x768',
              onPressed: () async {
                AppCache.imageGeneratorSize.value = '1366x768';
                setState(() {});
              },
              text: Text('1366x768'),
            ),
            MenuFlyoutItem(
              selected: AppCache.imageGeneratorSize.value == '1024x1024',
              onPressed: () async {
                AppCache.imageGeneratorSize.value = '1024x1024';
                setState(() {});
              },
              text: Text('1024x1024'),
            ),
            MenuFlyoutItem(
              selected: AppCache.imageGeneratorSize.value == '512x512',
              onPressed: () async {
                AppCache.imageGeneratorSize.value = '512x512';
                setState(() {});
              },
              text: Text('512x512'),
            ),
            MenuFlyoutItem(
              selected: AppCache.imageGeneratorSize.value == '768x768',
              onPressed: () async {
                AppCache.imageGeneratorSize.value = '768x768';
                setState(() {});
              },
              text: Text('768x768'),
            ),
          ],
          title: Text(AppCache.imageGeneratorSize.value ?? '-'),
        ),
      ]),
    );
  }
}

const supportedLocales = [
  Locale('en'),
  Locale('ru'),
  Locale('es'),
];

class GeneralSettingsPage extends StatefulWidget {
  const GeneralSettingsPage({super.key});

  @override
  State<GeneralSettingsPage> createState() => _GeneralSettingsPageState();
}

class _GeneralSettingsPageState extends State<GeneralSettingsPage> {
  final systemPromptController = TextEditingController();
  final cities = CitiesList.getAllCitiesList();
  @override
  void initState() {
    super.initState();
    systemPromptController.text = AppCache.globalSystemPrompt.value!;
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = context.read<AppTheme>();
    final currentLocale = appTheme.locale;
    return ColoredBox(
      color: FluentTheme.of(context).inactiveBackgroundColor,
      child: ScaffoldPage.scrollable(children: [
        LabelText('Global system prompt'.tr),
        TextFormBox(
          placeholder: 'Global system prompt'.tr,
          controller: systemPromptController,
          minLines: 1,
          maxLines: 50,
          suffix: AiLibraryButton(onPressed: () async {
            final prompt = await showDialog<CustomPrompt?>(
              context: context,
              builder: (ctx) => const AiPromptsLibraryDialog(),
              barrierDismissible: true,
            );
            if (prompt != null) {
              AppCache.globalSystemPrompt.value = prompt.prompt;
              systemPromptController.text = prompt.prompt;
              defaultGlobalSystemMessage = prompt.prompt;
            }
          }),
          onChanged: (value) {
            AppCache.globalSystemPrompt.value = value;
            defaultGlobalSystemMessage = value;
          },
        ),
        CaptionText(
          'Customizable Global system prompt will be used for all NEW chats. To check the whole system prompt press button below'
              .tr,
        ),
        spacer,
        Button(
          child: Text('Click here to check the whole system prompt'.tr),
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => const GlobalSystemPromptSampleDialog(),
              barrierDismissible: true,
            );
          },
        ),
        spacer,
        CheckBoxTooltip(
          content: Text('Use ai to name chat'.tr),
          tooltip: 'Can cause additional charges!'.tr,
          checked: AppCache.useAiToNameChat.value,
          onChanged: (value) {
            AppCache.useAiToNameChat.value = value;
            setState(() {});
          },
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Divider(),
        ),
        Card(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('OS: ${SysInfo.operatingSystemName}'),
            Text('Cores: ${SysInfo.cores.length}'),
            Text('Architecture: ${SysInfo.rawKernelArchitecture}'),
            Text('KernelName: ${SysInfo.kernelName}'),
            Text('OS version: ${SysInfo.kernelVersion}'),
            Text('User directory: ${SysInfo.userDirectory}'),
            Text('User system id: ${SysInfo.userId}'),
            Text('User name in OS: ${SysInfo.userName}'),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Divider(),
        ),
        Button(
            child: Text('Audio and Microphone'.tr),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => const MicrophoneSettingsDialog(),
              );
            }),

        /// dropdown to switch languages
        Text('Locale'.tr, style: FluentTheme.of(context).typography.subtitle),
        spacer,
        Wrap(
          spacing: 15.0,
          runSpacing: 10.0,
          children: List.generate(
            supportedLocales.length,
            (index) {
              final locale = supportedLocales[index];
              return RadioButton(
                checked: currentLocale == locale,
                onChanged: (value) {
                  if (value) {
                    appTheme.locale = locale;
                    // update hotshortcuts on the homepage
                    customPrompts.add(customPrompts.value);
                    // setState(() {});
                  }
                },
                content: Text('$locale'),
              );
            },
          ),
        ),
        spacer,
        // TODO: add macos support (https://pub.dev/packages/launch_at_startup#installation)
        if (!Platform.isMacOS)
          CheckBoxTile(
            isChecked: isLaunchAtStartupEnabled,
            onChanged: (value) async {
              if (value == true) {
                await launchAtStartup.enable();
              } else {
                await launchAtStartup.disable();
              }
              isLaunchAtStartupEnabled = value!;
              setState(() {});
            },
            child: Text('Launch at startup'.tr),
          ),
        CheckBoxTile(
          isChecked: appTheme.preventClose,
          expanded: true,
          onChanged: (value) {
            appTheme.togglePreventClose();
            setState(() {});
          },
          child: Text('Prevent close app'.tr),
        ),
        CheckBoxTile(
          isChecked: AppCache.showAppInDock.value == true,
          onChanged: (value) => appTheme.toggleShowInDock(),
          child: Text('Show app in dock'.tr),
        ),
        CheckBoxTile(
            isChecked: AppCache.hideTitleBar.value == true,
            child: Text('Hide window title'.tr),
            onChanged: (value) {
              appTheme.toggleHideTitleBar();
            }),
      ]),
    );
  }
}

class UserSettignsInfoPage extends StatefulWidget {
  const UserSettignsInfoPage({super.key});

  @override
  State<UserSettignsInfoPage> createState() => _UserSettignsInfoPageState();
}

class _UserSettignsInfoPageState extends State<UserSettignsInfoPage> {
  final systemPromptController = TextEditingController();
  final cities = CitiesList.getAllCitiesList();
  @override
  void initState() {
    super.initState();
    systemPromptController.text = AppCache.globalSystemPrompt.value!;
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: FluentTheme.of(context).inactiveBackgroundColor,
      child: ScaffoldPage.scrollable(children: [
        LabelText('Info about User'.tr),
        TextFormBox(
          prefix: BadgePrefix(Text('User name'.tr)),
          initialValue: AppCache.userName.value,
          minLines: 1,
          maxLines: 1,
          onChanged: (value) {
            AppCache.userName.value = value;
          },
        ),
        CaptionText('Your name that will be used in the chat'.tr),
        spacer,
        AutoSuggestBox(
          leadingIcon: BadgePrefix(Text('User city'.tr)),
          placeholder: AppCache.userCityName.value,
          onChanged: (value, reason) {
            AppCache.userCityName.value = value;
          },
          clearButtonEnabled: false,
          trailingIcon: IconButton(
            icon: Icon(FluentIcons.delete_20_filled, color: Colors.red),
            onPressed: () {
              AppCache.userCityName.value = '';
              setState(() {});
            },
          ),
          items: [
            for (var city in cities)
              AutoSuggestBoxItem(label: city, value: city)
          ],
        ),
        CaptionText(
            'Your city name that will be used in the chat and to get weather'
                .tr),
        CheckBoxTile(
          isChecked: AppCache.includeUserCityNamePrompt.value!,
          onChanged: (value) {
            AppCache.includeUserCityNamePrompt.value = value;
          },
          child: Text('Include user city name in system prompt'.tr),
        ),
        CheckBoxTile(
          isChecked: AppCache.includeWeatherPrompt.value!,
          onChanged: (value) {
            AppCache.includeWeatherPrompt.value = value;
          },
          child: Text('Include weather in system prompt'.tr),
        ),
        CheckBoxTile(
          isChecked: AppCache.includeUserNameToSysPrompt.value!,
          onChanged: (value) {
            AppCache.includeUserNameToSysPrompt.value = value;
          },
          child: Text('Include user name in system prompt'.tr),
        ),
        CheckBoxTile(
          isChecked: AppCache.includeTimeToSystemPrompt.value!,
          onChanged: (value) {
            AppCache.includeTimeToSystemPrompt.value = value;
          },
          child: Text('Include current date and time in system prompt'.tr),
        ),
        CheckBoxTile(
          isChecked: AppCache.includeSysInfoToSysPrompt.value!,
          onChanged: (value) {
            AppCache.includeSysInfoToSysPrompt.value = value;
          },
          child: Text('Include system info in system prompt'.tr),
        ),
        CheckBoxTile(
          isChecked: AppCache.includeKnowledgeAboutUserToSysPrompt.value!,
          onChanged: (value) {
            AppCache.includeKnowledgeAboutUserToSysPrompt.value = value;
          },
          child: Text('Include knowledge about user'.tr),
        ),
        Button(
            child: Text('Open info about User'.tr),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => const InfoAboutUserDialog(),
                barrierDismissible: true,
              );
            }),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Divider(),
        ),
        // Tooltip(
        //   message:
        //       'If enabled will summarize chat conversation and append the most'
        //               ' important information about the user to a file.'
        //               '\nCAN CAUSE ADDITIONAL SIGNIFICANT CHARGES!'
        //           .tr,
        //   child: CheckBoxTile(
        //     isChecked: AppCache.learnAboutUserAfterCreateNewChat.value!,
        //     onChanged: (value) {
        //       AppCache.learnAboutUserAfterCreateNewChat.value = value;
        //     },
        //     child: Wrap(
        //       crossAxisAlignment: WrapCrossAlignment.center,
        //       children: [
        //         Text('Learn about the user after creating new chat \$\$'.tr),
        //         const Icon(FluentIcons.brain_circuit_24_filled),
        //         SizedBox(width: 10.0),
        //         SizedBox(
        //           width: 120,
        //           height: 32,
        //           child: NumberBox(
        //               value: AppCache.maxTokensUserInfo.value!,
        //               clearButton: false,
        //               smallChange: 64,
        //               onChanged: (value) {
        //                 if (value == null) return;
        //                 if (value < 64) value = 64;
        //                 AppCache.maxTokensUserInfo.value = value;
        //               },
        //               mode: SpinButtonPlacementMode.inline),
        //         ),
        //       ],
        //     ),
        //   ),
        // ),
      ]),
    );
  }
}

class PermissionsSettingsPage extends StatefulWidget {
  const PermissionsSettingsPage({super.key});

  @override
  State<PermissionsSettingsPage> createState() =>
      _PermissionsSettingsPageState();
}

class _PermissionsSettingsPageState extends State<PermissionsSettingsPage> {
  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: FluentTheme.of(context).inactiveBackgroundColor,
      child: ScaffoldPage.scrollable(
        header: PageHeader(title: Text('Permissions'.tr)),
        children: [
          AccessebilityStatus(),
        ],
      ),
    );
  }
}

class DebugPage extends StatelessWidget {
  const DebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: FluentTheme.of(context).inactiveBackgroundColor,
      child: ScaffoldPage.scrollable(children: [
        Text('Debug', style: FluentTheme.of(context).typography.subtitle),
        Wrap(
          children: [
            Button(
                child: Text('PN'),
                onPressed: () {
                  NotificationService.showNotification('title', 'body');
                }),
            FilledRedButton(
                child: const Text('test native hello world'),
                onPressed: () {
                  NativeChannelUtils.testChannel();
                }),
            FilledRedButton(
                child: const Text('get selected text'),
                onPressed: () async {
                  final text = await NativeChannelUtils.getSelectedText();
                  log('Selected text: $text');
                }),
            FilledRedButton(
                child: const Text('show overlay'),
                onPressed: () {
                  NativeChannelUtils.showOverlay();
                }),
            FilledRedButton(
                child: const Text('request native permissions'),
                onPressed: () {
                  NativeChannelUtils.requestNativePermissions();
                }),
            FilledRedButton(
                child: const Text('init accessibility'),
                onPressed: () {
                  NativeChannelUtils.initAccessibility();
                }),
            FilledRedButton(
                child: const Text('is accessibility granted'),
                onPressed: () async {
                  final isGranted =
                      await NativeChannelUtils.isAccessibilityGranted();
                  log('isAccessibilityGranted: $isGranted');
                }),
            FilledRedButton(
                child: const Text('get screen size'),
                onPressed: () async {
                  final screenSize = await NativeChannelUtils.getScreenSize();
                  log('screenSize: $screenSize');
                }),
            FilledRedButton(
                child: const Text('get mouse position'),
                onPressed: () async {
                  final mousePosition =
                      await NativeChannelUtils.getMousePosition();
                  log('mousePosition: $mousePosition');
                }),
          ],
        )
      ]),
    );
  }
}

class ToolsSettings extends StatefulWidget {
  const ToolsSettings({super.key});

  @override
  State<ToolsSettings> createState() => _ToolsSettingsState();
}

class _ToolsSettingsState extends State<ToolsSettings> {
  bool obscureBraveText = true;
  bool obscureOpenAiText = true;
  final allValues = [
    AppCache.gptToolCopyToClipboardEnabled,
    AppCache.gptToolAutoOpenUrls,
    AppCache.gptToolGenerateImage,
    AppCache.gptToolRememberInfo,
  ];
  @override
  Widget build(BuildContext context) {
    // final gptProvider = context.watch<ChatProvider>();

    return ColoredBox(
      color: FluentTheme.of(context).inactiveBackgroundColor,
      child: ScaffoldPage.scrollable(
        children: [
          Text('Function tools'.tr,
              style: FluentTheme.of(context).typography.subtitle),
          spacer,
          Wrap(
            spacing: 15.0,
            children: [
              Button(
                onPressed: () {
                  bool allChecked = true;
                  for (var cache in allValues) {
                    if (cache.value == false) {
                      allChecked = false;
                      break;
                    }
                  }
                  setState(() {
                    for (var cache in allValues) {
                      cache.value = !allChecked;
                    }
                  });
                },
                child: Text('Toggle All'.tr),
              ),
              CheckBoxTile(
                key: Key(
                    'gptToolCopyToClipboardEnabled ${AppCache.gptToolCopyToClipboardEnabled.value}'),
                isChecked: AppCache.gptToolCopyToClipboardEnabled.value!,
                expanded: false,
                onChanged: (value) {
                  setState(() {
                    AppCache.gptToolCopyToClipboardEnabled.value = value;
                  });
                },
                child: Text('Auto copy to clipboard'.tr),
              ),
              CheckBoxTile(
                key: Key('autoOpenUrls ${AppCache.gptToolAutoOpenUrls.value}'),
                isChecked: AppCache.gptToolAutoOpenUrls.value!,
                expanded: false,
                onChanged: (value) {
                  setState(() {
                    AppCache.gptToolAutoOpenUrls.value = value;
                  });
                },
                child: Text('Auto open url'.tr),
              ),
              CheckBoxTile(
                key: Key(
                    'gptToolGenerateImage ${AppCache.gptToolGenerateImage.value}'),
                isChecked: AppCache.gptToolGenerateImage.value!,
                expanded: false,
                onChanged: (value) {
                  setState(() {
                    AppCache.gptToolGenerateImage.value = value;
                  });
                },
                child: Text('Generate images'.tr),
              ),
              CheckBoxTile(
                key: Key(
                    'gptToolRememberInfo ${AppCache.gptToolRememberInfo.value}'),
                isChecked: AppCache.gptToolRememberInfo.value!,
                expanded: false,
                onChanged: (value) {
                  setState(() {
                    AppCache.gptToolRememberInfo.value = value;
                  });
                },
                child: Text('Remember info'.tr),
              ),
            ],
          ),
          biggerSpacer,
          Text('Additional tools'.tr,
              style: FluentTheme.of(context).typography.subtitle),
          spacer,
          Checkbox(
            content: Expanded(
              child: Text(
                  'Imgur (Used to upload your image to your private Imgur account and get image link)'
                      .tr),
            ),
            checked: AppCache.useImgurApi.value,
            onChanged: (value) async {
              setState(() {
                AppCache.useImgurApi.value = value;
              });
            },
          ),
          if (AppCache.useImgurApi.value == true) ...[
            TextFormBox(
              placeholder: 'Imgur client ID',
              initialValue: AppCache.imgurClientId.value,
              obscureText: true,
              suffix: Tooltip(
                message: """1. Go to Imgur and create an account.
      2. Navigate to the Imgur API and register your application to get a clientId.
      3. Fill "Application Name" with anything you want. (e.g. "Fluent GPT")
      4. Authorization type: "OAuth 2 authorization without a callback URL
      5. Email: Your email
      6. Paste clientId here"""
                    .tr,
                child: Icon(FluentIcons.info_20_filled),
              ),
              onChanged: (value) {
                AppCache.imgurClientId.value = value;
                ImgurIntegration.authenticate(value);
              },
            ),
            const LinkTextButton(
              'Get Imgur clientID',
              url: 'https://api.imgur.com/oauth2/addclient',
            ),
          ],
          spacer,
          Text('Image Search engines'.tr,
              style: FluentTheme.of(context).typography.subtitle),
          Checkbox(
            content: const Text('SouceNao'),
            checked: AppCache.useSouceNao.value,
            onChanged: (value) async {
              setState(() {
                AppCache.useSouceNao.value = value;
              });
            },
          ),
          Checkbox(
            content: const Text('Yandex Image search'),
            checked: AppCache.useYandexImageSearch.value,
            onChanged: (value) async {
              setState(() {
                AppCache.useYandexImageSearch.value = value;
              });
            },
          ),
          CheckBoxTooltip(
            content: Text('Enable annoy mode'.tr),
            tooltip:
                'Use timer and allow AI to write you. Can cause additional charges!'
                    .tr,
            checked: AppCache.enableAutonomousMode.value,
            onChanged: (value) async {
              if (value!) {
                await AnnoyFeature.showConfigureDialog();
              } else {
                AnnoyFeature.stop();
                AppCache.enableAutonomousMode.value = false;
              }
              setState(() {});
            },
          ),
        ],
      ),
    );
  }
}

class AppearanceSettings extends StatelessWidget {
  const AppearanceSettings({super.key});
  Widget _buildColorBlock(AppTheme appTheme, AccentColor color) {
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Button(
        onPressed: () {
          appTheme.color = color;
          appTheme.setWindowEffectColor(color);
        },
        style: ButtonStyle(
          padding: WidgetStateProperty.all(EdgeInsets.zero),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.isPressed) {
              return color.light;
            } else if (states.isHovered) {
              return color.lighter;
            }
            return color;
          }),
        ),
        child: Container(
          height: 40,
          width: 40,
          alignment: AlignmentDirectional.center,
          child: appTheme.color == color
              ? Icon(
                  FluentIcons.radio_button_16_filled,
                  color: color.basedOnLuminance(),
                  size: 24.0,
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gptProvider = context.watch<ChatProvider>();
    final appTheme = context.watch<AppTheme>();
    return ColoredBox(
      color: FluentTheme.of(context).inactiveBackgroundColor,
      child: ScaffoldPage.scrollable(
        children: [
          Text('Accent Color'.tr,
              style: FluentTheme.of(context).typography.subtitle),
          spacer,
          Wrap(children: [
            Tooltip(
              message: accentColorNames[0],
              child: _buildColorBlock(appTheme, systemAccentColor),
            ),
            ...List.generate(Colors.accentColors.length, (index) {
              final color = Colors.accentColors[index];
              return Tooltip(
                message: accentColorNames[index + 1],
                child: _buildColorBlock(appTheme, color),
              );
            }),
          ]),
          Text('Theme'.tr, style: FluentTheme.of(context).typography.subtitle),
          spacer,
          Wrap(
            spacing: 4.0,
            runSpacing: 8.0,
            children: [
              GestureDetector(
                onTap: appTheme.applyLightTheme,
                child: ZoomHover(
                  hoverScale: 0.95,
                  child: Card(
                    borderRadius: BorderRadius.circular(12.0),
                    borderColor: appTheme.currentThemeStyle == ThemeStyle.white
                        ? Colors.blue
                        : null,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: SizedBox.square(
                            dimension: 200.0,
                            child: Image.asset('assets/theme_white.png'),
                          ),
                        ),
                        Text(
                          'Light'.tr,
                          style: FluentTheme.of(context).typography.bodyStrong,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: appTheme.applyDarkTheme,
                child: ZoomHover(
                  hoverScale: 0.95,
                  child: Card(
                    borderRadius: BorderRadius.circular(12.0),
                    borderColor: appTheme.currentThemeStyle == ThemeStyle.dark
                        ? Colors.blue
                        : null,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: SizedBox.square(
                            dimension: 200.0,
                            child: Image.asset('assets/theme_dark.png'),
                          ),
                        ),
                        Text(
                          'Dark'.tr,
                          style: FluentTheme.of(context).typography.bodyStrong,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: appTheme.applyMicaTheme,
                child: ZoomHover(
                  hoverScale: 0.95,
                  child: Card(
                    borderRadius: BorderRadius.circular(12.0),
                    borderColor: appTheme.currentThemeStyle == ThemeStyle.mica
                        ? Colors.blue
                        : null,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: SizedBox.square(
                            dimension: 200.0,
                            child: Image.asset('assets/theme_mica.png'),
                          ),
                        ),
                        Text(
                          'Mica'.tr,
                          style: FluentTheme.of(context).typography.bodyStrong,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              GestureDetector(
                onTap: appTheme.applyAcrylicTheme,
                child: ZoomHover(
                  hoverScale: 0.95,
                  child: Card(
                    borderRadius: BorderRadius.circular(12.0),
                    borderColor:
                        appTheme.currentThemeStyle == ThemeStyle.acrylic
                            ? Colors.blue
                            : null,
                    child: Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8.0),
                          child: SizedBox.square(
                            dimension: 200.0,
                            child: Image.asset('assets/theme_acrylic.png'),
                          ),
                        ),
                        Text(
                          'Acrilic'.tr,
                          style: FluentTheme.of(context).typography.bodyStrong,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          spacer,
          Checkbox(
            content: Text('Set window as frameless'.tr),
            checked: AppCache.frameless.value,
            onChanged: (value) {
              appTheme.setAsFrameless(value);
              if (value == false) {
                displayInfoBar(context,
                    builder: (context, _) => InfoBar(
                          title: Text('Restart the app to apply changes'.tr),
                          severity: InfoBarSeverity.warning,
                        ));
              }
            },
          ),
          spacer,
          DensityModeDropdown(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Divider(),
          ),
          Text('Message Text size'.tr,
              style: FluentTheme.of(context).typography.subtitle),
          spacer,
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text('Basic Message Text Size'.tr,
                        style: FluentTheme.of(context).typography.subtitle),
                    SizedBox(
                      width: 200.0,
                      child: NumberBox(
                        value: gptProvider.textSize,
                        onChanged: (value) {
                          gptProvider.textSize = value ?? 14;
                        },
                        mode: SpinButtonPlacementMode.inline,
                      ),
                    ),
                    const MessageSamplePreviewCard(isCompact: false),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text('Compact Message Text Size'.tr,
                        style: FluentTheme.of(context).typography.subtitle),
                    SizedBox(
                      width: 200.0,
                      child: NumberBox(
                        value: AppCache.compactMessageTextSize.value,
                        onChanged: (value) {
                          AppCache.compactMessageTextSize.value = value ?? 10;
                          Provider.of<ChatProvider>(context, listen: false)
                              .updateUI();
                        },
                        mode: SpinButtonPlacementMode.inline,
                      ),
                    ),
                    const MessageSamplePreviewCard(isCompact: true),
                  ],
                ),
              )
            ],
          ),
        ],
      ),
    );
  }
}

class _ElevenLabsSettings extends StatelessWidget {
  const _ElevenLabsSettings();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ElevenLabs API key (speech) \$\$\$',
          style: FluentTheme.of(context).typography.subtitle,
        ),
        ElevenLabsConfigContainer(),
        // Button(
        //   child: const Text('Configure ElevenLabs'),
        //   onPressed: () => ElevenlabsSpeech.showConfigureDialog(context),
        // ),
      ],
    );
  }
}

class _AzureSettings extends StatefulWidget {
  const _AzureSettings();

  @override
  State<_AzureSettings> createState() => _AzureSettingsState();
}

class _AzureSettingsState extends State<_AzureSettings> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Azure API key (speech) \$',
          style: FluentTheme.of(context).typography.subtitle,
        ),
        TextFormBox(
          initialValue: AppCache.azureSpeechApiKey.value,
          placeholder: AppCache.azureSpeechApiKey.value,
          obscureText: true,
          suffix: DropDownButton(
              leading: Text('${'Voice:'.tr} ${AppCache.azureVoiceModel.value}'),
              items: [
                for (var model in AzureSpeech.listModels)
                  MenuFlyoutItem(
                    selected: AppCache.azureVoiceModel.value == model,
                    trailing: SqueareIconButton(
                      onTap: () {
                        final previousModel = AppCache.azureVoiceModel.value;
                        if (AzureSpeech.isValid()) {
                          AppCache.azureVoiceModel.value = model;
                          AzureSpeech.readAloud(
                            'This is a sample text to read aloud',
                            onCompleteReadingAloud: () {
                              AppCache.azureVoiceModel.value = previousModel;
                            },
                          );
                        }
                      },
                      icon: const Icon(FluentIcons.play_circle_24_filled),
                      tooltip: 'Read sample'.tr,
                    ),
                    onPressed: () {
                      AppCache.azureVoiceModel.value = model;
                      DeepgramSpeech.init();
                      setState(() {});
                    },
                    text: Text(model),
                  ),
              ]),
          onChanged: (value) {
            AppCache.azureSpeechApiKey.value = value.trim();
            AzureSpeech.init();
          },
        ),
      ],
    );
  }
}

class _DeepgramSettings extends StatefulWidget {
  const _DeepgramSettings();

  @override
  State<_DeepgramSettings> createState() => _DeepgramSettingsState();
}

class _DeepgramSettingsState extends State<_DeepgramSettings> {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Deepgram API key (speech) \$\$',
          style: FluentTheme.of(context).typography.subtitle,
        ),
        TextFormBox(
          initialValue: AppCache.deepgramApiKey.value,
          placeholder: AppCache.deepgramApiKey.value,
          obscureText: true,
          suffix: DropDownButton(
              leading:
                  Text('${'Voice:'.tr} ${AppCache.deepgramVoiceModel.value}'),
              items: [
                for (var model in DeepgramSpeech.listModels)
                  MenuFlyoutItem(
                    selected: AppCache.deepgramVoiceModel.value == model,
                    trailing: SqueareIconButton(
                      onTap: () {
                        if (DeepgramSpeech.isValid()) {
                          DeepgramSpeech.readAloud(
                              'This is a sample text to read aloud');
                        }
                      },
                      icon: const Icon(FluentIcons.play_circle_24_filled),
                      tooltip: 'Read sample'.tr,
                    ),
                    onPressed: () {
                      AppCache.deepgramVoiceModel.value = model;
                      DeepgramSpeech.init();
                      setState(() {});
                    },
                    text: Text(model),
                  ),
              ]),
          onChanged: (value) {
            AppCache.deepgramApiKey.value = value.trim();
            DeepgramSpeech.init();
          },
        ),
        const Align(
          alignment: Alignment.centerLeft,
          child: LinkTextButton(
            'https://console.deepgram.com',
            url: 'https://console.deepgram.com',
          ),
        ),
      ],
    );
  }
}
