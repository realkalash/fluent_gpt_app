import 'package:fluent_ui/fluent_ui.dart';

extension ThemeExtension on BuildContext {
  FluentThemeData get theme => FluentTheme.of(this);
}
