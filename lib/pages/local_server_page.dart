import 'package:file_picker/file_picker.dart';
import 'package:fluent_gpt/providers/server_provider.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

class LocalServerPage extends StatelessWidget {
  const LocalServerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final serverProvider = context.watch<ServerProvider>();
    return ScaffoldPage.scrollable(
      header: PageHeader(title: Text('Local')),
      children: [
        TextFormBox(
          initialValue: serverProvider.modelPath,
          onChanged: (value) {
            serverProvider.modelPath = value;
          },
          validator: (value) {
            if ((value ?? '').isEmpty) {
              return 'Please enter a valid path';
            }
            return null;
          },
        ),
        ListTile.selectable(
          title: const Text('Enable local server'),
          selected: serverProvider.isRunning,
          onSelectionChange: (value) {
            serverProvider.toggleLocalFirstModel(value);
          },
        ),
        Button(
          child: const Text('Add model'),
          onPressed: () async {
            String? result = await FilePicker.platform.getDirectoryPath(
                // allowMultiple: false,
                // dialogTitle: 'Select a gguf model',
                // type: FileType.custom,
                // allowedExtensions: ['gguf'],
                );
            if (result != null && result.isNotEmpty) {
              serverProvider.addLocalModelPath(result);
            }
          },
        ),
      ],
    );
  }
}
