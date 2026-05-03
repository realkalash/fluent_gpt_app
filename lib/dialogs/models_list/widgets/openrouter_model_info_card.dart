import 'package:fluent_gpt/common/openrouter_model_metadata.dart';
import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_gpt/widgets/text_link.dart';
import 'package:fluent_ui/fluent_ui.dart';

/// Compact model listing details from OpenRouter `GET /v1/models`.
class OpenRouterModelInfoCard extends StatelessWidget {
  const OpenRouterModelInfoCard({
    super.key,
    required this.meta,
    this.onApplySuggestedCapabilities,
  });

  final OpenRouterModelMeta meta;
  final VoidCallback? onApplySuggestedCapabilities;

  @override
  Widget build(BuildContext context) {
    final typo = FluentTheme.of(context).typography;
    final img = metaSuggestsImageInput(meta);
    final tools = metaSuggestsTools(meta);
    final reasoning = metaSuggestsReasoning(meta);
    final hasAnyHint = img || tools || reasoning;

    final line1 = <String>[
      if (meta.name != null && meta.name!.isNotEmpty) meta.name!,
      if (meta.contextLength != null) '${meta.contextLength} tokens',
    ].join(' · ');

    final detailLine = _infoDetailLine(meta);

    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'From provider listing'.tr,
              style: typo.caption,
            ),
            if (line1.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(line1, style: typo.body),
            ],
            if (meta.description != null && meta.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                meta.description!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: typo.caption,
              ),
            ],
            if (detailLine.isNotEmpty) ...[
              const SizedBox(height: 4),
              SelectableText(detailLine, style: typo.caption),
            ],
            if (hasAnyHint) ...[
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (img)
                    _Chip(text: 'Images (input)'.tr),
                  if (tools)
                    _Chip(text: 'Tools'.tr),
                  if (reasoning)
                    _Chip(text: 'Reasoning params'.tr),
                ],
              ),
            ],
            if (meta.detailsUrl != null && meta.detailsUrl!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: LinkTextButton(meta.detailsUrl!),
              ),
            ],
            if (onApplySuggestedCapabilities != null) ...[
              const SizedBox(height: 8),
              Button(
                onPressed: onApplySuggestedCapabilities,
                child: Text('Apply suggested capabilities'.tr),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _infoDetailLine(OpenRouterModelMeta m) {
  final parts = <String>[];
  final mod = openRouterModalitySummary(m);
  if (mod.isNotEmpty) parts.add(mod);
  if (m.pricingPrompt != null || m.pricingCompletion != null) {
    final pp = formatOpenRouterUsdPerMillionLabel(m.pricingPrompt);
    final pc = formatOpenRouterUsdPerMillionLabel(m.pricingCompletion);
    parts.add('Prompt $pp · completion $pc (USD / 1M tokens)');
  }
  return parts.join('\n');
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(4),
        color: FluentTheme.of(context).micaBackgroundColor,
      ),
      child: Text(text, style: FluentTheme.of(context).typography.caption),
    );
  }
}
