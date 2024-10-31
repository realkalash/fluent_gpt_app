import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_gpt/cities_list.dart';
import 'package:fluent_gpt/common/custom_prompt.dart';
import 'package:fluent_gpt/common/enums.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/dialogs/ai_prompts_library_dialog.dart';
import 'package:fluent_gpt/dialogs/custom_action_dialog.dart';
import 'package:fluent_gpt/dialogs/global_system_prompt_sample_dialog.dart';
import 'package:fluent_gpt/dialogs/how_to_use_llm_dialog.dart';
import 'package:fluent_gpt/dialogs/info_about_user_dialog.dart';
import 'package:fluent_gpt/dialogs/models_list_dialog.dart';
import 'package:fluent_gpt/features/deepgram_speech.dart';
import 'package:fluent_gpt/features/elevenlabs_speech.dart';
import 'package:fluent_gpt/features/imgur_integration.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/native_channels.dart';
import 'package:fluent_gpt/navigation_provider.dart';
import 'package:fluent_gpt/pages/prompts_settings_page.dart';
import 'package:fluent_gpt/pages/welcome/welcome_shortcuts_helper_screen.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/providers/server_provider.dart';
import 'package:fluent_gpt/shell_driver.dart';
import 'package:fluent_gpt/system_messages.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/custom_buttons.dart';
import 'package:fluent_gpt/widgets/custom_list_tile.dart';
import 'package:fluent_gpt/widgets/keybinding_dialog.dart';
import 'package:fluent_gpt/widgets/markdown_builders/code_wrapper.dart';
import 'package:fluent_gpt/widgets/message_list_tile.dart';
import 'package:fluent_gpt/widgets/page.dart';
import 'package:fluent_gpt/widgets/text_link.dart';
import 'package:fluent_gpt/widgets/wiget_constants.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:langchain/langchain.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:rxdart/subjects.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:flutter/foundation.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:provider/provider.dart';
import 'package:system_info2/system_info2.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:window_manager/window_manager.dart';

import '../theme.dart';
import '../widgets/confirmation_dialog.dart';

BehaviorSubject<String> defaultGPTLanguage = BehaviorSubject.seeded('en');
bool isLaunchAtStartupEnabled = false;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with PageMixin {
  @override
  Widget build(BuildContext context) {
    final canGoBack = Navigator.of(context).canPop();
    return Container(
      color: Colors.transparent,
      child: ScaffoldPage.scrollable(
        header: GestureDetector(
          onPanStart: (v) => WindowManager.instance.startDragging(),
          child: PageHeader(
              title: const Text('Settings'),
              leading: canGoBack
                  ? IconButton(
                      icon: const Icon(FluentIcons.arrow_left_24_filled,
                          size: 24),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : null),
        ),
        children: [
          const EnabledGptTools(),
          const AdditionalTools(),
          spacer,
          const GlobalSettings(),
          spacer,
          const CustomActionsSection(),
          const OverlaySettings(),
          const AccessibilityPermissionButton(),
          const _CacheSection(),
          if (kDebugMode) const _DebugSection(),
          const _HotKeySection(),
          const CustomPromptsButton(),
          Text('Appearance', style: FluentTheme.of(context).typography.title),
          const _ThemeModeSection(),
          spacer,
          MessageAppearanceSettings(),
          spacer,
          // biggerSpacer,
          // const _LocaleSection(),
          const _LocaleSection(),
          biggerSpacer,
          const ServerSettings(),
          const _OtherSettings(),
        ],
      ),
    );
  }
}

class MessageAppearanceSettings extends StatelessWidget {
  const MessageAppearanceSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final gptProvider = context.watch<ChatProvider>();
    return Expander(
        header: Text('Message Appearance'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Message Text size',
                style: FluentTheme.of(context).typography.subtitle),
            spacer,
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      Text('Basic Message Text Size',
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
                      Text('Compact Message Text Size',
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
        ));
  }
}

class CustomActionsSection extends StatefulWidget {
  const CustomActionsSection({super.key});

  @override
  State<CustomActionsSection> createState() => _CustomActionsSectionState();
}

class _CustomActionsSectionState extends State<CustomActionsSection> {
  @override
  Widget build(BuildContext context) {
    return Expander(
      header: const Text('Custom actions (on response end)'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
            child: const Text('Add custom action'),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => const CustomActionDialog(),
              );
            },
          ),
          spacer,
        ],
      ),
    );
  }
}

class AdditionalTools extends StatefulWidget {
  const AdditionalTools({super.key});

  @override
  State<AdditionalTools> createState() => _AdditionalToolsState();
}

