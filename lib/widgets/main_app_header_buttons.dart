import 'dart:io';

import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/pages/new_settings_page.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/providers/server_provider.dart';
import 'package:fluent_gpt/theme.dart';
import 'package:fluent_gpt/widgets/markdown_builders/code_wrapper.dart';
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

    return Focus(
      canRequestFocus: false,
      descendantsAreFocusable: false,
      descendantsAreTraversable: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 6.0, right: 16),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const ServerInitializingIcon(),
            const RevertMessageHeaderButton(),
            const AddChatButton(),
            const ClearChatButton(),
            SizedBox(width: 8.0),
            if (AppCache.enableOverlay.value == true) const ToggleOverlaySqueareButton(),

            const SizedBox(width: 4.0),
            const PinAppButton(),
            Tooltip(
              message: 'Theme'.tr,
              child: ToggleButton(
                checked: isDark,
                onChanged: (v) {
                  if (isDark) {
                    appTheme.applyLightTheme();
                  } else {
                    appTheme.applyDarkTheme();
                  }
                },
                child: const Icon(
                  icons.FluentIcons.weather_sunny_24_regular,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            Tooltip(
              message: 'Settings'.tr,
              child: ToggleButton(
                checked: false,
                onChanged: (_) {
                  Navigator.of(context).push(
                    FluentPageRoute(builder: (context) => const NewSettingsPage()),
                  );
                },
                child: const Icon(
                  icons.FluentIcons.settings_24_regular,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8.0),
            const CollapseAppButton(),
            // if (!kIsWeb) const WindowButtons(),
          ],
        ),
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
        child: ToggleButton(
          checked: false,
          onChanged: (v) => chatProvider.revertDeletedMessage(),
          child: const Icon(
            icons.FluentIcons.arrow_undo_24_regular,
            size: 20,
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
  State<EnableOverlaySqueareButton> createState() => _ToggleOverlaySqueareButtonState();
}

class _ToggleOverlaySqueareButtonState extends State<EnableOverlaySqueareButton> {
  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Show overlay on tap',
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
    );
  }
}

class ToggleOverlaySqueareButton extends StatelessWidget {
  const ToggleOverlaySqueareButton({super.key});
  static const double _height = 16;
  static const double _width = 48;
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SqueareIconButtonSized(
          height: _height,
          width: _width,
          onTap: () {
            AppCache.enableOverlay.value = true;
            OverlayManager.showOverlay(context);
          },
          icon: const Icon(icons.FluentIcons.cursor_hover_24_regular, size: 16),
          tooltip: 'Switch to overlay'.tr,
        ),
        const SizedBox(height: 1),
        SqueareIconButtonSized(
          height: _height,
          width: _width,
          tooltip: 'Switch to sidebar'.tr,
          onTap: () {
            if (AppCache.enableOverlay.value == false) {
              AppCache.enableOverlay.value = true;
            }
            OverlayManager.showSidebarOverlay(context);
          },
          icon: const Icon(icons.FluentIcons.panel_right_32_filled, size: _height),
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
      message: 'Add new chat (Ctrl + T)'.tr,
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
      message: 'Clear conversation (Ctrl + R)'.tr,
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
    );
  }
}

class PinAppButton extends StatelessWidget {
  const PinAppButton({super.key});

  @override
  Widget build(BuildContext context) {
    var appTheme = context.watch<AppTheme>();

    return Tooltip(
      message: appTheme.isPinned ? 'Unpin window'.tr : 'Pin window'.tr,
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
      message: Platform.isLinux ? 'Close window'.tr : 'Collapse'.tr,
      child: Padding(
        padding: const EdgeInsets.all(4.0),
        child: ToggleButton(
          semanticLabel: 'Close window'.tr,
          checked: false,
          onChanged: (v) {
            if (Platform.isLinux) {
              windowManager.close();
              return;
            }
            windowManager.hide();
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

class ServerInitializingIcon extends StatelessWidget {
  const ServerInitializingIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder(
      stream: ServerProvider.isInitializingStreamController.stream,
      builder: (context, snapshot) {
        bool isInitializing = snapshot.data ?? false;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 1000),
          child: isInitializing
              ? DecoratedBox(
                  key: Key('starting-server'),
                  decoration: BoxDecoration(
                    color: Colors.green.withAlpha(86),
                    borderRadius: const BorderRadius.all(Radius.circular(12)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'Starting server',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}
