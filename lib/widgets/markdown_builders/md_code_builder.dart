// import 'package:flutter/material.dart';
// import 'package:flutter_highlighter/themes/atom-one-dark.dart';
// import 'package:flutter_highlighter/themes/atom-one-light.dart';
// import 'package:flutter_markdown/flutter_markdown.dart';
// import 'package:markdown/markdown.dart' as md;
// // ignore: depend_on_referenced_packages
// import 'package:highlighter/highlighter.dart' show highlight, Node;

// class CodeElementBuilder extends MarkdownElementBuilder {
//   final bool isDarkTheme;

//   CodeElementBuilder({required this.isDarkTheme});

//   @override
//   Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
//     var language = '';

//     if (element.attributes['class'] != null) {
//       String lg = element.attributes['class'] as String;
//       language = lg.substring(9);
//     }
//     return SizedBox(
//       width:
//           // ignore: deprecated_member_use
//           MediaQueryData.fromView(WidgetsBinding.instance.window).size.width,
//       child: CustomHighlightView(
//         // The original code to be highlighted
//         element.textContent,

//         // Specify language
//         // It is recommended to give it a value for performance
//         language: language,

//         // Specify highlight theme
//         // All available themes are listed in `themes` folder
//         // ignore: deprecated_member_use
//         theme: !isDarkTheme ? atomOneLightTheme : atomOneDarkTheme,
//         padding: const EdgeInsets.all(8),
//       ),
//     );
//   }
// }

// /// Highlight Flutter Widget
// class CustomHighlightView extends StatelessWidget {
//   /// The original code to be highlighted
//   final String source;

//   /// Highlight language
//   ///
//   /// It is recommended to give it a value for performance
//   ///
//   /// [All available languages](https://github.com/predatorx7/highlight/tree/master/highlight/lib/languages)
//   final String? language;

//   /// Highlight theme
//   ///
//   /// [All available themes](https://github.com/predatorx7/highlight/blob/master/flutter_highlighter/lib/themes)
//   final Map<String, TextStyle> theme;

//   /// Padding
//   final EdgeInsetsGeometry? padding;

//   /// Text styles
//   ///
//   /// Specify text styles such as font family and font size
//   final TextStyle? textStyle;

//   CustomHighlightView(
//     String input, {
//     super.key,
//     this.language,
//     this.theme = const {},
//     this.padding,
//     this.textStyle,
//     int tabSize = 8, 
//   }) : source = input.replaceAll('\t', ' ' * tabSize);

//   List<TextSpan> _convert(List<Node> nodes) {
//     List<TextSpan> spans = [];
//     var currentSpans = spans;
//     List<List<TextSpan>> stack = [];

//     traverse(Node node) {
//       if (node.value != null) {
//         currentSpans.add(node.className == null
//             ? TextSpan(text: node.value)
//             : TextSpan(text: node.value, style: theme[node.className!]));
//       } else if (node.children != null) {
//         List<TextSpan> tmp = [];
//         currentSpans
//             .add(TextSpan(children: tmp, style: theme[node.className!]));
//         stack.add(currentSpans);
//         currentSpans = tmp;

//         for (var n in node.children!) {
//           traverse(n);
//           if (n == node.children!.last) {
//             currentSpans = stack.isEmpty ? spans : stack.removeLast();
//           }
//         }
//       }
//     }

//     for (var node in nodes) {
//       traverse(node);
//     }

//     return spans;
//   }

//   static const _rootKey = 'root';
//   static const _defaultFontColor = Color(0xff000000);
//   static const _defaultBackgroundColor = Color(0xffffffff);

//   static const _defaultFontFamily = 'monospace';

//   @override
//   Widget build(BuildContext context) {
//     var textStyle = TextStyle(
//       fontFamily: _defaultFontFamily,
//       color: theme[_rootKey]?.color ?? _defaultFontColor,
//     );
//     textStyle = textStyle.merge(textStyle);

//     return Container(
//       color: theme[_rootKey]?.backgroundColor ?? _defaultBackgroundColor,
//       padding: padding,
//       child: SelectableText.rich(
//         TextSpan(
//           style: textStyle,
//           children:
//               _convert(highlight.parse(source, language: language).nodes!),
//         ),
//       ),
//     );
//   }
// }