class _AdditionalToolsState extends State<AdditionalTools> {
  @override
  Widget build(BuildContext context) {
    return Expander(
      header: const Text('Additional tools'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Additional tools',
              style: FluentTheme.of(context).typography.subtitle),
          spacer,
          Checkbox(
            content: Expanded(
              child: const Text(
                  'Imgur (Used to upload your image to your private Imgur account and get image link)'),
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
              suffix: const Tooltip(
                message: """1. Go to Imgur and create an account.
      2. Navigate to the Imgur API and register your application to get a clientId.
      3. Fill "Application Name" with anything you want. (e.g. "Fluent GPT")
      4. Authorization type: "OAuth 2 authorization without a callback URL
      5. Email: Your email
      6. Paste clientId here""",
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
          Text('Image Search engines',
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
        ],
      ),
    );
  }
}

class _DebugSection extends StatelessWidget {
  const _DebugSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        biggerSpacer,
        Text('Debug', style: FluentTheme.of(context).typography.subtitle),
        Wrap(
          children: [
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
        ),
        biggerSpacer,
      ],
    );
  }
}

class AccessibilityPermissionButton extends StatelessWidget {
  const AccessibilityPermissionButton({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        spacer,
        AccessebilityStatus(),
        spacer,
      ],
    );
  }
}

class CustomPromptsButton extends StatelessWidget {
  const CustomPromptsButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        spacer,
        Text('Quick prompts',
            style: FluentTheme.of(context).typography.subtitle),
        spacer,
        Button(
          child: const Text('Customize quick prompts'),
          onPressed: () {
            showDialog(
              context: context,
              builder: (ctx) => const CustomPromptsSettingsDialog(),
            );
          },
        ),
        biggerSpacer
      ],
    );
  }
}

class OverlaySettings extends StatefulWidget {
  const OverlaySettings({super.key});

  @override
  State<OverlaySettings> createState() => _OverlaySettingsState();
}

class _OverlaySettingsState extends State<OverlaySettings> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Overlay settings',
            style: FluentTheme.of(context).typography.subtitle),
        _CheckBoxTile(
          isChecked: AppCache.enableOverlay.value!,
          onChanged: (value) {
            setState(() {
              AppCache.enableOverlay.value = value;
            });
            Provider.of<AppTheme>(context, listen: false).updateUI();
          },
          child: const Text('Enable overlay'),
        ),
        _CheckBoxTile(
          isChecked: AppCache.showSettingsInOverlay.value!,
          onChanged: (value) {
            setState(() {
              AppCache.showSettingsInOverlay.value = value;
            });
          },
          child: const Text('Show settings icon in overlay'),
        ),
        spacer,
        NumberBox(
          value: AppCache.overlayVisibleElements.value,
          placeholder:
              AppCache.overlayVisibleElements.value == null ? 'Adaptive' : null,
          onChanged: (value) {
            AppCache.overlayVisibleElements.value = value;
          },
          min: 4,
          mode: SpinButtonPlacementMode.inline,
        ),
        biggerSpacer,
      ],
    );
  }
}

class AccessebilityStatus extends StatefulWidget {
  const AccessebilityStatus({super.key});

  @override
  State<AccessebilityStatus> createState() => _AccessebilityStatusState();
}

class _AccessebilityStatusState extends State<AccessebilityStatus> {
  @override
  Widget build(BuildContext context) {
    if (!Platform.isMacOS) {
      return const SizedBox.shrink();
    }
    return FutureBuilder(
      future: overlayChannel.invokeMethod('isAccessabilityGranted'),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final isGranted = snapshot.data as bool? ?? false;
          return Button(
            onPressed: () {
              const url =
                  'x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility';
              launchUrlString(url);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Accessibility granted'),
                const SizedBox(width: 10.0),
                if (isGranted)
                  Icon(FluentIcons.checkmark_20_regular, color: Colors.green)
                else
                  Icon(FluentIcons.error_circle_20_regular, color: Colors.red)
              ],
            ),
          );
        }
        return const Text('Checking accessibility status...');
      },
    );
  }
}

