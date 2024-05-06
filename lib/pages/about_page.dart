import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      content: ListView(
        padding: const EdgeInsets.all(20.0),
        children: [
          Text(
            'FluentGPT',
            style: FluentTheme.of(context).typography.display,
          ),
          const AppVersion(),
          const SizedBox(height: 16.0),
          // description
          const AppDescription(),
        ],
      ),
    );
  }
}

class AppVersion extends StatelessWidget {
  const AppVersion({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Object>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            final PackageInfo info = snapshot.data as PackageInfo;
            return Text('Version: ${info.version}',
                style: FluentTheme.of(context).typography.title);
          }
          return const SizedBox();
        });
  }
}

class AppDescription extends StatelessWidget {
  const AppDescription({super.key});
  static const message = '''
Welcome to Fluent GPT App, an open-source, multi-platform desktop application that brings the power of GPT models to your fingertips. Designed with a sleek Fluent interface, it offers a unique and customizable chat experience on Windows, macOS, and Linux.

## Features

- **Cross-Platform Support**: Works seamlessly on Windows, macOS, and Linux.
- **Tray Functionality**: Ability to minimize to the system tray for quick access.
- **Custom Shortcut Activation**: Open the app with a custom keyboard shortcut.
- **Multiple Chat Rooms**: Engage with different GPT models in separate chat rooms.
- **Custom Instructions**: Tailor each chat room with specific instructions or guidelines.
- **Integration with ChatGPT from OpenAI**: Use ChatGPT by obtaining a token from OpenAI.
- **Custom GPT**: You can use your own GPT models by providing a URL to the model. 
- **Pin app**: Pin the app to the top of your screen for easy access.''';
  @override
  Widget build(BuildContext context) {
    return Card(
      backgroundColor:
          FluentTheme.of(context).micaBackgroundColor.withOpacity(0.8),
      child: const MarkdownBody(data: message),
    );
  }
}
