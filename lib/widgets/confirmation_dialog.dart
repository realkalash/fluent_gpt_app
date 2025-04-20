import 'package:fluent_gpt/i18n/i18n.dart';
import 'package:fluent_ui/fluent_ui.dart';

import 'custom_buttons.dart';

class ConfirmationDialog extends StatefulWidget {
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
      useRootNavigator: true,
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
  State<ConfirmationDialog> createState() => _ConfirmationDialogState();
}

class _ConfirmationDialogState extends State<ConfirmationDialog> {
  final focus = FocusNode();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      // get main focus and unfocus it
      FocusManager.instance.primaryFocus?.unfocus();
      // wait for unfocus
      await Future.delayed(const Duration(milliseconds: 50));
      focus.requestFocus();
    });
  }

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title:  Text('Are you sure?'.tr),
      content: widget.message != null
          ? Text(widget.message!)
          : Text('This action cannot be undone.'.tr),
      actions: [
        Button(
          focusNode: focus,
          onPressed: () {
            Navigator.of(context).pop(false);
          },
          child: Text('Cancel'.tr),
        ),
        widget.isDelete
            ? FilledRedButton(
                onPressed: () {
                  widget.onAcceptPressed?.call();
                  Navigator.of(context).pop(true);
                },
                child: Text('Delete'.tr))
            : FilledButton(
                onPressed: () {
                  widget.onAcceptPressed?.call();
                  Navigator.of(context).pop(true);
                },
                child: Text('Accept'.tr)),
      ],
    );
  }
}