class ServerSettings extends StatelessWidget {
  const ServerSettings({super.key});

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode) return const SizedBox.shrink();
    final server = context.watch<ServerProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Server settings',
            style: FluentTheme.of(context).typography.subtitle),
        spacer,
        Expander(
          header: Row(
            children: [
              const Text('Models List'),
              const Spacer(),
              Button(
                child: const Text('Add model'),
                onPressed: () async {
                  String? result = await FilePicker.platform.getDirectoryPath(
                      // allowMultiple: false,
                      // dialogTitle: 'Select a gguf model',
                      // type: FileType.custom,
                      // allowedExtensions: ['gguf'],
                      );
                  if (result != null && result.isNotEmpty) {
                    server.addLocalModelPath(result);
                  }
                },
              ),
              SqueareIconButton(
                onTap: () {
                  showDialog(
                      context: context,
                      builder: (ctx) => const HowToRunLocalModelsDialog());
                },
                icon: const Icon(FluentIcons.chat_help_20_filled),
                tooltip: 'How to use local models',
              )
            ],
          ),
          content: ListView.builder(
            shrinkWrap: true,
            itemCount: server.localModelsPaths.length,
            itemBuilder: (context, index) {
              final element = server.localModelsPaths.entries.elementAt(index);
              return ListTile(
                title: SelectableText(element.key),
                leading: IconButton(
                  icon: Icon(element.value
                      ? FluentIcons.pause_20_filled
                      : FluentIcons.play_20_filled),
                  onPressed: () {
                    if (element.value) {
                      server.stopModel(element.key);
                    } else {
                      server.loadModel(element.key);
                    }
                  },
                ),
                trailing: IconButton(
                  icon: Icon(FluentIcons.delete_20_filled, color: Colors.red),
                  onPressed: () => server.removeLocalModelPath(element.key),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class GlobalSettings extends StatefulWidget {
  const GlobalSettings({super.key});

  @override
  State<GlobalSettings> createState() => _GlobalSettingsState();
}

class _GlobalSettingsState extends State<GlobalSettings> {
  final systemPromptController = TextEditingController();
  final cities = CitiesList.getAllCitiesList();
  @override
  void initState() {
    super.initState();
    systemPromptController.text = AppCache.globalSystemPrompt.value!;
  }

  @override
  Widget build(BuildContext context) {
    return Expander(
      header: const Text('Global settings'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const LabelText('Global system prompt'),
          TextFormBox(
            placeholder: 'Global system prompt',
            controller: systemPromptController,
            minLines: 1,
            maxLines: 12,
            suffix: AiLibraryButton(onPressed: () async {
              final prompt = await showDialog<CustomPrompt?>(
                context: context,
                builder: (ctx) => const AiPromptsLibraryDialog(),
                barrierDismissible: true,
              );
              if (prompt != null) {
                AppCache.globalSystemPrompt.value = prompt.prompt;
                systemPromptController.text = prompt.prompt;
                defaultSystemMessage = prompt.prompt;
              }
            }),
            onChanged: (value) {
              AppCache.globalSystemPrompt.value = value;
              defaultSystemMessage = value;
            },
          ),
          const CaptionText(
            'Customizable Global system prompt will be used for all NEW chats. To check the whole system prompt press button below',
          ),
          Button(
            child: const Text('Click here to check the whole system prompt'),
            onPressed: () {
              showDialog(
                context: context,
                builder: (ctx) => const GlobalSystemPromptSampleDialog(),
                barrierDismissible: true,
              );
            },
          ),
          spacer,
          const LabelText('Info about User'),
          TextFormBox(
            prefix: const _BadgePrefix(Text('User name')),
            initialValue: AppCache.userName.value,
            minLines: 1,
            maxLines: 1,
            onChanged: (value) {
              AppCache.userName.value = value;
            },
          ),
          const CaptionText('Your name that will be used in the chat'),
          spacer,
          AutoSuggestBox(
            leadingIcon: const _BadgePrefix(Text('User city')),
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
          const CaptionText(
              'Your city name that will be used in the chat and to get weather'),
          spacer,
          const LabelText('System info'),
          Card(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
          _CheckBoxTile(
            isChecked: AppCache.includeUserCityNamePrompt.value!,
            onChanged: (value) {
              AppCache.includeUserCityNamePrompt.value = value;
            },
            child: const Text('Include user city name in system prompt'),
          ),
          _CheckBoxTile(
            isChecked: AppCache.includeWeatherPrompt.value!,
            onChanged: (value) {
              AppCache.includeWeatherPrompt.value = value;
            },
            child: const Text('Include weather in system prompt'),
          ),
          _CheckBoxTile(
            isChecked: AppCache.includeUserNameToSysPrompt.value!,
            onChanged: (value) {
              AppCache.includeUserNameToSysPrompt.value = value;
            },
            child: const Text('Include user name in system prompt'),
          ),
          _CheckBoxTile(
            isChecked: AppCache.includeTimeToSystemPrompt.value!,
            onChanged: (value) {
              AppCache.includeTimeToSystemPrompt.value = value;
            },
            child: const Text('Include current date and time in system prompt'),
          ),
          _CheckBoxTile(
            isChecked: AppCache.includeSysInfoToSysPrompt.value!,
            onChanged: (value) {
              AppCache.includeSysInfoToSysPrompt.value = value;
            },
            child: const Text('Include system info in system prompt'),
          ),
          Tooltip(
            message:
                'If enabled will summarize chat conversation and append the most'
                ' important information about the user to a file.'
                '\nCAN CAUSE ADDITIONAL SIGNIFICANT CHARGES!',
            child: Row(
              children: [
                _CheckBoxTile(
                  isChecked: AppCache.learnAboutUserAfterCreateNewChat.value!,
                  onChanged: (value) {
                    AppCache.learnAboutUserAfterCreateNewChat.value = value;
                  },
                  child: const Text(
                      'Learn about the user after creating new chat \$\$'),
                ),
                const Icon(FluentIcons.brain_circuit_24_filled),
                SizedBox(width: 10.0),
                SizedBox(
                  width: 200,
                  height: 30,
                  child: NumberBox(
                      value: AppCache.maxTokensUserInfo.value!,
                      clearButton: false,
                      smallChange: 64,
                      onChanged: (value) {
                        if (value == null) return;
                        if (value < 64) value = 64;
                        AppCache.maxTokensUserInfo.value = value;
                      },
                      mode: SpinButtonPlacementMode.inline),
                ),
              ],
            ),
          ),
          Row(
            children: [
              _CheckBoxTile(
                isChecked: AppCache.includeKnowledgeAboutUserToSysPrompt.value!,
                onChanged: (value) {
                  AppCache.includeKnowledgeAboutUserToSysPrompt.value = value;
                },
                child: const Text('Include knowledge about user'),
              ),
              const Spacer(),
              Button(
                  child: const Text('Open info about User'),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => const InfoAboutUserDialog(),
                      barrierDismissible: true,
                    );
                  }),
            ],
          ),
        ],
      ),
    );
  }
}

class _CheckBoxTile extends StatefulWidget {
  const _CheckBoxTile({
    super.key,
    required this.isChecked,
    required this.child,
    this.onChanged,
  });
  final bool isChecked;
  final Widget child;
  final void Function(bool?)? onChanged;
  @override
  State<_CheckBoxTile> createState() => _CheckBoxTileState();
}

class _CheckBoxTileState extends State<_CheckBoxTile> {
  bool isChecked = false;
  bool isHovered = false;
  @override
  void initState() {
    isChecked = widget.isChecked;
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (event) {
        if (isHovered) return;
        setState(() {
          isHovered = true;
        });
      },
      onExit: (event) {
        if (!isHovered) return;
        setState(() {
          isHovered = false;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          color: isHovered ? context.theme.cardColor : null,
          borderRadius: BorderRadius.circular(4.0),
        ),
        child: GestureDetector(
          onTap: () {
            setState(() {
              isChecked = !isChecked;
            });
            widget.onChanged?.call(isChecked);
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Checkbox(
                  checked: isChecked,
                  onChanged: (value) {
                    setState(() {
                      isChecked = value!;
                    });
                    widget.onChanged?.call(value);
                  }),
              const SizedBox(width: 8.0),
              widget.child,
            ],
          ),
        ),
      ),
    );
  }
}

class _BadgePrefix extends StatelessWidget {
  const _BadgePrefix(this.child, {super.key});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2.0),
      margin: const EdgeInsets.only(left: 4.0),
      decoration: BoxDecoration(
        color: context.theme.cardColor,
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: child,
    );
  }
}

class LabelText extends StatelessWidget {
  const LabelText(this.label, {super.key});
  final String label;
  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: FluentTheme.of(context).typography.subtitle,
    );
  }
}

