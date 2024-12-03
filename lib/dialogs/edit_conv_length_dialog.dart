import 'package:fluent_gpt/common/conversaton_style_enum.dart';
import 'package:fluent_gpt/widgets/wiget_constants.dart';
import 'package:fluent_ui/fluent_ui.dart';

class ConversationStyleDialog extends StatefulWidget {
  const ConversationStyleDialog({super.key, required this.item});
  final ConversationLengthStyleEnum item;
  static Future<ConversationLengthStyleEnum?> show(
    BuildContext context,
    ConversationLengthStyleEnum item,
  ) {
    return showDialog<ConversationLengthStyleEnum>(
      context: context,
      builder: (context) {
        return ConversationStyleDialog(item: item);
      },
    );
  }

  @override
  State<ConversationStyleDialog> createState() =>
      _ConversationStyleDialogState();
}

class _ConversationStyleDialogState extends State<ConversationStyleDialog> {
  ConversationLengthStyleEnum? newItem;
  @override
  void initState() {
    super.initState();
    newItem = widget.item.copyWith();
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: Text('Edit conversation style for [${newItem!.name}]'),
      actions: [
        Button(
          onPressed: () {
            Navigator.of(context).pop(newItem);
          },
          child: const Text('Save'),
        ),
        Button(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
      ],
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Name (should be unique)'),
          TextFormBox(
            initialValue: newItem!.name,
            onChanged: (value) {
              setState(() {
                newItem = newItem!.copyWith(name: value);
              });
            },
          ),
          spacer,
          const Text('Prompt that will be added to the end of your messages'),
          TextFormBox(
            initialValue: newItem!.prompt,
            onChanged: (value) {
              setState(() {
                newItem = newItem!.copyWith(prompt: value);
              });
            },
          ),
        ],
      ),
    );
  }
}
