import 'package:chatgpt_windows_flutter_app/navigation_provider.dart';
import 'package:chatgpt_windows_flutter_app/pages/home_page.dart';
import 'package:chatgpt_windows_flutter_app/theme.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

class AddChatButton extends StatelessWidget {
  const AddChatButton({super.key});

  @override
  Widget build(BuildContext context) {
    var chatProvider = context.read<ChatGPTProvider>();
    var navProvider = context.read<NavigationProvider>();

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: ToggleButton(
        checked: false,
        onChanged: (v) {
          chatProvider.createNewChatRoom();
          navProvider.refreshNavItems(chatProvider);
        },
        child: const Icon(FluentIcons.add),
      ),
    );
  }
}

class ClearChatButton extends StatelessWidget {
  const ClearChatButton({super.key});

  @override
  Widget build(BuildContext context) {
    var chatProvider = context.read<ChatGPTProvider>();

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: ToggleButton(
        checked: false,
        child: const Icon(FluentIcons.update_restore),
        onChanged: (v) {
          chatProvider.clearConversation();
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

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: ToggleButton(
        checked: appTheme.isPinned,
        onChanged: (v) {
          appTheme.togglePinMode();
        },
        child: appTheme.isPinned
            ? const Icon(FluentIcons.pinned)
            : const Icon(FluentIcons.pin),
      ),
    );
  }
}
