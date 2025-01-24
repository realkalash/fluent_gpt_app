import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/custom_selectable_region.dart';
import 'package:flutter/material.dart';
import 'package:markdown_widget/config/all.dart';
import 'package:markdown_widget/widget/all.dart';

import 'code_wrapper.dart';


///Tag: [MarkdownTag.em]
///
/// emphasis, Markdown treats asterisks (*) and underscores (_) as indicators of emphasis
class EmCustomNode extends ElementNode {
  @override
  TextStyle get style => parentStyle!.merge(TextStyle(fontStyle: FontStyle.italic, color: Colors.amber));
}

Widget buildMarkdown(
  BuildContext context,
  String data, {
  String? language,
  double? textSize,
  Widget Function(BuildContext, CustomSelectableRegionState)?
      contextMenuBuilder,
}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final config =
      isDark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig;
  final focusNode = FocusNode();

  return Material(
    color: Colors.transparent,
    child: CustomSelectableRegion(
      contextMenuBuilder: contextMenuBuilder,
      focusNode: focusNode,
      selectionControls: materialTextSelectionHandleControls,
      child: MarkdownWidget(
        data: data,
        shrinkWrap: true,
        selectable: false,
        markdownGenerator: MarkdownGenerator(generators: [
          SpanNodeGeneratorWithTag(
            generator: (e, config, visitor) {
              return EmCustomNode();
            },
            tag: MarkdownTag.em.name,
          )
        ]),
        config: config.copy(
          configs: [
            PConfig(textStyle: TextStyle(fontSize: textSize ?? 16)),
            isDark
                ? PreConfig.darkConfig.copy(
                    styleNotMatched: TextStyle(
                        fontSize: textSize,
                        color: Colors.amber,
                        backgroundColor: Colors.black),
                    wrapper: (child, code, lang) => CodeWrapperWidget(
                      content: code,
                      language: lang,
                      preConfig: PreConfig.darkConfig,
                      style: TextStyle(fontSize: textSize),
                      contextMenuBuilder: contextMenuBuilder,
                      focusNode: FocusNode(),
                    ),
                    language: language,
                    textStyle: TextStyle(fontSize: textSize, color: Colors.red),
                    margin: const EdgeInsets.all(0),
                    decoration: BoxDecoration(
                      color: context.theme.cardColor,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
                  )
                : const PreConfig().copy(
                    styleNotMatched: TextStyle(fontSize: textSize),
                    wrapper: (child, code, lang) => CodeWrapperWidget(
                      content: code,
                      language: lang,
                      preConfig: PreConfig.darkConfig,
                      style: TextStyle(fontSize: textSize),
                      contextMenuBuilder: contextMenuBuilder,
                      focusNode: FocusNode(),
                    ),
                    language: language,
                    margin: const EdgeInsets.all(0),
                    textStyle: PreConfig.darkConfig.textStyle.copyWith(
                      fontSize: textSize,
                    ),
                    decoration: BoxDecoration(
                      color: context.theme.cardColor,
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(4),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                  )
          ],
        ),
      ),
    ),
  );
}
