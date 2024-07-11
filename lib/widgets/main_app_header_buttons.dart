import 'package:chatgpt_windows_flutter_app/common/prefs/app_cache.dart';
import 'package:chatgpt_windows_flutter_app/overlay_manager.dart';
import 'package:chatgpt_windows_flutter_app/providers/chat_gpt_provider.dart';
import 'package:chatgpt_windows_flutter_app/theme.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:provider/provider.dart';
import 'package:system_tray/system_tray.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as icons;
import 'package:window_manager/window_manager.dart';

class MainAppHeaderButtons extends StatelessWidget {
  const MainAppHeaderButtons({super.key});

  @override
  Widget build(BuildContext context) {
    final appTheme = context.watch<AppTheme>();
    final bool isDark = appTheme.isDark;

    return Padding(
      padding: const EdgeInsets.only(top: 6.0, right: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const AddChatButton(),
          const ClearChatButton(),
          const PinAppButton(),
          const ToggleOverlaySqueareButton(),
          const SizedBox(width: 4.0),
          ToggleButton(
            checked: isDark,
            onChanged: (v) {
              if (isDark) {
                appTheme.mode = ThemeMode.light;
                appTheme.setEffect(WindowEffect.disabled);
              } else {
                appTheme.mode = ThemeMode.dark;
                appTheme.setEffect(WindowEffect.mica);
              }
            },
            child: const Icon(
              icons.FluentIcons.weather_sunny_24_regular,
              size: 20,
            ),
          ),
          const SizedBox(width: 8.0),
          const CollapseAppButton(),
          // if (!kIsWeb) const WindowButtons(),
        ],
      ),
    );
  }
}

class EnableOverlaySqueareButton extends StatefulWidget {
  const EnableOverlaySqueareButton({super.key});

  @override
  State<EnableOverlaySqueareButton> createState() =>
      _ToggleOverlaySqueareButtonState();
}

class _ToggleOverlaySqueareButtonState
    extends State<EnableOverlaySqueareButton> {
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Show overlay on tap',
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ToggleButton(
          checked: AppCache.enableOverlay.value ?? false,
          onChanged: (v) {
            setState(() {
              AppCache.enableOverlay.value = v;
            });
          },
          child: const Icon(
            icons.FluentIcons.cursor_hover_24_regular,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class ToggleOverlaySqueareButton extends StatelessWidget {
  const ToggleOverlaySqueareButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Show overlay on tap',
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ToggleButton(
          checked: isShowingOverlay.value,
          onChanged: (v) {
            if (v == true) {
              // AppCache.windowX.set(offset.dx.toInt());
              // AppCache.windowY.set(offset.dy.toInt());
              final x = AppCache.windowX.value;
              final y = AppCache.windowY.value;
              OverlayManager.showOverlay(context,
                  positionX: x?.toDouble(), positionY: y?.toDouble());
            }
          },
          child: const Icon(
            icons.FluentIcons.cursor_hover_24_regular,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class AddChatButton extends StatelessWidget {
  const AddChatButton({super.key});

  @override
  Widget build(BuildContext context) {
    var chatProvider = context.read<ChatGPTProvider>();
    // var navProvider = context.read<NavigationProvider>();

    return Tooltip(
      message: 'Add new chat (Ctrl + T)',
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ToggleButton(
          checked: false,
          onChanged: (v) {
            chatProvider.createNewChatRoom();
            // navProvider.refreshNavItems(chatProvider);
          },
          child: const Icon(
            icons.FluentIcons.add_24_regular,
            size: 20,
          ),
        ),
      ),
    );
  }
}

class ClearChatButton extends StatelessWidget {
  const ClearChatButton({super.key});

  @override
  Widget build(BuildContext context) {
    var chatProvider = context.read<ChatGPTProvider>();

    return Tooltip(
      message: 'Clear conversation (Ctrl + R)',
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ToggleButton(
          checked: false,
          child: const Icon(
            icons.FluentIcons.arrow_counterclockwise_24_regular,
            size: 20,
          ),
          onChanged: (v) {
            chatProvider.clearConversation();
          },
        ),
      ),
    );
  }
}

class PinAppButton extends StatelessWidget {
  const PinAppButton({super.key});

  @override
  Widget build(BuildContext context) {
    var appTheme = context.watch<AppTheme>();

    return Tooltip(
      message: appTheme.isPinned ? 'Unpin window' : 'Pin window',
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ToggleButton(
          checked: appTheme.isPinned,
          onChanged: (v) => appTheme.togglePinMode(),
          child: appTheme.isPinned
              ? const Icon(
                  icons.FluentIcons.pin_off_24_regular,
                  size: 20,
                )
              : const Icon(
                  icons.FluentIcons.pin_24_regular,
                  size: 20,
                ),
        ),
      ),
    );
  }
}

class CollapseAppButton extends StatelessWidget {
  const CollapseAppButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Hide window',
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ToggleButton(
          semanticLabel: 'Collapse',
          checked: false,
          onChanged: (v) {
            AppWindow().hide();
          },
          child: const Icon(
            FluentIcons.chrome_close,
            size: 20,
          ),
        ),
      ),
    );
  }
}
