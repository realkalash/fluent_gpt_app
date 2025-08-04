import 'dart:io';

import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/widgets/custom_buttons.dart';
import 'package:fluent_gpt/widgets/text_link.dart';
import 'package:fluent_ui/fluent_ui.dart';

class ServerProviderUtil {
  static String getPlatformCppBuildDir() {
    if (Platform.isWindows) {
      return 'cpp_build_win';
    } else if (Platform.isLinux) {
      return 'cpp_build_linux';
    } else if (Platform.isMacOS) {
      return 'cpp_build_macos_arm64';
    }
    return 'cpp_build_macos_arm64';
  }

  static String getPlatformCppExecutable() {
    if (Platform.isWindows) {
      return 'llama-server.exe';
    } else if (Platform.isLinux) {
      return 'llama-server';
    } else if (Platform.isMacOS) {
      return 'llama-server';
    }
    return 'llama-server';
  }
}

class ServerTouchFilesPromptDialog extends StatelessWidget {
  const ServerTouchFilesPromptDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: Text('The app needs permission to run these files'),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
              'I\'m using llama.cpp to run local AI models. I\'m a single developer and I don\'t have a team to help me with managing certificates. Please grant the permission to run these files. They are all secure and has been downloaded from the official llama.cpp repository.'),
          LinkTextButton(
            'Click here to open the official llama.cpp repository. (https://github.com/ggml-org/llama.cpp/releases/tag/b6082)',
            url: 'https://github.com/ggml-org/llama.cpp/releases/tag/b6082',
          ),
          const SizedBox(height: 16),
          Text("""INSTRUCTIONS:
1. Click on the "Grant" button
2. Open the privacy and security settings
3. Scroll down to "Security" section
4. Click "Allow" to grant access for a specific file
5. Repeat the process for all the files"""),
        ],
      ),
      actions: [
        FilledButton(
            onPressed: () {
              Navigator.of(context).pop(true);
            },
            child: Text('Grant access'.tr)),
        Button(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text('Dismiss'.tr),
        ),
      ],
    );
  }
}
