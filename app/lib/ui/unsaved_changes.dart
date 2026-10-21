import 'package:flutter/material.dart';

/// Blocks system/in-app back while a form has unsaved changes and asks for
/// confirmation before discarding them.
class UnsavedChangesGuard extends StatelessWidget {
  const UnsavedChangesGuard({
    super.key,
    required this.hasUnsavedChanges,
    required this.child,
    this.title = 'تغييرات غير محفوظة',
    this.message = 'هل تريد مغادرة الصفحة دون حفظ التغييرات؟',
    this.discardLabel = 'مغادرة دون حفظ',
    this.stayLabel = 'البقاء',
  });

  final bool hasUnsavedChanges;
  final Widget child;
  final String title;
  final String message;
  final String discardLabel;
  final String stayLabel;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final discard = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(stayLabel),
              ),
              FilledButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(discardLabel),
              ),
            ],
          ),
        );
        if (discard == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: child,
    );
  }
}
