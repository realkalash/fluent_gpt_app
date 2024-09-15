import 'package:fluent_gpt/fluent_icons_list.dart';
import 'package:fluent_gpt/widgets/wiget_constants.dart';
import 'package:fluent_ui/fluent_ui.dart';

class IconChooserDialog extends StatefulWidget {
  const IconChooserDialog({super.key});
  static Future<IconData?> show(BuildContext context) {
    return showDialog<IconData?>(
      context: context,
      builder: (ctx) => const IconChooserDialog(),
    );
  }

  @override
  State<IconChooserDialog> createState() => _IconChooserDialogState();
}

class _IconChooserDialogState extends State<IconChooserDialog> {
  final textContr = TextEditingController();

  @override
  void initState() {
    icons.addAll(tagToIconMap);
    super.initState();
  }

  Map<String, IconData> icons = {};

  void searchIcons(String query) {
    icons.clear();
    if (query.isEmpty) {
      icons.addAll(tagToIconMap);
      setState(() {});
      return;
    }
    for (var entry in tagToIconMap.entries) {
      if (entry.key.contains(query)) {
        icons[entry.key] = entry.value;
      }
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Choose an icon'),
      constraints: const BoxConstraints(maxWidth: 800),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 24, right: 24, bottom: 16),
            child: TextBox(
              controller: textContr,
              placeholder: 'Search for an icon',
              onChanged: searchIcons,
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var icon in icons.entries)
                Tooltip(
                  message: icon.key,
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Button(
                      onPressed: () {
                        Navigator.of(context).pop(icon.value);
                      },
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icon.value, size: 24),
                          const SizedBox(width: 8),
                          Expanded(child: Text(icon.key,maxLines: 1,overflow: TextOverflow.clip)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
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
