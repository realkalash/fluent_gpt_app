import 'package:fluent_gpt/utils.dart';
import 'package:fluent_gpt/widgets/markdown_builders/code_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:markdown_widget/config/all.dart';
import 'package:markdown_widget/config/configs.dart';
import 'package:markdown_widget/widget/all.dart';

Widget buildMarkdown(BuildContext context, String data,
    {String? language, double? textSize}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final config =
      isDark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig;
  codeWrapper(child, text, language) =>
      CodeWrapperWidget(child, text, language);

  return Material(
    color: Colors.transparent,
    child: MarkdownWidget(
        data: data,
        shrinkWrap: true,
        config: config.copy(configs: [
          isDark
              ? PreConfig.darkConfig.copy(
                  wrapper: codeWrapper,
                  language: language,
                  textStyle: PreConfig.darkConfig.textStyle.copyWith(
                    fontSize: textSize,
                  ),
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
                  wrapper: codeWrapper,
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
        ])),
  );
}
