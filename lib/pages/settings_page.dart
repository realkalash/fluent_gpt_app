import 'dart:convert';
import 'dart:io';

import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:fluent_gpt/common/chat_room.dart';
import 'package:fluent_gpt/common/custom_prompt.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/main.dart';
import 'package:fluent_gpt/native_channels.dart';
import 'package:fluent_gpt/navigation_provider.dart';
import 'package:fluent_gpt/pages/prompts_settings_page.dart';
import 'package:fluent_gpt/pages/welcome/welcome_shortcuts_helper_screen.dart';
import 'package:fluent_gpt/providers/chat_gpt_provider.dart';
import 'package:fluent_gpt/shell_driver.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/custom_buttons.dart';
import 'package:fluent_gpt/widgets/keybinding_dialog.dart';
import 'package:fluent_gpt/widgets/message_list_tile.dart';
import 'package:fluent_gpt/widgets/page.dart';
import 'package:fluent_gpt/widgets/wiget_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:provider/provider.dart';
import 'package:system_tray/system_tray.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:window_manager/window_manager.dart';

import '../theme.dart';
import '../widgets/confirmation_dialog.dart';

class GptModelChooser extends StatefulWidget {
  const GptModelChooser({super.key, required this.onChanged});

  final void Function(ChatModel model) onChanged;

  @override
  State<GptModelChooser> createState() => _GptModelChooserState();
}

class _GptModelChooserState extends State<GptModelChooser> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String>(
        stream: selectedChatRoomNameStream,
        builder: (context, snapshot) {
          return Wrap(
            spacing: 15.0,
            runSpacing: 10.0,
            children: List.generate(
              allModels.length,
              (index) {
                final model = allModels[index];

                return Padding(
                  padding: const EdgeInsetsDirectional.only(bottom: 8.0),
                  child: RadioButton(
                    checked: selectedModel.model == model.model,
                    onChanged: (value) {
                      if (value) {
                        setState(() {
                          widget.onChanged.call(model);
                        });
                      }
                    },
                    content: Text(model.model),
                  ),
                );
              },
            ),
          );
        });
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with PageMixin {
  @override
  Widget build(BuildContext context) {
    final canGoBack = Navigator.of(context).canPop();
    return ScaffoldPage.scrollable(
      header: PageHeader(
          title: const Text('Settings'),
          leading: canGoBack
              ? IconButton(
                  icon: const Icon(FluentIcons.back),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null),
      children: [
        const EnabledGptTools(),
        const OverlaySettings(),
        const _FilesSection(),
        const AccessibilityPermissionButton(),
        const _CacheSection(),
        if (kDebugMode) const _DebugSection(),
        const _HotKeySection(),
        const CustomPromptsButton(),
        Text('Appearance', style: FluentTheme.of(context).typography.title),
        const _ThemeModeSection(),
        spacer,
        const _WindowTitleButton(),
        // biggerSpacer,
        // const _LocaleSection(),
        const _ResolutionsSelector(),
        const _LocaleSection(),
        biggerSpacer,
        const _OtherSettings(),
      ],
    );
  }
}

class _WindowTitleButton extends StatefulWidget {
  const _WindowTitleButton({super.key});

  @override
  State<_WindowTitleButton> createState() => _WindowTitleButtonState();
}

class _WindowTitleButtonState extends State<_WindowTitleButton> {
  toggleTitleBarVisibility() {
    setState(() {
      AppCache.hideTitleBar.value = !AppCache.hideTitleBar.value!;
    });
    if (AppCache.hideTitleBar.value == true) {
      windowManager.setTitleBarStyle(TitleBarStyle.hidden,
          windowButtonVisibility: false);
    } else {
      windowManager.setTitleBarStyle(TitleBarStyle.normal,
          windowButtonVisibility: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FlyoutListTile(
      text: const Text('Hide window title'),
      tooltip: Platform.isWindows
          ? 'Will disable acrylic effect due to a bug'
          : null,
      icon: Platform.isWindows
          ? Icon(FluentIcons.warning, color: Colors.yellow)
          : null,
      onPressed: toggleTitleBarVisibility,
      trailing: Checkbox(
        checked: AppCache.hideTitleBar.value,
        onChanged: (value) => toggleTitleBarVisibility(),
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
        Text('Custom prompts',
            style: FluentTheme.of(context).typography.subtitle),
        spacer,
        Button(
          child: const Text('Customize custom prompts'),
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
        FlyoutListTile(
          text: const Text('Enable overlay'),
          trailing: Checkbox(
            checked: AppCache.enableOverlay.value,
            onChanged: (value) {
              setState(() {
                AppCache.enableOverlay.value = value;
              });
            },
          ),
        ),
        FlyoutListTile(
          text: const Text('Show settings icon in overlay'),
          trailing: Checkbox(
            checked: AppCache.showSettingsInOverlay.value,
            onChanged: (value) {
              setState(() {
                AppCache.showSettingsInOverlay.value = value;
              });
            },
          ),
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
        Text('compactMessageTextSize',
            style: FluentTheme.of(context).typography.subtitle),
        spacer,
        NumberBox(
          value: AppCache.compactMessageTextSize.value,
          onChanged: (value) {
            AppCache.compactMessageTextSize.value = value ?? 10;
            Provider.of<ChatGPTProvider>(context, listen: false).updateUI();
          },
          mode: SpinButtonPlacementMode.inline,
        ),
        const MessageSamplePreviewCard(isCompact: true),
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
                  Icon(FluentIcons.check_mark, color: Colors.green)
                else
                  Icon(FluentIcons.clear, color: Colors.red)
              ],
            ),
          );
        }
        return const Text('Checking accessibility status...');
      },
    );
  }
}

class EnabledGptTools extends StatefulWidget {
  const EnabledGptTools({super.key});

  @override
  State<EnabledGptTools> createState() => _EnabledGptToolsState();
}

class _EnabledGptToolsState extends State<EnabledGptTools> {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Enabled GPT tools',
            style: FluentTheme.of(context).typography.subtitle),
        Wrap(
          children: [
            if (Platform.isWindows)
              FlyoutListTile(
                text: const Text('Search files'),
                trailing: Checkbox(
                  checked: AppCache.gptToolSearchEnabled.value!,
                  onChanged: (value) {
                    setState(() {
                      AppCache.gptToolSearchEnabled.value = value;
                    });
                  },
                ),
              ),
            FlyoutListTile(
              text: const Text('Auto copy to clipboard'),
              trailing: Checkbox(
                checked: AppCache.gptToolCopyToClipboardEnabled.value!,
                onChanged: (value) {
                  setState(() {
                    AppCache.gptToolCopyToClipboardEnabled.value = value;
                  });
                },
              ),
            ),
            FlyoutListTile(
              text: const Text('Run python code'),
              trailing: Checkbox(
                checked: AppCache.gptToolPythonEnabled.value!,
                onChanged: (value) {
                  setState(() {
                    AppCache.gptToolPythonEnabled.value = value;
                  });
                },
              ),
            ),
            biggerSpacer,
          ],
        ),
      ],
    );
  }
}

