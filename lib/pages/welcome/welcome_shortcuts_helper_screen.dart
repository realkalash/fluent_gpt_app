// ignore_for_file: public_member_api_docs, sort_constructors_first
import 'dart:io';

import 'package:adaptive_layout/adaptive_layout.dart';
import 'package:fluent_gpt/overlay/overlay_manager.dart';
import 'package:fluent_gpt/tray.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';

import 'welcome_screen.dart';

class WelcomeShortcutsHelper extends StatefulWidget {
  const WelcomeShortcutsHelper({super.key});

  @override
  State<WelcomeShortcutsHelper> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomeShortcutsHelper> {
  final _leftKeybindings = <Widget>[
    KeyBindingText(
      title: 'Create new chat (only in chat)',
      hotKey: createNewChat,
      textColor: Colors.white,
    ),
    KeyBindingText(
      title: 'Reset chat (only in chat)',
      hotKey: resetChat,
      textColor: Colors.white,
    ),
    KeyBindingText(
      title: 'Escape/Cancel selection (only in chat)',
      hotKey: HotKey(key: LogicalKeyboardKey.escape),
      textColor: Colors.white,
    ),
    KeyBindingText(
      title: 'Reset chat (only in chat)',
      hotKey: resetChat,
      textColor: Colors.white,
    ),
    KeyBindingText(
      title: 'Copy last message to clipboard (only in chat)',
      hotKey: HotKey(
        key: LogicalKeyboardKey.enter,
        modifiers: [
          HotKeyModifier.meta,
        ],
      ),
      textColor: Colors.white,
    ),
    KeyBindingText(
      title:
          'Include current chat history in conversation ${Platform.isWindows ? '(Ctrl+H)' : '(⌘+H)'}',
      hotKey: HotKey(
        key: LogicalKeyboardKey.keyH,
        modifiers: [
          Platform.isMacOS ? HotKeyModifier.meta : HotKeyModifier.control
        ],
      ),
      textColor: Colors.white,
    ),
    KeyBindingText(
      title: 'Search in chat (only when input field is focused)',
      hotKey: HotKey(
        key: LogicalKeyboardKey.keyF,
        modifiers: [
          Platform.isMacOS ? HotKeyModifier.meta : HotKeyModifier.control
        ],
      ),
      textColor: Colors.white,
    ),
  ];

  final _rightKeybindings = <Widget>[
    KeyBindingText(
      title: 'Open/Focus/Hide window',
      hotKey: openWindowHotkey,
      textColor: Colors.white,
    ),
    KeyBindingText(
      title: 'Show overlay for selected text',
      hotKey: showOverlayForText,
      textColor: Colors.white,
    ),
  ];

  @override
  void initState() {
    super.initState();
    final promptsList = customPrompts.value;
    if (promptsList.isNotEmpty) {
      _rightKeybindings.add(const Divider());
    }
    for (final prompt in promptsList) {
      if (prompt.hotkey != null) {
        _rightKeybindings.add(KeyBindingText(
          title: prompt.title,
          hotKey: prompt.hotkey!,
          textColor: Colors.white,
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AnimatedGradientBackgroundMovingCircles(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Center side
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Shortcuts',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'This is your quick shortcuts you can use anytime',
                        style: TextStyle(
                            color: Colors.white.withAlpha(178), fontSize: 14),
                      ),
                    ],
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: AdaptiveLayout(
                        smallLayout: ListView(
                          children: [
                            ..._leftKeybindings,
                            const Divider(),
                            ..._rightKeybindings,
                          ],
                        ),
                        mediumLayout: SingleChildScrollView(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  children: _leftKeybindings,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  children: _rightKeybindings,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class KeyBindingText extends StatelessWidget {
  const KeyBindingText({
    super.key,
    required this.title,
    required this.hotKey,
    this.textColor,
    this.buttonColor,
  });
  final String title;
  final HotKey hotKey;
  final Color? textColor;
  final Color? buttonColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: buttonColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(color: textColor),
          ),
          const SizedBox(width: 16),
          HotKeyVirtualView(hotKey: hotKey),
        ],
      ),
    );
  }
}
