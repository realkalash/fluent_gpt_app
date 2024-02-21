import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:chatgpt_windows_flutter_app/chat_room.dart';
import 'package:chatgpt_windows_flutter_app/main.dart';
import 'package:chatgpt_windows_flutter_app/providers/chat_gpt_provider.dart';
import 'package:chatgpt_windows_flutter_app/shell_driver.dart';
import 'package:chatgpt_windows_flutter_app/tray.dart';
import 'package:chatgpt_windows_flutter_app/widgets/page.dart';
import 'package:flutter/foundation.dart';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:provider/provider.dart';
import 'package:system_tray/system_tray.dart';

import '../theme.dart';

const List<String> accentColorNames = [
  'System',
  'Yellow',
  'Orange',
  'Red',
  'Magenta',
  'Purple',
  'Blue',
  'Teal',
  'Green',
];

bool get kIsWindowEffectsSupported {
  return !kIsWeb &&
      [
        TargetPlatform.windows,
        TargetPlatform.linux,
        TargetPlatform.macOS,
      ].contains(defaultTargetPlatform);
}

const _LinuxWindowEffects = [
  WindowEffect.disabled,
  WindowEffect.transparent,
];

const _WindowsWindowEffects = [
  WindowEffect.disabled,
  WindowEffect.solid,
  WindowEffect.transparent,
  WindowEffect.aero,
  WindowEffect.acrylic,
  WindowEffect.mica,
  WindowEffect.tabbed,
];

const _MacosWindowEffects = [
  WindowEffect.disabled,
  WindowEffect.titlebar,
  WindowEffect.selection,
  WindowEffect.menu,
  WindowEffect.popover,
  WindowEffect.sidebar,
  WindowEffect.headerView,
  WindowEffect.sheet,
  WindowEffect.windowBackground,
  WindowEffect.hudWindow,
  WindowEffect.fullScreenUI,
  WindowEffect.toolTip,
  WindowEffect.contentBackground,
  WindowEffect.underWindowBackground,
  WindowEffect.underPageBackground,
];

List<WindowEffect> get currentWindowEffects {
  if (kIsWeb) return [];

  if (defaultTargetPlatform == TargetPlatform.windows) {
    return _WindowsWindowEffects;
  } else if (defaultTargetPlatform == TargetPlatform.linux) {
    return _LinuxWindowEffects;
  } else if (defaultTargetPlatform == TargetPlatform.macOS) {
    return _MacosWindowEffects;
  }

  return [];
}

const spacer = SizedBox(height: 10.0);
const biggerSpacer = SizedBox(height: 40.0);

class GptModelChooser extends StatefulWidget {
  const GptModelChooser({super.key, required this.onChanged});

  final void Function(ChatModel model) onChanged;

  @override
  State<GptModelChooser> createState() => _GptModelChooserState();
}

class _GptModelChooserState extends State<GptModelChooser> {
  @override
  Widget build(BuildContext context) {
    final chatProvider = context.read<ChatGPTProvider>();
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
              checked: chatProvider.selectedModel.model == model.model,
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
    assert(debugCheckHasMediaQuery(context));

    return ScaffoldPage.scrollable(
      header: const PageHeader(title: Text('Settings')),
      children: [
        Text('GPT model', style: FluentTheme.of(context).typography.subtitle),
        GptModelChooser(
          onChanged: (model) {
            context.read<ChatGPTProvider>().selectNewModel(model);
          },
        ),
        const _FilesSection(),
        const _CacheSection(),
        const _HotKeySection(),
        const _ThemeModeSection(),
        biggerSpacer,
        const _LocaleSection(),
        biggerSpacer,
        const _ResolutionsSelector(),
        biggerSpacer,
        const _OtherSettings(),
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
    final provider = context.read<ChatGPTProvider>();
    provider.retrieveFiles();
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
                  onPressed: () => gptProvider.downloadOpenFile(file),
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
      ],
    );
  }
}

class _ResolutionsSelector extends StatelessWidget {
  const _ResolutionsSelector({super.key});
  static const resolutions = [
    /// 4k
    Size(3840, 2160),

    /// 2k
    Size(2560, 1440),

    /// 1080p
    Size(1920, 1080),

    /// 720p
    Size(1280, 720),
    Size(1024, 768),
    Size(800, 600),
    Size(640, 480),
    Size(640, 360),
    Size(480, 360),
    Size(480, 320),
    Size(320, 240),
    Size(320, 180),
  ];

