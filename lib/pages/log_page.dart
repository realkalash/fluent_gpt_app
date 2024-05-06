import 'package:chatgpt_windows_flutter_app/log.dart';
import 'package:fluent_ui/fluent_ui.dart';

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
        title: const Text('Log'),
        commandBar: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
                icon: const Icon(FluentIcons.delete),
                onPressed: () {
                  logMessages.add([]);
                  log('Logs cleared');
                })
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