class CaptionText extends StatelessWidget {
  const CaptionText(this.caption, {super.key});
  final String caption;
  @override
  Widget build(BuildContext context) {
    return Text(
      caption,
      style: FluentTheme.of(context).typography.caption,
    );
  }
}

class EnabledGptTools extends StatefulWidget {
  const EnabledGptTools({super.key});

  @override
  State<EnabledGptTools> createState() => _EnabledGptToolsState();
}

class _EnabledGptToolsState extends State<EnabledGptTools> {
  bool obscureBraveText = true;
  bool obscureOpenAiText = true;
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Enabled GPT tools',
            style: FluentTheme.of(context).typography.subtitle),
        Wrap(
          spacing: 15.0,
          children: [
            _CheckBoxTile(
              isChecked: AppCache.gptToolCopyToClipboardEnabled.value!,
              onChanged: (value) {
                setState(() {
                  AppCache.gptToolCopyToClipboardEnabled.value = value;
                });
              },
              child: const Text('Auto copy to clipboard'),
            ),
            biggerSpacer,
          ],
        ),
        Button(
          child: Text('Models List'),
          onPressed: () {
            showDialog(
                context: context, builder: (ctx) => const ModelsListDialog());
          },
        ),
        spacer,
        Expander(
          header: const Text('API and URLs'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Text('LLama url (local AI)',
              //     style: FluentTheme.of(context).typography.subtitle),
              // TextFormBox(
              //   initialValue: AppCache.localApiUrl.value,
              //   placeholder: AppCache.localApiUrl.value,
              //   prefix: Padding(
              //     padding: const EdgeInsets.only(left: 8),
              //     child: Checkbox(
              //       checked: AppCache.useLocalApiUrl.value!,
              //       onChanged: (value) {
              //         setState(() {
              //           AppCache.useLocalApiUrl.value = value;
              //         });
              //       },
              //     ),
              //   ),
              //   onFieldSubmitted: (value) async {
              //     AppCache.localApiUrl.value = value;
              //     final provider =
              //         Provider.of<ChatProvider>(context, listen: false);
              //     final isSuccess = await provider.initChatModels();
              //     if (isSuccess) {
              //       provider.initModelsApi();
              //       // ignore: use_build_context_synchronously
              //       displayInfoBar(context, builder: (context, _) {
              //         return const InfoBar(
              //             title: Text('Success'),
              //             severity: InfoBarSeverity.success);
              //       });
              //     } else {
              //       // ignore: use_build_context_synchronously
              //       displayInfoBar(context, builder: (context, _) {
              //         return const InfoBar(
              //             title: Text('Error'),
              //             severity: InfoBarSeverity.error);
              //       });
              //     }
              //   },
              //   onChanged: (value) {
              //     AppCache.localApiUrl.value = value;
              //   },
              // ),
              Text(
                'Brave API key (search engine) \$',
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
              // Text(
              //   'OpenAi global API key \$',
              //   style: FluentTheme.of(context).typography.subtitle,
              // ),
              // TextFormBox(
              //   initialValue: AppCache.openAiApiKey.value,
              //   placeholder: AppCache.openAiApiKey.value,
              //   obscureText: obscureOpenAiText,
              //   suffix: IconButton(
              //     icon: const Icon(FluentIcons.eye_20_regular),
              //     onPressed: () {
              //       setState(() {
              //         obscureOpenAiText = !obscureOpenAiText;
              //       });
              //     },
              //   ),
              //   onChanged: (value) => AppCache.openAiApiKey.value = value,
              // ),
              // const Align(
              //   alignment: Alignment.centerLeft,
              //   child: LinkTextButton(
              //     'https://platform.openai.com/api-keys',
              //     url: 'https://platform.openai.com/api-keys',
              //   ),
              // ),
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
                    'Text-to-Speech service: ${AppCache.textToSpeechService.value}'),
              ),
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
                        Text('Voice: ${AppCache.deepgramVoiceModel.value}'),
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
                            tooltip: 'Read sample',
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
              Text(
                'ElevenLabs API key (speech) \$\$\$',
                style: FluentTheme.of(context).typography.subtitle,
              ),
              Button(
                child: const Text('Configure ElevenLabs'),
                onPressed: () => ElevenlabsSpeech.showConfigureDialog(context),
              ),
              const Align(
                alignment: Alignment.centerLeft,
                child: LinkTextButton(
                  'https://elevenlabs.io/app/speech-synthesis/text-to-speech',
                  url:
                      'https://elevenlabs.io/app/speech-synthesis/text-to-speech',
                ),
              ),
            ],
          ),
        ),
        spacer,
      ],
    );
  }
}

