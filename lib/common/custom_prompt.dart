import 'dart:convert';

import 'package:fluent_gpt/common/prefs/app_cache.dart';
import 'package:fluentui_system_icons/fluentui_system_icons.dart';
import 'package:flutter/widgets.dart' as widgets;
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:rxdart/rxdart.dart';

BehaviorSubject<String> defaultGPTLanguage = BehaviorSubject.seeded('en');
const List<CustomPrompt> baseArchivedPromptsTemplate = [
  // Continue writing
  CustomPrompt(
    id: 5,
    icon: FluentIcons.edit_24_filled,
    index: 5,
    title: 'Continue writing',
    prompt: '''"""\${input}""" 
Continue writing that begins with the text above and keeping the same voice and style. Stay on the same topic.
Only give me the output and nothing else. Respond in the same language variety or dialect of the text above. Answer only in clipboard quotes: \${clipboardAccess}''',
    showInChatField: true,
    showInOverlay: true,
    children: [],
  ),
];
const List<CustomPrompt> basePromptsTemplate = [
  CustomPrompt(
    id: 1,
    title: 'Explain this',
    icon: FluentIcons.info_24_filled,
    index: 0,
    prompt:
        'Please explain clearly and concisely using:"\${lang}" language: "\${input}"',
    showInChatField: true,
    showInOverlay: true,
    children: [],
  ),
  CustomPrompt(
    id: 2,
    title: 'Summarize this',
    icon: FluentIcons.text_paragraph_24_regular,
    index: 1,
    prompt:
        '''You are a highly skilled AI trained in language comprehension and summarization. I would like you to read the text delimited by triple quotes and summarize it into a concise abstract paragraph. Aim to retain the most important points, providing a coherent and readable summary that could help a person understand the main points of the discussion without needing to read the entire text. Please avoid unnecessary details or tangential points.
Only give me the output and nothing else. Respond in the \${lang} language. Clipboard access: \${clipboardAccess}
"""
\${input}
"""''',
    showInChatField: true,
    showInOverlay: true,
    children: [],
  ),
  CustomPrompt(
    id: 3,
    title: 'Check grammar',
    icon: FluentIcons.text_grammar_wand_24_filled,
    index: 2,
    prompt:
        '''Check spelling and grammar in the following text.
If the original text has no mistake, write "Original text has no mistake". 
Copy to clipboard: \${clipboardAccess}. 
"""
\${input}
"""''',
    showInChatField: true,
    showInOverlay: true,
    children: [],
  ),
  CustomPrompt(
    id: 3,
    title: 'Improve writing',
    icon: FluentIcons.text_grammar_wand_24_filled,
    index: 3,
    prompt: '''Please improve the writing in the following text. Make it more engaging and clear.
Copy to clipboard: \${clipboardAccess}.
"""
\${input}
"""''',
    showInChatField: true,
    showInOverlay: true,
    children: [],
  ),
  CustomPrompt(
    id: 4,
    title: 'Translate this',
    index: 4,
    icon: FluentIcons.translate_24_regular,
    prompt:
        '''Please translate the following text to language:"\${lang}". Only give me the output and nothing else:
    "\${input}"''',
    showInChatField: true,
    showInOverlay: true,
    children: [
      CustomPrompt(
        id: 5,
        title: 'Translate to English',
        prompt:
            '''Please translate the following text to English. Only give me the output and nothing else:
    "\${input}"''',
      ),
      CustomPrompt(
        id: 6,
        title: 'Translate to Russian',
        prompt:
            '''Please translate the following text to Russian. Only give me the output and nothing else:
    "\${input}"''',
      ),
      CustomPrompt(
        id: 7,
        title: 'Translate to Ukrainian',
        prompt:
            '''Please translate the following text to Ukrainian. Only give me the output and nothing else:
    "\${input}"''',
      ),
    ],
  ),
];

class CustomPrompt {
  /// The id of the prompt
  final int id;

  /// The name of the prompt
  final String title;

  /// Index for sorting
  final int index;

  /// User can paste a custon prompt for chatGPT here
  /// He can use ${input} to refer to the selected text in the chat field
  final String prompt;

