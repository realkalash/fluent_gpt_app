import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/providers/chat_provider.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:fluent_gpt/utils/custom_spellcheck_service.dart';
import 'package:fluent_gpt/widgets/input_field/additional_btns_input_field.dart';
import 'package:fluent_gpt/widgets/input_field/input_field.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart' as ic;
import 'package:provider/provider.dart';
import 'package:spell_check_on_client/spell_check_on_client.dart';

class InputFieldMini extends StatelessWidget {
  const InputFieldMini({super.key, required this.onSubmit});
  final Function(String) onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            IconButton(
              // visualDensity: VisualDensity.compact,
              icon: const Icon(ic.FluentIcons.chat_add_20_filled),
              onPressed: () {
                // if messages are not empty
                if (messages.value.isEmpty) return;
                onTrayButtonTapCommand('', TrayCommand.create_new_chat.name);
              },
            ),
            const AddFileButton(isMini: true),
            const ChooseModelButton(),
          ],
        ),
        Expanded(
            child: Selector<ChatProvider, SpellCheck?>(
          selector: (context, chatProvider) => chatProvider.spellCheck,
          builder: (context, spellCheck, child) {
            return TextBox(
              key: ValueKey(spellCheck),
              autofocus: true,
              autocorrect: true,
              focusNode: promptTextFocusNode,
              prefixMode: OverlayVisibilityMode.always,
              suffix: const MicrophoneButton(),
              controller: ChatProvider.messageControllerGlobal,
              expands: false,
              minLines: 2,
              maxLines: 30,
              spellCheckConfiguration: CustomSpellCheckService.getSpellCheckConfiguration(spellCheck),
              textInputAction: TextInputAction.done,
              onSubmitted: (value) => onSubmit(value),
              placeholder: 'Use "/" or type your message here'.tr,
            );
          },
        ))
      ],
    );
  }
}
