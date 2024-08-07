import 'package:fluent_gpt/utils.dart';
import 'package:flutter/material.dart';
import 'package:markdown_widget/config/all.dart';
import 'package:markdown_widget/widget/all.dart';

import 'code_wrapper.dart';

Widget buildMarkdown(BuildContext context, String data,
    {String? language, double? textSize}) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  final config =
      isDark ? MarkdownConfig.darkConfig : MarkdownConfig.defaultConfig;

  return Material(
    color: Colors.transparent,
    child: MarkdownWidget(
        data: data,
        shrinkWrap: true,
        config: config.copy(configs: [
          isDark
              ? PreConfig.darkConfig.copy(
                  wrapper: (child, code, lang) => CodeWrapperWidget(
                    content: code,
                    language: lang,
                    preConfig: PreConfig.darkConfig,
                    style: PreConfig.darkConfig.textStyle.copyWith(
                      fontSize: textSize,
                    ),
                  ),
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
                  wrapper: (child, code, lang) => CodeWrapperWidget(
                    content: code,
                    language: lang,
                    preConfig: PreConfig.darkConfig,
                    style: PreConfig.darkConfig.textStyle.copyWith(
                      fontSize: textSize,
                    ),
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
        ])),
  );
}
