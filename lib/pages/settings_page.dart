import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_gpt/common/custom_messages/fluent_chat_message.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/dialogs/how_to_use_llm_dialog.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/log.dart';
import 'package:fluent_gpt/native_channels.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/providers/server_provider.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/custom_buttons.dart';
import 'package:fluent_gpt/widgets/markdown_builders/code_wrapper.dart';
import 'package:fluent_gpt/widgets/message_list_tile.dart';
import 'package:fluent_gpt/widgets/page.dart';
import 'package:fluent_gpt/widgets/wiget_constants.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:window_manager/window_manager.dart';

import '../theme.dart';
import 'new_settings_page.dart';

bool isLaunchAtStartupEnabled = false;

class SettingsPage extends StatefulWidget {
  @Deprecated('Use NewSettingsPage instead')
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
              title: Text('Settings'.tr),
              leading: canGoBack
                  ? IconButton(
                      icon: const Icon(FluentIcons.arrow_left_24_filled,
                          size: 24),
                      onPressed: () => Navigator.of(context).pop(),
                    )
                  : null),
        ),
        children: [
          spacer,
          const DensityModeDropdown(),
          spacer,
          const _LocaleSection(),
          spacer,
          const ServerSettings(),
        ],
      ),
    );
  }
}

class DensityModeDropdown extends StatelessWidget {
  const DensityModeDropdown({super.key});

  static const values = <String, VisualDensity>{
    'Standard': VisualDensity.standard,
    'Comfortable': VisualDensity.comfortable,
    'Compact': VisualDensity.compact,
  };

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AppTheme>();
    final currentDensity = context.theme.visualDensity;
    final name =
        values.entries.firstWhere((e) => e.value == currentDensity).key;
    return DropDownButton(
      title: Text('Density mode: $name'),
      items: [
        for (var density in values.entries)
          MenuFlyoutItem(
            selected: currentDensity == density.value,
            trailing: currentDensity == density.value
                ? const Icon(FluentIcons.checkmark_20_filled)
                : null,
            onPressed: () {
              provider.setVisualDensity(density.value);
            },
            text: Text(density.key),
          ),
      ],
    );
  }
}

class _DebugSection extends StatelessWidget {
  const _DebugSection();

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

class CheckBoxTile extends StatefulWidget {
  const CheckBoxTile({
    super.key,
    required this.isChecked,
    required this.child,
    this.onChanged,
    this.expanded = true,
  });
  final bool isChecked;
  final bool expanded;
  final Widget child;
  final void Function(bool?)? onChanged;
  @override
  State<CheckBoxTile> createState() => _CheckBoxTileState();
}

class _CheckBoxTileState extends State<CheckBoxTile> {
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
              if (widget.expanded)
                Expanded(child: widget.child)
              else
                widget.child,
            ],
          ),
        ),
      ),
    );
  }
}

class BadgePrefix extends StatelessWidget {
  const BadgePrefix(this.child, {super.key});
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

class CheckBoxTooltip extends StatelessWidget {
  const CheckBoxTooltip({
    super.key,
    required this.content,
    this.tooltip,
    required this.checked,
    required this.onChanged,
  });
  final Widget content;
  final String? tooltip;
  final bool? checked;
  final void Function(bool?) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(content: content, checked: checked, onChanged: onChanged),
        if (tooltip != null) ...[
          const SizedBox(width: 10.0),
          Tooltip(
            message: tooltip!,
            child: Icon(FluentIcons.info_16_filled),
          ),
        ],
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
      padding: const EdgeInsets.all(4.0),
      child: Card(
        child: MessageCard(
          message: FluentChatMessage.ai(
            id: '1234',
            content:
                'Hello, how are you doing today?\nI\'m doing great, thank you for asking. I\'m here to help you with anything you need.',
            timestamp: DateTime.now().millisecondsSinceEpoch,
            tokens: 1234,
          ),
          selectionMode: false,
          textSize: isCompact
              ? AppCache.compactMessageTextSize.value!
              : provider.textSize,
          isCompactMode: isCompact,
        ),
      ),
    );
  }
}

// const supportedLocales = FluentLocalizations.supportedLocales;
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
  const _LocaleSection();

  @override
  Widget build(BuildContext context) {
    final appTheme = context.watch<AppTheme>();

    final currentLocale = appTheme.locale;
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
