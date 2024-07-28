import 'package:fluent_gpt/navigation_provider.dart';
import 'package:fluent_gpt/pages/welcome/welcome_screen.dart';
import 'package:fluent_gpt/utils.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:window_manager/window_manager.dart';

class WelcomeTab extends StatelessWidget {
  const WelcomeTab({super.key});

  @override
  Widget build(BuildContext context) {
    final navProvider = context.read<NavigationProvider>();
    final pageController = navProvider.welcomeScreenPageController;
    return Stack(
      fit: StackFit.expand,
      children: [
        const AnimatedGradientBackgroundMovingCircles(),
        GestureDetector(
          onPanUpdate: (details) {
            windowManager.startDragging();
          },
          child: Scaffold(
            bottomNavigationBar: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  SmoothPageIndicator(
                    controller: pageController,
                    count: navProvider.welcomeScreens.length,
                    effect: WormEffect(
                      dotWidth: 16,
                      dotHeight: 10,
                      paintStyle: PaintingStyle.stroke,
                      activeDotColor: context.theme.accentColor,
                    ),
                    onDotClicked: (index) {
                      navProvider.welcomeScreenPageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 1000),
                          curve: Curves.fastEaseInToSlowEaseOut);
                    },
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      navProvider.welcomeScreenNext();
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ),
            body: PageView(
              controller: pageController,
              physics: const NeverScrollableScrollPhysics(),
              children: navProvider.welcomeScreens,
            ),
          ),
        ),
      ],
    );
  }
}
