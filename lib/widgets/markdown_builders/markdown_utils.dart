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
          PConfig(textStyle: TextStyle(fontSize: textSize ?? 16)),
          isDark
              ? PreConfig.darkConfig.copy(
                  styleNotMatched: TextStyle(fontSize: textSize),
                  theme: _a11yDarkTheme(textSize),
                  wrapper: (child, code, lang) => CodeWrapperWidget(
                    content: code,
                    language: lang,
                    preConfig: PreConfig.darkConfig,
                    style: TextStyle(fontSize: textSize),
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
                  theme: _a11yDarkTheme(textSize),
                  wrapper: (child, code, lang) => CodeWrapperWidget(
                    content: code,
                    language: lang,
                    preConfig: PreConfig.darkConfig,
                    style: TextStyle(fontSize: textSize),
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

_a11yDarkTheme(double? fontSize) => {
      'comment': TextStyle(color: const Color(0xffd4d0ab), fontSize: fontSize),
      'quote': TextStyle(color: const Color(0xffd4d0ab), fontSize: fontSize),
      'variable': TextStyle(color: const Color(0xffffa07a), fontSize: fontSize),
      'template-variable':
          TextStyle(color: const Color(0xffffa07a), fontSize: fontSize),
      'tag': TextStyle(color: const Color(0xffffa07a), fontSize: fontSize),
      'name': TextStyle(color: const Color(0xffffa07a), fontSize: fontSize),
      'selector-id':
          TextStyle(color: const Color(0xffffa07a), fontSize: fontSize),
      'selector-class':
          TextStyle(color: const Color(0xffffa07a), fontSize: fontSize),
      'regexp': TextStyle(color: const Color(0xffffa07a), fontSize: fontSize),
      'deletion': TextStyle(color: const Color(0xffffa07a), fontSize: fontSize),
      'number': TextStyle(color: const Color(0xfff5ab35), fontSize: fontSize),
      'built_in': TextStyle(color: const Color(0xfff5ab35), fontSize: fontSize),
      'builtin-name':
          TextStyle(color: const Color(0xfff5ab35), fontSize: fontSize),
      'literal': TextStyle(color: const Color(0xfff5ab35), fontSize: fontSize),
      'type': TextStyle(color: const Color(0xfff5ab35), fontSize: fontSize),
      'params': TextStyle(color: const Color(0xfff5ab35), fontSize: fontSize),
      'meta': TextStyle(color: const Color(0xfff5ab35), fontSize: fontSize),
      'link': TextStyle(color: const Color(0xfff5ab35), fontSize: fontSize),
      'attribute':
          TextStyle(color: const Color(0xffffd700), fontSize: fontSize),
      'string': TextStyle(color: const Color(0xffabe338), fontSize: fontSize),
      'symbol': TextStyle(color: const Color(0xffabe338), fontSize: fontSize),
      'bullet': TextStyle(color: const Color(0xffabe338), fontSize: fontSize),
      'addition': TextStyle(color: const Color(0xffabe338), fontSize: fontSize),
      'title': TextStyle(color: const Color(0xff00e0e0), fontSize: fontSize),
      'section': TextStyle(color: const Color(0xff00e0e0), fontSize: fontSize),
      'keyword': TextStyle(color: const Color(0xffdcc6e0), fontSize: fontSize),
      'selector-tag':
          TextStyle(color: const Color(0xffdcc6e0), fontSize: fontSize),
      'root': TextStyle(
          backgroundColor: const Color(0xff2b2b2b),
          color: const Color(0xfff8f8f2),
          fontSize: fontSize),
      'emphasis': TextStyle(fontStyle: FontStyle.italic, fontSize: fontSize),
      'strong': TextStyle(fontWeight: FontWeight.bold, fontSize: fontSize),
    };