  /// Icon. The default is chat_20_filled
  final widgets.IconData icon;

  /// If true will be shown above the chat input field as a button
  final bool showInChatField;

  /// If true will be shown in the overlay
  final bool showInOverlay;

  /// If not empty, this prompt will be shown as a dropdown
  final List<CustomPrompt> children;

  /// Shortcut for using this custom prompt
  final HotKey? hotkey;

  /// If true will automatically focus the window when the prompt is run
  final bool focusTheWindowOnRun;

  const CustomPrompt({
    required this.id,
    required this.title,
    required this.prompt,
    this.index = 0,
    this.showInChatField = false,
    this.showInOverlay = false,
    this.children = const [],
    this.icon = FluentIcons.chat_20_filled,
    this.hotkey,
    this.focusTheWindowOnRun = false,
  });

  /// Returns the prompt text with the selected text
  /// If selectedText is null, it will be replaced with '<nothing selected>'
  /// The prompt also use the language from the lang BehaviorSubject
  String getPromptText([String? selectedText]) => prompt
      .replaceAll('\${lang}', defaultGPTLanguage.value)
      .replaceAll(
        '\${clipboardAccess}',
        AppCache.gptToolCopyToClipboardEnabled.value == true ? 'YES' : 'NO',
      )
      .replaceAll('\${input}', selectedText ?? '<nothing selected>');

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is CustomPrompt && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CustomPrompt(id: $id, index:$index, title: $title, showInChatField: $showInChatField, showInOverlay: $showInOverlay, children: $children, icon: $icon)';
  }

  Map<String, Object?> toJson() {
    return {
      'id': id,
      'title': title,
      'prompt': prompt,
      'showInChatField': showInChatField,
      'showInOverlay': showInOverlay,
      'children': children.map((e) => e.toJson()).toList(),
      'icon': icon.codePoint,
      'fontPackage': icon.fontPackage,
      'iconFamily': icon.fontFamily,
      'hotkey': hotkey?.toJson(),
      'focusTheWindowOnRun': focusTheWindowOnRun,
      'index': index,
    };
  }

  static CustomPrompt fromJson(Map<dynamic, dynamic> json) {
    return CustomPrompt(
      id: json['id'] ?? -1,
      title: json['title'],
      prompt: json['prompt'],
      showInChatField: json['showInChatField'],
      index: json['index'] ?? 0,
      showInOverlay: json['showInOverlay'],
      children: (json['children'] is List)
          ? (json['children'] as List)
              .map((e) => CustomPrompt.fromJson(e))
              .toList()
          : [],
      icon: widgets.IconData(
        json['icon'] is int
            ? json['icon']
            : FluentIcons.chat_20_filled.codePoint,
        fontPackage: json['fontPackage'],
        fontFamily: json['iconFamily'],
      ),
      hotkey: json['hotkey'] != null ? HotKey.fromJson(json['hotkey']) : null,
      focusTheWindowOnRun: json['focusTheWindowOnRun'] ?? false,
    );
  }

  String toJsonString() {
    return jsonEncode(toJson());
  }

  static CustomPrompt fromJsonString(String jsonString) {
    return fromJson(jsonDecode(jsonString));
  }

  CustomPrompt copyWith({
    int? id,
    String? title,
    String? prompt,
    int? index,
    widgets.IconData? icon,
    bool? showInChatField,
    bool? showInOverlay,
    List<CustomPrompt>? children,
    HotKey? hotkey,
    bool? focusTheWindowOnRun,
  }) {
    return CustomPrompt(
      id: id ?? this.id,
      title: title ?? this.title,
      prompt: prompt ?? this.prompt,
      index: index ?? this.index,
      icon: icon ?? this.icon,
      showInChatField: showInChatField ?? this.showInChatField,
      showInOverlay: showInOverlay ?? this.showInOverlay,
      children: children ?? this.children,
      hotkey: hotkey ?? this.hotkey,
      focusTheWindowOnRun: focusTheWindowOnRun ?? this.focusTheWindowOnRun,
    );
  }
}
