import 'package:fluent_ui/fluent_ui.dart' hide FluentIcons;
import 'package:fluentui_system_icons/fluentui_system_icons.dart';

class IconToolsSupported extends StatelessWidget {
  const IconToolsSupported({super.key});

  @override
  Widget build(BuildContext context) {
    return Icon(FluentIcons.code_16_filled, color: Colors.blue);
  }
}

class IconReasoningSupported extends StatelessWidget {
  const IconReasoningSupported({super.key});

  @override
  Widget build(BuildContext context) {
    return Icon(FluentIcons.brain_sparkle_20_filled, color: Colors.green);
  }
}

class IconImagesSupported extends StatelessWidget {
  const IconImagesSupported({super.key});

  @override
  Widget build(BuildContext context) {
    return Icon(FluentIcons.image_24_filled, color: Colors.yellow);
  }
}
