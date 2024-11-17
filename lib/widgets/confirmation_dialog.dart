import 'package:fluent_ui/fluent_ui.dart';

import 'custom_buttons.dart';

class ConfirmationDialog extends StatelessWidget {
  const ConfirmationDialog({
    super.key,
    required this.onAcceptPressed,
    this.isDelete = false,
    this.message,
  });
  final void Function()? onAcceptPressed;
  final bool isDelete;
  final String? message;

  /// Shows a confirmation dialog.
  /// You can use [onAcceptPressed] to handle the action when the user
  /// or wait for the result which is bool
  static Future<bool> show({
    required BuildContext context,
    void Function()? onAcceptPressed,
    bool isDelete = false,
    String? message,
  }) async {
    final result = await showDialog<bool?>(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return ConfirmationDialog(
          onAcceptPressed: onAcceptPressed,
          isDelete: isDelete,
          message: message,
        );
      },
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Are you sure?'),
      content: message != null
          ? Text(message!)
          : const Text('This action cannot be undone.'),
      actions: [
        Button(
          onPressed: () {
            Navigator.of(context).pop(false);
          },
          child: const Text('Cancel'),
        ),
        isDelete
            ? FilledRedButton(
                autofocus: true,
                onPressed: () {
                  onAcceptPressed?.call();
                  Navigator.of(context).pop(true);
                },
                child: const Text('Delete'))
            : FilledButton(
                autofocus: true,
                onPressed: () {
                  onAcceptPressed?.call();
                  Navigator.of(context).pop(true);
                },
                child: const Text('Accept')),
      ],
    );
  }
}
