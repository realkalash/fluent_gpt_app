extension WordExtension on String {
  String capitalize() =>
      isEmpty || length < 2 ? this : "${this[0].toUpperCase()}${substring(1)}";
  String toLowerCaseFirst() => isEmpty || length < 2
      ? toLowerCase()
      : "${this[0].toLowerCase()}${substring(1)}";
  bool get noWords => RegExp(
          r'''[\p{P}\p{N}\p{Pd}\p{Nd}\p{Nl}\p{Pi}\p{No}\p{Pf}\p{Pc}\p{Ps}\p{Cf}\p{Co}\p{Cn}\p{Cs}\p{Pe}\p{S}\p{Sm}\p{Sc}\p{Sk}\p{So}\p{Cc}\p{Po}\p{Mc}]''',
          unicode: true)
      .hasMatch(this);
}