class _FilesSection extends StatefulWidget {
  const _FilesSection({super.key});

  @override
  State<_FilesSection> createState() => _FilesSectionState();
}

class _FilesSectionState extends State<_FilesSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      final provider = context.read<ChatGPTProvider>();
      provider.retrieveFiles();
    });
  }

  @override
  Widget build(BuildContext context) {
    final gptProvider = context.watch<ChatGPTProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Files', style: FluentTheme.of(context).typography.subtitle),
            IconButton(
              icon: const Icon(FluentIcons.refresh),
              onPressed: () {
                gptProvider.retrieveFiles();
              },
            ),
          ],
        ),
        spacer,
        if (gptProvider.isRetrievingFiles)
          const Center(child: ProgressBar())
        else
          Wrap(
            spacing: 15.0,
            runSpacing: 10.0,
            children: List.generate(
              gptProvider.filesInOpenAi.length,
              (index) {
                final file = gptProvider.filesInOpenAi[index];
                return Button(
                  onPressed: () {
                    // gptProvider.downloadOpenFile(file);
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${file.filename} (${file.bytes ~/ 1024} KB)'),
                      IconButton(
                        icon: const Icon(FluentIcons.delete),
                        onPressed: () {
                          gptProvider.deleteFileFromOpenAi(file);
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _OtherSettings extends StatelessWidget {
  const _OtherSettings({super.key});

  @override
  Widget build(BuildContext context) {
    final appTheme = context.watch<AppTheme>();
    final gptProvider = context.watch<ChatGPTProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Other settings',
            style: FluentTheme.of(context).typography.subtitle),
        spacer,
        FlyoutListTile(
          text: const Text('Prevent close app'),
          trailing: Checkbox(
            checked: appTheme.preventClose,
            onChanged: (value) => appTheme.togglePreventClose(),
          ),
        ),
        FlyoutListTile(
          text: const Text('Show in dock'),
          trailing: Checkbox(
              checked: AppCache.showAppInDock.value == true,
              onChanged: (value) {
                appTheme.toggleShowInDock();
              }),
        ),
        FlyoutListTile(
          text: const Text('Use second request for naming chats'),
          tooltip: 'Can cause additional charges!',
          trailing: Checkbox(
            checked: gptProvider.useSecondRequestForNamingChats,
            onChanged: (value) =>
                gptProvider.toggleUseSecondRequestForNamingChats(),
          ),
        ),
      ],
    );
  }
}

class _ResolutionsSelector extends StatelessWidget {
  const _ResolutionsSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final appTheme = context.watch<AppTheme>();
    final gptProvider = context.watch<ChatGPTProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          title: const Text('Resolution'),
          subtitle: Text(
              '${appTheme.resolution?.width}x${appTheme.resolution?.height}'),
          trailing: kDebugMode
              ? IconButton(
                  icon: const Icon(FluentIcons.delete),
                  onPressed: () async {
                    await AppCache.resolution.remove();
                  })
              : null,
        ),
        const SizedBox(height: 8.0),
        Text('Text size', style: FluentTheme.of(context).typography.subtitle),
        spacer,
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
    );
  }
}

class MessageSamplePreviewCard extends StatelessWidget {
  const MessageSamplePreviewCard({super.key, required this.isCompact});
  final bool isCompact;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ChatGPTProvider>();
    return Container(
      padding: const EdgeInsets.all(16.0),
      child: Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Message sample preview'),
            MessageCard(
              message: const {
                'content':
                    '''Hello, how are you doing today?\nI'm doing great, thank you for asking. I'm here to help you with anything you need.''',
                'role': 'user',
              },
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
          spacing: 12,
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
                  initShortcuts(AppWindow());
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
                                    child: Icon(FluentIcons.page_left),
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

class _LocaleSection extends StatelessWidget {
  const _LocaleSection({super.key});

  @override
  Widget build(BuildContext context) {
    final appTheme = context.watch<AppTheme>();

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
        spacer,
        Wrap(
          spacing: 15.0,
          runSpacing: 10.0,
          children: List.generate(
            gptLocales.length,
            (index) {
              final locale = gptLocales[index];
              return RadioButton(
                checked: defaultGPTLanguage.value == locale.languageCode,
                onChanged: (value) {
                  if (value) {
                    defaultGPTLanguage.add(locale.languageCode);
                    appTheme.updateUI();
                  }
                },
                content: Text('$locale'),
              );
            },
          ),
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
          padding: ButtonState.all(EdgeInsets.zero),
          backgroundColor: ButtonState.resolveWith((states) {
            if (states.isPressing) {
              return color.light;
            } else if (states.isHovering) {
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
                  FluentIcons.check_mark,
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
        Text('Theme mode', style: FluentTheme.of(context).typography.subtitle),
        spacer,
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: 8.0),
          child: RadioButton(
            checked: appTheme.mode == ThemeMode.light,
            onChanged: (value) {
              if (value) {
                appTheme.mode = ThemeMode.light;

                if (kIsWindowEffectsSupported) {
                  // some window effects require on [dark] to look good.
                  // appTheme.setEffect(WindowEffect.disabled, context);
                  appTheme.setEffect(appTheme.windowEffect);
                }
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

                if (kIsWindowEffectsSupported) {
                  // some window effects require on [dark] to look good.
                  // appTheme.setEffect(WindowEffect.disabled, context);
                  appTheme.setEffect(appTheme.windowEffect);
                }
              }
            },
            content: const Text('Dark'),
          ),
        ),
        biggerSpacer,
        Text(
          'Navigation Pane Display Mode',
          style: FluentTheme.of(context).typography.subtitle,
        ),
        spacer,
        ...List.generate(PaneDisplayMode.values.length, (index) {
          final mode = PaneDisplayMode.values[index];
          return Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 8.0),
            child: RadioButton(
              checked: appTheme.displayMode == mode,
              onChanged: (value) {
                if (value) appTheme.displayMode = mode;
              },
              content: Text(
                mode.toString().replaceAll('PaneDisplayMode.', ''),
              ),
            ),
          );
        }),
        biggerSpacer,
        Text('Navigation Indicator',
            style: FluentTheme.of(context).typography.subtitle),
        spacer,
        ...List.generate(NavigationIndicators.values.length, (index) {
          final mode = NavigationIndicators.values[index];
          return Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 8.0),
            child: RadioButton(
              checked: appTheme.indicator == mode,
              onChanged: (value) {
                if (value) appTheme.indicator = mode;
              },
              content: Text(
                mode.toString().replaceAll('NavigationIndicators.', ''),
              ),
            ),
          );
        }),
        biggerSpacer,
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
        biggerSpacer,
        Text('Background', style: FluentTheme.of(context).typography.subtitle),
        // background color
        spacer,
        // use solid background effect
        FlyoutListTile(
          text: const Text('Use acrylic'),
          trailing: Checkbox(
            checked: appTheme.windowEffect == WindowEffect.acrylic,
            onChanged: (value) {
              if (value == true) {
                appTheme.setEffect(WindowEffect.acrylic);
              } else {
                appTheme.windowEffectOpacity = 0.0;
                appTheme.setEffect(WindowEffect.disabled);
              }
            },
          ),
          onPressed: () {
            if (appTheme.windowEffect == WindowEffect.acrylic) {
              appTheme.setEffect(WindowEffect.disabled);
            } else {
              appTheme.windowEffectOpacity = 0.0;
              appTheme.setEffect(WindowEffect.acrylic);
            }
          },
          // selected: appTheme.windowEffect == WindowEffect.acrylic,
          // trailing: Checkbox(
          //   checked: appTheme.windowEffect == WindowEffect.acrylic,
          //   onChanged: (v) {
          //     if (v == true) {
          //       appTheme.setEffect(WindowEffect.acrylic);
          //     } else {
          //       appTheme.windowEffectOpacity = 0.0;
          //       appTheme.setEffect(WindowEffect.disabled);
          //     }
          //   },
          // ),
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
  });
  final double initValue;
  final void Function(double) onChanged;
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
                onPressed: () {
                  context.read<ChatGPTProvider>().deleteAllChatRooms();
                }),
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
