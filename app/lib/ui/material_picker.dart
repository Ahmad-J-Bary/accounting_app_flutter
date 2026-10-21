import 'package:flutter/material.dart';

import '../ledger.dart';
import '../theme/app_theme.dart';

/// A searchable material picker.
///
/// The React document grid opens a floating panel that filters the materials
/// by name, code or barcode. A dropdown that lists every material becomes
/// unusable once a company owns a few hundred of them, so the Flutter editors
/// use this field instead.
class AppMaterialPicker extends StatelessWidget {
  const AppMaterialPicker({
    super.key,
    required this.label,
    required this.materials,
    required this.selectedId,
    required this.onSelected,
    this.isSales = true,
    this.emptyMessage = 'لا توجد مواد مطابقة.',
    this.hideLabel = false,
  });

  final String label;
  final List<LedgerMaterial> materials;
  final String? selectedId;

  /// Called with the picked material, or with null when the selection is
  /// cleared.
  final ValueChanged<LedgerMaterial?> onSelected;
  final bool isSales;
  final String emptyMessage;

  /// Hides the floating label of the field, for the line grid where the
  /// column header already names it.
  final bool hideLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = materials
        .where((material) => material.id == selectedId)
        .firstOrNull;
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: hideLabel ? null : label,
          prefixIcon: const Icon(Icons.inventory_2_outlined),
          suffixIcon: const Icon(Icons.search, size: 18),
        ),
        child: Text(
          selected == null
              ? 'اختر مادة'
              : '${selected.name} (${selected.code})',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: selected == null
              ? theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )
              : null,
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final material = await showDialog<LedgerMaterial>(
      context: context,
      builder: (dialogContext) => _MaterialPickerDialog(
        label: label,
        materials: materials,
        isSales: isSales,
        emptyMessage: emptyMessage,
      ),
    );
    if (material != null) {
      onSelected(material);
    }
  }
}

class _MaterialPickerDialog extends StatefulWidget {
  const _MaterialPickerDialog({
    required this.label,
    required this.materials,
    required this.isSales,
    required this.emptyMessage,
  });

  final String label;
  final List<LedgerMaterial> materials;
  final bool isSales;
  final String emptyMessage;

  @override
  State<_MaterialPickerDialog> createState() => _MaterialPickerDialogState();
}

class _MaterialPickerDialogState extends State<_MaterialPickerDialog> {
  final TextEditingController _controller = TextEditingController();
  String _query = '';

  /// The React panel caps the list at thirty results.
  static const int _maxResults = 30;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<LedgerMaterial> get _results {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) {
      return widget.materials.take(_maxResults).toList(growable: false);
    }
    final matches = <LedgerMaterial>[];
    for (final material in widget.materials) {
      if (_matches(material, query)) {
        matches.add(material);
        if (matches.length >= _maxResults) {
          break;
        }
      }
    }
    return matches;
  }

  bool _matches(LedgerMaterial material, String query) {
    if (material.name.toLowerCase().contains(query) ||
        material.nameEn.toLowerCase().contains(query) ||
        material.code.toLowerCase().contains(query) ||
        material.barcode.toLowerCase().contains(query)) {
      return true;
    }
    // A unit barcode identifies the material as well.
    for (final unit in material.units) {
      final barcode = unit.barcode?.toLowerCase() ?? '';
      if (barcode.isNotEmpty && barcode.contains(query)) {
        return true;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final results = _results;
    return AlertDialog(
      title: Text(widget.label),
      content: SizedBox(
        width: 520,
        height: 420,
        child: Column(
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: 'ابحث بالاسم أو الرمز أو الباركود…',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'مسح البحث',
                        onPressed: () {
                          _controller.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close, size: 18),
                      ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Text(
                        widget.emptyMessage,
                        style: theme.textTheme.bodyMedium,
                      ),
                    )
                  : ListView.separated(
                      itemCount: results.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final material = results[index];
                        final price = widget.isSales
                            ? material.salePrice
                            : material.purchasePrice;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.sm,
                          ),
                          title: Text(
                            material.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${material.code}'
                            '${material.barcode.isEmpty ? '' : ' • ${material.barcode}'}'
                            '${price.isEmpty ? '' : ' • $price'}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => Navigator.of(context).pop(material),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
      ],
    );
  }
}