class _OtherSettings extends StatelessWidget {
  const _OtherSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final appTheme = context.watch<AppTheme>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Other settings',
            style: FluentTheme.of(context).typography.subtitle),
        spacer,
        Checkbox(
          content: const Text('Prevent close app'),
          checked: appTheme.preventClose,
          onChanged: (value) => appTheme.togglePreventClose(),
        ),
        Checkbox(
          content: const Text('Show in dock'),
          checked: AppCache.showAppInDock.value == true,
          onChanged: (value) => appTheme.toggleShowInDock(),
        ),
        Checkbox(
            content: const Text('Hide window title'),
            checked: AppCache.hideTitleBar.value,
            onChanged: (value) => appTheme.toggleHideTitleBar()),
        // TODO: add macos support (https://pub.dev/packages/launch_at_startup#installation)
        if (!Platform.isMacOS)
          Checkbox(
            content: const Text('Launch at startup'),
            checked: isLaunchAtStartupEnabled,
            onChanged: (value) async {
              if (value == true) {
                await launchAtStartup.enable();
              } else {
                await launchAtStartup.disable();
              }
              isLaunchAtStartupEnabled = value!;
              appTheme.updateUI();
            },
          ),
        Tooltip(
          message: 'Can cause additional charges!',
          child: Checkbox(
            content: const Text('Use ai to name chat'),
            checked: AppCache.useAiToNameChat.value,
            onChanged: (value) {
              AppCache.useAiToNameChat.value = value;
              appTheme.updateUI();
            },
          ),
        ),
        spacer,
        Text('Autoscroll speed (use it if the chat is jumping too hard)'),
        Consumer<ChatProvider>(
          builder: (context, provider, child) {
            return NumberBox(
              value: provider.autoScrollSpeed,
              onChanged: (value) {
                provider.setAutoScrollSpeed(value ?? 1);
              },
              min: 0.01,
              max: 10,
              smallChange: 0.1,
              largeChange: 1,
              mode: SpinButtonPlacementMode.inline,
            );
          },
        ),
      ],
    );
  }
}

