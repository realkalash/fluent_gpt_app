import 'dart:convert';

import 'package:fluent_gpt/common/on_message_actions/on_message_action.dart';
import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluent_gpt/providers/chat_globals.dart';
import 'package:fluent_gpt/system_messages.dart';
import 'package:fluent_gpt/widgets/wiget_constants.dart';
import 'package:fluent_ui/fluent_ui.dart';

class CustomActionDialog extends StatefulWidget {
  const CustomActionDialog({super.key, this.action});
  final OnMessageAction? action;

  @override
  State<CustomActionDialog> createState() => _CustomActionDialogState();
}

class _CustomActionDialogState extends State<CustomActionDialog> {
  @override
  void initState() {
    super.initState();
    if (widget.action != null) {
      actionNameController.text = widget.action!.actionName;
      regExpController.text = widget.action!.regExp.pattern;
      action = widget.action!.actionEnum;
    }
  }

  final actionNameController = TextEditingController();
  final regExpController = TextEditingController();
  OnMessageActionEnum action = OnMessageActionEnum.none;
  final regFocus = FocusNode();
  final actionFocus = FocusNode();
  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Add custom action'),
      constraints: BoxConstraints(maxWidth: 600.0),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormBox(
            controller: actionNameController,
            autofocus: true,
            placeholder: 'Action name',
            onFieldSubmitted: (_) {
              regFocus.requestFocus();
            },
          ),
          Text('If message contains this RegExp'),
          Row(
            children: [
              Expanded(
                child: TextFormBox(
                  focusNode: regFocus,
                  controller: regExpController,
                  placeholder: 'RegExp',
                  onFieldSubmitted: (_) => actionFocus.requestFocus(),
                ),
              ),
              SizedBox(
                height: 32,
                child: DropDownButton(
                  title: const Text('Examples'),
                  items: [
                    MenuFlyoutItem(
                      text: Text('If text contains "Clipboard" quotes'),
                      onPressed: () {
                        regExpController.text = copyToCliboardRegex.pattern;
                      },
                    ),
                    MenuFlyoutItem(
                      text: Text('If text contains "Open URL" quotes'),
                      onPressed: () {
                        regExpController.text = openUrlRegex.pattern;
                      },
                    ),
                    MenuFlyoutItem(
                      text: Text('If text contains "Run CLI" quotes'),
                      onPressed: () {
                        regExpController.text = runShellRegex.pattern;
                      },
                    ),
                  ],
                ),
              )
            ],
          ),
          spacer,
          Text('Do this action'),
          spacer,
          DropDownButton(
            focusNode: actionFocus,
            title: action == OnMessageActionEnum.none
                ? const Text('Do nothing')
                : Text(action.name),
            items: [
              for (var action in OnMessageActionEnum.values)
                MenuFlyoutItem(
                  text: Text(action.name),
                  selected: this.action == action,
                  onPressed: () {
                    setState(() {
                      this.action = action;
                    });
                  },
                ),
            ],
          ),
          biggerSpacer,
          SelectableText(
            'Keep in mind that in order to actions be used by LLM you need to manually tell the bot to use them in system message like this:'
            '\n\n'
            """Your tools:
1 Copy content to user's clipboard
```clipboard
text
```
2 open url
```open-url
link
```""",
            style: TextStyle(color: Colors.yellow),
          )
        ],
      ),
      actions: [
        FilledButton(
          child: widget.action != null ? Text('Save') : const Text('Add'),
          onPressed: () {
            final newAction = OnMessageAction(
              actionName: actionNameController.text,
              regExp: RegExp(regExpController.text),
              actionEnum: action,
            );
            final actions = onMessageActions.value;
            if (widget.action != null) {
              actions.remove(widget.action);
            }
            actions.add(newAction);
            onMessageActions.add(actions);
            final json = actions.map((e) => e.toJson()).toList();
            AppCache.customActions.set(jsonEncode(json));
            Navigator.of(context).pop();
          },
        ),
        Button(
          child: const Text('Cancel'),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
      ],
    );
  }
}
