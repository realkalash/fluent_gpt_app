import 'package:flutter/material.dart';
import 'package:markdown_widget/markdown_widget.dart';

import 'code_wrapper.dart';

SpanNodeGeneratorWithTag codeBlockGenerator = SpanNodeGeneratorWithTag(
  tag: MarkdownTag.pre.name,
  generator: (e, config, visitor) {
    return CustomCodeBlockNode(e.textContent, config.pre);
  },
);

class CustomCodeBlockNode extends ElementNode {
  CustomCodeBlockNode(this.content, this.preConfig);

  final String content;
  final PreConfig preConfig;
  final scrollController = ScrollController();

  @override
  InlineSpan build() {
    return WidgetSpan(
      child: CodeWrapperWidget(
        content: content,
        language: preConfig.language,
        preConfig: preConfig,
        style: style,
      ),
    );
  }

  @override
  TextStyle get style => preConfig.textStyle.merge(parentStyle);
}