class MessageSamplePreviewCard extends StatelessWidget {
  const MessageSamplePreviewCard({super.key, required this.isCompact});
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatProvider>();
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Message sample preview'),
            MessageCard(
              message: const AIChatMessage(
                content:
                    '''Hello, how are you doing today?\nI'm doing great, thank you for asking. I'm here to help you with anything you need.''',
              ),
              selectionMode: false,
              dateTime: DateTime.now(),
              id: '1234',
              isError: false,
              textSize: isCompact
                  ? AppCache.compactMessageTextSize.value!
                  : provider.textSize,
              isCompactMode: isCompact,
            ),
          ],
        ),
      ),
    );
  }
}

class _HotKeySection extends StatefulWidget {
  const _HotKeySection({super.key});

  @override
  State<_HotKeySection> createState() => _HotKeySectionState();
}

class _HotKeySectionState extends State<_HotKeySection> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hotkeys', style: FluentTheme.of(context).typography.subtitle),
        spacer,
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            Button(
              onPressed: () async {
                final key = await KeybindingDialog.show(
                  context,
                  initHotkey: openWindowHotkey,
                  title: const Text('Open the window keybinding'),
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
                  const Text('Open the window'),
                  const SizedBox(width: 10.0),
                  HotKeyVirtualView(hotKey: openWindowHotkey),
                ],
              ),
            ),
            Button(
              onPressed: () async {
                final key = await KeybindingDialog.show(
                  context,
                  initHotkey: takeScreenshot,
                  title: const Text('Take a screenshot keybinding'),
                );
                final wasRegistered = HotKeyManager
                    .instance.registeredHotKeyList
                    .any((element) => element == key);
                if (key != null && key != takeScreenshot) {
                  setState(() {
                    takeScreenshot = key;
                  });
                  if (!wasRegistered) {
                    await HotKeyManager.instance.unregister(key);
                  }
                  await AppCache.takeScreenshotKey
                      .set(jsonEncode(key.toJson()));
                  initShortcuts();
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Use visual AI'),
                  const SizedBox(width: 10.0),
                  if (takeScreenshot != null)
                    HotKeyVirtualView(hotKey: takeScreenshot!)
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Text('[Not set]'),
                    ),
                ],
              ),
            ),
            Button(
              onPressed: () async {
                final key = await KeybindingDialog.show(
                  context,
                  initHotkey: pttScreenshotKey,
                  title: const Text('Push-to-talk with screenshot'),
                );
                final wasRegistered = HotKeyManager
                    .instance.registeredHotKeyList
                    .any((element) => element == key);
                if (key != null && key != pttScreenshotKey) {
                  setState(() {
                    pttScreenshotKey = key;
                  });
                  if (!wasRegistered) {
                    await HotKeyManager.instance.unregister(key);
                  }
                  await AppCache.pttScreenshotKey.set(jsonEncode(key.toJson()));
                  initShortcuts();
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Push-to-talk with screenshot'),
                  const SizedBox(width: 10.0),
                  if (pttScreenshotKey != null)
                    HotKeyVirtualView(hotKey: pttScreenshotKey!)
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Text('[Not set]'),
                    ),
                ],
              ),
            ),
            Button(
              onPressed: () async {
                final key = await KeybindingDialog.show(
                  context,
                  initHotkey: pttKey,
                  title: const Text('Push-to-talk'),
                );
                final wasRegistered = HotKeyManager
                    .instance.registeredHotKeyList
                    .any((element) => element == key);
                if (key != null && key != pttKey) {
                  setState(() {
                    pttKey = key;
                  });
                  if (!wasRegistered) {
                    await HotKeyManager.instance.unregister(key);
                  }
                  await AppCache.pttKey.set(jsonEncode(key.toJson()));
                  initShortcuts();
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Push-to-talk'),
                  const SizedBox(width: 10.0),
                  if (pttKey != null)
                    HotKeyVirtualView(hotKey: pttKey!)
                  else
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Text('[Not set]'),
                    ),
                ],
              ),
            ),
            Button(
                child: const Text('Show all keybindings'),
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
                                    child:
                                        Icon(FluentIcons.arrow_left_20_filled),
                                  ),
                                ),
                              ),
                              const Expanded(child: WelcomeShortcutsHelper()),
                            ],
                          )));
                }),
          ],
        ),
        spacer,
      ],
    );
  }
}

