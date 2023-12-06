import 'package:fluent_ui/fluent_ui.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      content: Center(
        child: Text(
          'This is the About page',
          style: TextStyle(fontSize: 24),
        ),
      ),
    );
  }
}
