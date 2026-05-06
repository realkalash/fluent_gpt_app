import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_ui/fluent_ui.dart';

class AddModelSectionTitle extends StatelessWidget {
  const AddModelSectionTitle(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Text(
        label,
        style: FluentTheme.of(context).typography.subtitle,
      ),
    );
  }
}

/// Shows which step of the connection test is running.
class AddModelTestProgress extends StatelessWidget {
  const AddModelTestProgress({
    super.key,
    required this.isTesting,
    this.phaseLabel,
  });

  final bool isTesting;
  final String? phaseLabel;

  @override
  Widget build(BuildContext context) {
    if (!isTesting || phaseLabel == null) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Testing…'.tr),
          const SizedBox(height: 6),
          const ProgressBar(),
          const SizedBox(height: 4),
          Text(
            phaseLabel!,
            style: FluentTheme.of(context).typography.caption,
          ),
        ],
      ),
    );
  }
}
