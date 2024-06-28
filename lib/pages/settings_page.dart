import 'package:chat_gpt_sdk/chat_gpt_sdk.dart';
import 'package:chatgpt_windows_flutter_app/common/chat_room.dart';
import 'package:chatgpt_windows_flutter_app/common/prefs/app_cache.dart';
import 'package:chatgpt_windows_flutter_app/main.dart';
import 'package:chatgpt_windows_flutter_app/providers/chat_gpt_provider.dart';
import 'package:chatgpt_windows_flutter_app/shell_driver.dart';
import 'package:chatgpt_windows_flutter_app/tray.dart';
import 'package:chatgpt_windows_flutter_app/widgets/page.dart';
import 'package:chatgpt_windows_flutter_app/widgets/wiget_constants.dart';
import 'package:flutter/foundation.dart';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:provider/provider.dart';
import 'package:system_tray/system_tray.dart';

import '../theme.dart';
import 'home_page.dart';

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
        const EnabledGptTools(),
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
    final gptProvider = context.watch<ChatGPTProvider>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Resolution', style: FluentTheme.of(context).typography.subtitle),
        spacer,
        SizedBox(
          width: 200.0,
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
        const MessageSamplePreviewCard(),
      ],
    );
  }
}

class MessageSamplePreviewCard extends StatelessWidget {
  const MessageSamplePreviewCard({super.key});

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
              textSize: provider.textSize,
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
  bool isChoosingHotkey = false;

  @override
  Widget build(BuildContext context) {
    // ignore: unused_local_variable
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
                            // print('onHotKeyRecorded: $v');

                            /// if escape is pressed, the value will be null
                            if (v.physicalKey == PhysicalKeyboardKey.escape) {
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

    // const supportedLocales = FluentLocalizations.supportedLocales;
    const supportedLocales = [Locale('en')];
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
            Button(
                child: const Text('Clear all data'),
                onPressed: () async {
                  await ShellDriver.deleteAllTempFiles();
                  await prefs!.clear();

                  /// info to show restart the app banner
                  // ignore: use_build_context_synchronously
                  // showSnackbar(
                  //     context, const InfoBar(title: Text('Restart the app')));
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
