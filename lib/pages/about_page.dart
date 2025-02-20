import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:markdown_widget/markdown_widget.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: PageHeader(
        title: Text(
          'FluentGPT',
          style: FluentTheme.of(context).typography.display,
        ),
        leading: IconButton(
          icon: const Icon(FluentIcons.arrow_left_24_regular, size: 24),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      content: ListView(
        padding: const EdgeInsets.all(20.0),
        children: const [
          AppVersion(),
          SizedBox(height: 16.0),
          // description
          AppDescription(),
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
- **Pin app**: Pin the app to the top of your screen for easy access.
- **Search files support**: You can download and use "Everything" search engine to search files on your computer.
- **Shell support**: GPT can run shell commands on your computer.
- **Quick Prompts**: Users can create their custom quick prompts and bind hotkeys to use them faster in the chat and overlay.
- **Overlay Mode on Text Selection (macOS)**: When users select text, the app will show a compact horizontal overlay with pre-created user's quick prompts.
- **Sidebar Mode**: The app will switch to a compact vertical overlay that will show custom user prompts. You can copy selected text in clipboard and use buttons to interact with the app.
- **Run Python Code**: GPT can run Python code locally, allowing for seamless integration and execution of scripts.''';
  @override
  Widget build(BuildContext context) {
    return Card(
      backgroundColor:
          FluentTheme.of(context).micaBackgroundColor.withAlpha(200),
      child: const MarkdownWidget(
        data: message,
        shrinkWrap: true,
      ),
    );
  }
}