// const supportedLocales = FluentLocalizations.supportedLocales;
const supportedLocales = [
  Locale('en'),
];
const gptLocales = [
  Locale('en'),
  Locale('ru'),
  Locale('uk'),
  Locale('es'),
  Locale('fr'),
  Locale('de'),
  Locale('it'),
  Locale('ja'),
  Locale('ko'),
  Locale('pt'),
  Locale('zh'),
];

class _LocaleSection extends StatelessWidget {
  const _LocaleSection({super.key});

  @override
  Widget build(BuildContext context) {
    final appTheme = context.watch<AppTheme>();

    final currentLocale =
        appTheme.locale ?? Localizations.maybeLocaleOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Locale', style: FluentTheme.of(context).typography.subtitle),
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
                  }
                },
                content: Text('$locale'),
              );
            },
          ),
        ),
        spacer,
        Text('GPT Locale', style: FluentTheme.of(context).typography.subtitle),
        const CaptionText('Language LLM will use to generate answers'),
        spacer,
        DropDownButton(
          leading: Text(defaultGPTLanguage.value),
          items: gptLocales.map((locale) {
            return MenuFlyoutItem(
              selected: defaultGPTLanguage.value == locale.languageCode,
              onPressed: () {
                defaultGPTLanguage.add(locale.languageCode);
                appTheme.updateUI();
              },
              text: Text('$locale'),
            );
          }).toList(),
        ),
        Text('Speech Language',
            style: FluentTheme.of(context).typography.subtitle),
        const CaptionText(
            'Language you are using to talk to the AI (Used in Speech to Text)'),
        spacer,
        DropDownButton(
          leading: Text(AppCache.speechLanguage.value!),
          items: gptLocales.map((locale) {
            return MenuFlyoutItem(
              selected: AppCache.speechLanguage.value == locale.languageCode,
              onPressed: () {
                AppCache.speechLanguage.value = locale.languageCode;
                appTheme.updateUI();
              },
              text: Text('$locale'),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ThemeModeSection extends StatelessWidget {
  const _ThemeModeSection({super.key});
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
                  FluentIcons.checkmark_20_filled,
                  color: color.basedOnLuminance(),
                  size: 22.0,
                )
              : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = context.watch<AppTheme>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Accent Color',
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
        Text('Theme mode', style: FluentTheme.of(context).typography.subtitle),
        spacer,
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: 8.0),
          child: RadioButton(
            checked: appTheme.mode == ThemeMode.light,
            onChanged: (value) {
              if (value) {
                appTheme.mode = ThemeMode.light;
                appTheme.setEffect(appTheme.windowEffect);
              }
            },
            content: const Text('Light'),
          ),
        ),
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: 8.0),
          child: RadioButton(
            checked: appTheme.mode == ThemeMode.dark,
            onChanged: (value) {
              if (value) {
                appTheme.mode = ThemeMode.dark;
                appTheme.setEffect(appTheme.windowEffect);
              }
            },
            content: const Text('Dark'),
          ),
        ),
        Text('Background', style: FluentTheme.of(context).typography.subtitle),
        spacer,
        Wrap(
          spacing: 8.0,
          children: [
            if (!Platform.isLinux)
              Checkbox(
                content: const Text('Use aero'),
                checked: appTheme.windowEffect == WindowEffect.aero,
                onChanged: (value) {
                  if (value == true) {
                    appTheme.windowEffectOpacity = 0.0;
                    appTheme.windowEffectColor = Colors.blue;
                    appTheme.setEffect(WindowEffect.aero);
                  } else {
                    appTheme.windowEffectOpacity = 0.0;
                    appTheme.setEffect(WindowEffect.disabled);
                  }
                },
              ),
            if (!Platform.isLinux)
              Checkbox(
                content: const Text('Use acrylic'),
                checked: appTheme.windowEffect == WindowEffect.acrylic,
                onChanged: (value) {
                  if (value == true) {
                    appTheme.windowEffectOpacity = 0.0;
                    appTheme.windowEffectColor = appTheme.color;
                    appTheme.setEffect(WindowEffect.acrylic);
                  } else {
                    appTheme.windowEffectOpacity = 0.0;
                    appTheme.setEffect(WindowEffect.disabled);
                  }
                },
              ),
            Checkbox(
              content: const Text('Use transparent'),
              checked: appTheme.windowEffect == WindowEffect.transparent,
              onChanged: (value) {
                if (value == true) {
                  appTheme.windowEffectOpacity = 0.0;
                  appTheme.windowEffectColor = Colors.transparent;
                  appTheme.setEffect(WindowEffect.transparent);
                } else {
                  appTheme.windowEffectOpacity = 0.0;
                  appTheme.setEffect(WindowEffect.disabled);
                }
              },
            ),
            Checkbox(
              content: const Text('Use mica'),
              checked: appTheme.windowEffect == WindowEffect.mica,
              onChanged: (value) {
                if (value == true) {
                  appTheme.windowEffectOpacity = 0.7;
                  appTheme.windowEffectColor = Colors.blue;
                  appTheme.setEffect(WindowEffect.mica);
                } else {
                  appTheme.windowEffectOpacity = 0.0;
                  appTheme.setEffect(WindowEffect.disabled);
                }
              },
            ),
          ],
        ),
        spacer,
        if (appTheme.windowEffect != WindowEffect.disabled) ...[
          Text('Transparency',
              style: FluentTheme.of(context).typography.subtitle),
          spacer,
          SliderStatefull(
            initValue: appTheme.windowEffectOpacity,
            onChangeEnd: (value) {
              appTheme.windowEffectOpacity = value;
              appTheme.setEffect(appTheme.windowEffect);
            },
            label: 'Opacity',
            min: 0.0,
            max: 1.0,
            divisions: 100,
            onChanged: (_) {},
          ),
          spacer,
        ],
        Checkbox(
          content: const Text('Set window as frameless'),
          checked: AppCache.frameless.value,
          onChanged: (value) {
            appTheme.setAsFrameless(value);
            if (value == false) {
              displayInfoBar(context,
                  builder: (context, _) => const InfoBar(
                        title: Text('Restart the app to apply changes'),
                        severity: InfoBarSeverity.warning,
                      ));
            }
          },
        ),
      ],
    );
  }
}

