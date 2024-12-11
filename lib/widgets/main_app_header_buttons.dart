import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/pages/settings_page.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/theme.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
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
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const RevertMessageHeaderButton(),
          const AddChatButton(),
          const ClearChatButton(),
          const PinAppButton(),
          if (AppCache.enableOverlay.value == true)
            const ToggleOverlaySqueareButton(),
          Tooltip(
            message: 'Settings',
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: ToggleButton(
                checked: false,
                onChanged: (_) {
                  Navigator.of(context).push(
                    FluentPageRoute(builder: (context) => const SettingsPage()),
                  );
                },
                child: const Icon(
                  icons.FluentIcons.settings_24_regular,
                  size: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4.0),
          ToggleButton(
            checked: isDark,
            onChanged: (v) {
              if (isDark) {
                appTheme.mode = ThemeMode.light;
              } else {
                appTheme.mode = ThemeMode.dark;
              }
              appTheme.setEffect(appTheme.windowEffect);
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

class RevertMessageHeaderButton extends StatelessWidget {
  const RevertMessageHeaderButton({super.key});

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    if (chatProvider.lastDeletedMessage.isNotEmpty)
      return Tooltip(
        message: 'Revert deleted message',
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: ToggleButton(
            checked: false,
            onChanged: (v) => chatProvider.revertDeletedMessage(),
            child: const Icon(
              icons.FluentIcons.arrow_undo_24_regular,
              size: 20,
            ),
          ),
        ),
      );
    else {
      return const SizedBox.shrink();
    }
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'Switch to overlay',
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: ToggleButton(
              checked: overlayVisibility.value.isShowingOverlay,
              onChanged: (v) {
                if (v == true) {
                  if (AppCache.enableOverlay.value == false) {
                    AppCache.enableOverlay.value = true;
                  }
                  OverlayManager.showOverlay(context);
                }
              },
              child: const Icon(
                icons.FluentIcons.cursor_hover_24_regular,
                size: 20,
              ),
            ),
          ),
        ),
        Tooltip(
          message: 'Switch to sidebar',
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: ToggleButton(
              checked: overlayVisibility.value.isShowingSidebarOverlay,
              onChanged: (v) {
                if (v == true) {
                  if (AppCache.enableOverlay.value == false) {
                    AppCache.enableOverlay.value = true;
                  }
                  OverlayManager.showSidebarOverlay(context);
                }
              },
              child: const Icon(
                icons.FluentIcons.panel_right_32_filled,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AddChatButton extends StatelessWidget {
  const AddChatButton({super.key});

  @override
  Widget build(BuildContext context) {
    var chatProvider = context.read<ChatProvider>();
    // var navProvider = context.read<NavigationProvider>();

    return Tooltip(
      message: 'Add new chat (Ctrl + T)',
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ToggleButton(
          checked: false,
          onChanged: (v) {
            chatProvider.createNewChatRoom();
          },
          child: const Icon(
            icons.FluentIcons.compose_24_regular,
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
    var chatProvider = context.read<ChatProvider>();

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
            chatProvider.clearChatMessages();
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
          onChanged: (v) => windowManager.hide(),
          child: const Icon(
            FluentIcons.chrome_close,
            size: 20,
          ),
        ),
      ),
    );
  }
}
