import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_moving_background/enums/animation_types.dart';
import 'package:simple_animations/simple_animations.dart';
import 'package:flutter_moving_background/flutter_moving_background.dart';
import 'package:widget_and_text_animator/widget_and_text_animator.dart';
import 'package:window_manager/window_manager.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  @override
  void initState() {
    windowManager.setTitleBarStyle(TitleBarStyle.hidden,
        windowButtonVisibility: false);
    super.initState();
    if (Platform.isMacOS) {
      Future.delayed(const Duration(milliseconds: 100)).then((_) async {
        Size windowSize = await windowManager.getSize();
        Offset position =
            await calcWindowPosition(windowSize, Alignment.center);
        await windowManager.setBounds(
          null,
          size: const Size(800, 500),
          position: position.translate(0, 0),
          animate: true,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanUpdate: (details) {
        windowManager.startDragging();
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Center side
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 16),
                      const TextAnimator(
                        'WELCOME!',
                        initialDelay: Duration(milliseconds: 500),
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 40,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      TextAnimator(
                        'We will ask for some permissions to make sure you have the best experience.',
                        initialDelay: const Duration(milliseconds: 1000),
                        characterDelay: const Duration(milliseconds: 15),
                        style: TextStyle(
                            color: Colors.white.withOpacity(0.7), fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AnimatedGradientBackground extends StatelessWidget {
  const AnimatedGradientBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return MirrorAnimationBuilder<Color?>(
      tween: ColorTween(
          begin: const Color(0xFF1a1a1a),
          end: const Color.fromARGB(255, 15, 25, 36)),
      duration: const Duration(seconds: 1),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                value!,
                const Color(0xFF1a1a1a),
              ],
            ),
          ),
        );
      },
    );
  }
}

class AnimatedGradientBackgroundMovingCircles extends StatelessWidget {
  const AnimatedGradientBackgroundMovingCircles({super.key});

  @override
  Widget build(BuildContext context) {
    return const MovingBackground(
      backgroundColor: Color.fromARGB(120, 26, 26, 26),
      animationType: AnimationType.rain,
      duration: Duration(seconds: 30),
      circles: [
        MovingCircle(color: Colors.purple),
        MovingCircle(color: Colors.deepPurple, radius: 1000, blurSigma: 50),
        MovingCircle(color: Colors.orange),
        MovingCircle(color: Colors.orangeAccent),
      ],
    );
  }
}

class PermissionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool isGranted;
  final VoidCallback? onGrantAccessTap;

  const PermissionItem({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.isGranted,
    this.onGrantAccessTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(description,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        isGranted
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Access Granted',
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              )
            : ElevatedButton(
                onPressed: onGrantAccessTap,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey[800],
                  foregroundColor: Colors.white,
                ),
                child: const Text('Grant Access'),
              ),
      ],
    );
  }
}
