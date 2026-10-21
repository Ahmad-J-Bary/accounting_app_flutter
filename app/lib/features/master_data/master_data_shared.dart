import 'package:flutter/material.dart';

import '../../ledger.dart';
import '../../theme/app_theme.dart';
import '../../ui/app_ui.dart';

enum MasterDataRowAction { edit, delete, units }

/// Shared row menu for the three master-data pages.
class MasterDataRowActions extends StatelessWidget {
  const MasterDataRowActions({
    super.key,
    required this.onEdit,
    required this.onDelete,
    this.onUnits,
    this.extraActions = const <PopupMenuEntry<MasterDataRowAction>>[],
  });

  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onUnits;
  final List<PopupMenuEntry<MasterDataRowAction>> extraActions;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<MasterDataRowAction>(
      tooltip: 'إجراءات',
      icon: const Icon(Icons.more_horiz, size: 19),
      onSelected: (action) {
        switch (action) {
          case MasterDataRowAction.edit:
            onEdit();
            break;
          case MasterDataRowAction.delete:
            onDelete();
            break;
          case MasterDataRowAction.units:
            onUnits?.call();
            break;
        }
      },
      itemBuilder: (context) => <PopupMenuEntry<MasterDataRowAction>>[
        const PopupMenuItem(
          value: MasterDataRowAction.edit,
          child: _ActionRow(icon: Icons.edit_outlined, label: 'تعديل'),
        ),
        if (onUnits != null)
          const PopupMenuItem(
            value: MasterDataRowAction.units,
            child: _ActionRow(icon: Icons.straighten, label: 'الوحدات'),
          ),
        ...extraActions,
        const PopupMenuItem(
          value: MasterDataRowAction.delete,
          child: _ActionRow(icon: Icons.delete_outline, label: 'حذف'),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [Icon(icon, size: 17), const SizedBox(width: 8), Text(label)],
    );
  }
}

/// Search + filter strip shared by the master-data pages.
class MasterDataSearchBar extends StatelessWidget {
  const MasterDataSearchBar({
    super.key,
    required this.controller,
    required this.hintText,
    required this.onChanged,
    required this.resultCount,
    this.filters = const <Widget>[],
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String> onChanged;
  final int resultCount;
  final List<Widget> filters;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final search = AppSearchField(
            controller: controller,
            hintText: hintText,
            onChanged: onChanged,
          );
          final count = AppBadge(
            label: '$resultCount نتيجة',
            tone: AppBadgeTone.neutral,
            icon: Icons.filter_alt_outlined,
          );
          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                search,
                if (filters.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Wrap(spacing: AppSpacing.sm, children: filters),
                ],
                const SizedBox(height: AppSpacing.sm),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: count,
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: search),
              if (filters.isNotEmpty) ...[
                const SizedBox(width: AppSpacing.md),
                ...filters,
              ],
              const SizedBox(width: AppSpacing.md),
              count,
            ],
          );
        },
      ),
    );
  }
}

Future<bool> confirmMasterDataDelete(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('حذف'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

void showMasterDataMessage(BuildContext context, String message) {
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

void showMasterDataError(BuildContext context, Object error) {
  if (!context.mounted) {
    return;
  }
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(describeError(error)),
        duration: const Duration(seconds: 6),
      ),
    );
}
