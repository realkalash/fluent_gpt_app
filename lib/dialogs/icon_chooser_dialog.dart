import 'package:fluent_gpt/fluent_icons_list.dart';
import 'package:fluent_ui/fluent_ui.dart';

class IconChooserDialog extends StatelessWidget {
  const IconChooserDialog({super.key});
  static Future<IconData?> show(BuildContext context) {
    return showDialog<IconData?>(
      context: context,
      builder: (ctx) => const IconChooserDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Choose an icon'),
      constraints: const BoxConstraints(maxWidth: 800),
      content: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: [
          for (var icon in fluentIconsList)
            Button(
              onPressed: () {
                Navigator.of(context).pop(icon);
              },
              child: Icon(icon, size: 24),
            ),
        ],
      ),
      actions: [
        Button(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