  @override
  Widget build(BuildContext context) {
    final appTheme = context.watch<AppTheme>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Resolution', style: FluentTheme.of(context).typography.subtitle),
        spacer,
        Padding(
          padding: const EdgeInsetsDirectional.only(bottom: 8.0),
          child: ComboBox<Size>(
            items: resolutions.map((e) {
              final isCurrent = e == appTheme.resolution;
              final string = '${e.width}x${e.height}';
              final selectedString = '$string (current)';
              return ComboBoxItem(
                value: e,
                child: Text(isCurrent ? selectedString : string),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                appTheme.setResolution(value);
              }
            },
            value: appTheme.resolution,
            placeholder: const Text('Select a resolution'),
          ),
        ),
      ],
    );
  }
}

class _HotKeySection extends StatefulWidget {
  const _HotKeySection({super.key});

  @override
  State<_HotKeySection> createState() => _HotKeySectionState();
}

class _HotKeySectionState extends State<_HotKeySection> {
  bool isChoosingHotkey = false;

  String getKeyCodeString(HotKey hotKey) {
    final modifiers = hotKey.modifiers?.map((e) => e.keyLabel).join('') ?? '';
    return '$modifiers${hotKey.keyCode.keyLabel}';
  }

  @override
  Widget build(BuildContext context) {
    final appTheme = context.watch<AppTheme>();

    /// a button to add a new hotkey
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Hotkeys', style: FluentTheme.of(context).typography.subtitle),
        spacer,
        if (isChoosingHotkey)
          Text(
            'Press a key combination to set a new hotkey (escape to cancel)',
            style: FluentTheme.of(context).typography.caption,
          ),
        Row(
          children: [
            Button(
              onPressed: () {
                setState(() {
                  isChoosingHotkey = true;
                });
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Open the window'),
                  const SizedBox(width: 10.0),
                  isChoosingHotkey
                      ? HotKeyRecorder(
                          onHotKeyRecorded: (v) async {
                            print('onHotKeyRecorded: $v');

                            /// if escape is pressed, the value will be null
                            if (v.keyCode == KeyCode.escape) {
                              setState(() {
                                isChoosingHotkey = false;
                              });
                              return;
                            }
                            if (mounted) {
                              await hotKeyManager.unregister(openWindowHotkey);
                              setState(() {
                                openWindowHotkey = v;
                                isChoosingHotkey = false;
                              });
                              initShortcuts(AppWindow());
                            }
                          },
                          initalHotKey: openWindowHotkey,
                        )
                      : HotKeyVirtualView(hotKey: openWindowHotkey),
                ],
              ),
            ),
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

    const supportedLocales = FluentLocalizations.supportedLocales;
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

              return Padding(
                padding: const EdgeInsetsDirectional.only(bottom: 8.0),
                child: RadioButton(
                  checked: currentLocale == locale,
                  onChanged: (value) {
                    if (value) {
                      appTheme.locale = locale;
                    }
                  },
                  content: Text('$locale'),
                ),
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
        ...List.generate(ThemeMode.values.length, (index) {
          final mode = ThemeMode.values[index];
          return Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 8.0),
            child: RadioButton(
              checked: appTheme.mode == mode,
              onChanged: (value) {
                if (value) {
                  appTheme.mode = mode;

                  if (kIsWindowEffectsSupported) {
                    // some window effects require on [dark] to look good.
                    // appTheme.setEffect(WindowEffect.disabled, context);
                    appTheme.setEffect(appTheme.windowEffect, context);
                  }
                }
              },
              content: Text('$mode'.replaceAll('ThemeMode.', '')),
            ),
          );
        }),
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
        if (kIsWindowEffectsSupported) ...[
          biggerSpacer,
          Text(
            'Window Transparency (${defaultTargetPlatform.toString().replaceAll('TargetPlatform.', '')})',
            style: FluentTheme.of(context).typography.subtitle,
          ),
          spacer,
          ...List.generate(currentWindowEffects.length, (index) {
            final mode = currentWindowEffects[index];
            return Padding(
              padding: const EdgeInsetsDirectional.only(bottom: 8.0),
              child: RadioButton(
                checked: appTheme.windowEffect == mode,
                onChanged: (value) {
                  if (value) {
                    appTheme.setEffect(mode, context);
                  }
                },
                content: Text(
                  mode.toString().replaceAll('WindowEffect.', ''),
                ),
              ),
            );
          }),
        ],
      ],
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
                child: const Text('Clear all data'),
                onPressed: () async {
                  await ShellDriver.deleteAllTempFiles();
                  await prefs!.clear();

                  /// info to show restart the app banner
                  // ignore: use_build_context_synchronously
                  showSnackbar(
                      context, const InfoBar(title: Text('Restart the app')));
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