class SliderStatefull extends StatefulWidget {
  const SliderStatefull({
    super.key,
    required this.initValue,
    required this.onChanged,
    this.label,
    this.min = 0.0,
    this.max = 100.0,
    this.divisions = 100,
    this.onChangeEnd,
  });
  final double initValue;
  final void Function(double value) onChanged;
  final void Function(double value)? onChangeEnd;
  final String? label;
  final double min;
  final double max;
  final int divisions;

  @override
  State<SliderStatefull> createState() => _SliderStatefullState();
}

class _SliderStatefullState extends State<SliderStatefull> {
  double _value = 0.0;
  @override
  void initState() {
    super.initState();
    _value = widget.initValue;
  }

  @override
  Widget build(BuildContext context) {
    return Slider(
      value: _value,
      label: widget.label == null ? '$_value' : '${widget.label!}: $_value',
      min: widget.min,
      max: widget.max,
      divisions: widget.divisions,
      onChangeEnd: (value) {
        widget.onChangeEnd?.call(value);
      },
      onChanged: (value) {
        setState(() {
          _value = value;
        });
        widget.onChanged.call(value);
      },
    );
  }
}

class _CacheSection extends StatefulWidget {
  const _CacheSection({super.key});

  @override
  State<_CacheSection> createState() => __CacheSectionState();
}

class __CacheSectionState extends State<_CacheSection> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Cache', style: FluentTheme.of(context).typography.subtitle),
        const SizedBox(height: 10.0),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.start,
          spacing: 15.0,
          children: [
            Button(
                child: const Text('Delete all chat rooms'),
                onPressed: () => ConfirmationDialog(
                      isDelete: true,
                      onAcceptPressed: () {
                        context.read<ChatProvider>().deleteAllChatRooms();
                      },
                    )),
            Button(
                child: const Text('Delete total costs cache'),
                onPressed: () {
                  AppCache.costTotal.value = 0.0;
                  AppCache.tokensUsedTotal.value = 0;
                }),
            FilledRedButton(
                child: const Text('Clear all data'),
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
            FutureBuilder(
              future: ShellDriver.calcTempFilesSize(),
              builder: (context, snapshot) {
                if (snapshot.data is int) {
                  final size = snapshot.data as int;
                  String formattedSize = '0';
                  if (size > 1024 * 1024) {
                    formattedSize =
                        '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
                  } else if (size > 1024) {
                    formattedSize = '${(size / 1024).toStringAsFixed(2)} KB';
                  } else {
                    formattedSize = '$formattedSize B';
                  }
                  return Button(
                    onPressed: () async {
                      await ShellDriver.deleteAllTempFiles();
                      setState(() {});
                    },
                    child: Text('Temp files size: $formattedSize'),
                  );
                }
                return Button(
                  onPressed: () {
                    setState(() {});
                  },
                  child: const Text('Calculating temp files size...'),
                );
              },
            )
          ],
        )
      ],
    );
  }
}
