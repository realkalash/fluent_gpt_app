import 'package:fluent_gpt/log.dart';
import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class LogPage extends StatefulWidget {
  const LogPage({super.key});

  @override
  State<LogPage> createState() => _LogPageState();
}

class _LogPageState extends State<LogPage> {
  final List<String> logs = [];
  @override
  void initState() {
    super.initState();
    logMessages.listen((value) {
      if (mounted) {
        setState(() {
          logs.clear();
          logs.addAll(value);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        leading: IconButton(
          icon: const Icon(
            FluentIcons.arrow_left_24_regular,
            size: 24,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('Log (${logs.length} items)'),
        commandBar: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                icon: const Icon(FluentIcons.delete_24_filled),
                onPressed: () {
                  logMessages.add([]);
                  log('Logs cleared');
                }),
          ],
        ),
      ),
      content: ListView.builder(
        itemBuilder: (context, index) {
          final log = logs[index];
          return LogListTile(message: log);
        },
        itemCount: logs.length,
      ),
    );
  }
}

class LogListTile extends StatelessWidget {
  const LogListTile({
    super.key,
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.zero,
      backgroundColor: message.contains('Error')
          ? Colors.red.withOpacity(0.5)
          : const Color(0xff636363),
      child: ListTile(
        title: SelectableText(message),
      ),
    );
  }
}
