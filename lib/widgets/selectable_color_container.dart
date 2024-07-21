import 'package:flutter/material.dart';

class SelectableColorContainer extends StatelessWidget {
  const SelectableColorContainer({
    super.key,
    required this.selectedColor,
    required this.unselectedColor,
    required this.isSelected,
    required this.child,
    required this.onTap,
  });
  final Color selectedColor;
  final Color? unselectedColor;
  final bool isSelected;
  final Widget child;
  final void Function() onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected ? selectedColor : unselectedColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: child,
      ),
    );
  }
}
