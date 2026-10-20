import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ledger.dart';

class MaterialUnitsPage extends StatefulWidget {
  const MaterialUnitsPage({
    super.key,
    required this.gateway,
    required this.material,
  });

  final LedgerGateway gateway;
  final LedgerMaterial material;

  @override
  State<MaterialUnitsPage> createState() => _MaterialUnitsPageState();
}

class _MaterialUnitsPageState extends State<MaterialUnitsPage> {
  late Future<List<LedgerMaterialUnit>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.gateway.loadMaterialUnits(widget.material.id);
  }

  void _refresh() {
    setState(() {
      _future = widget.gateway.loadMaterialUnits(widget.material.id);
    });
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _showError(Object error) {
    if (!mounted) {
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

  Future<void> _addUnit() async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _UnitFormDialog(
        gateway: widget.gateway,
        materialId: widget.material.id,
      ),
    );
    if (saved == true) {
      _showMessage('تمت إضافة الوحدة.');
      _refresh();
    }
  }

  Future<void> _deleteUnit(LedgerMaterialUnit unit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الوحدة'),
        content: Text(
          'سيتم حذف وحدة «${unit.name}». '
          'ستُحذف أسعار هذه الوحدة المرتبطة بالمادة. '
          'إذا كانت الوحدة مستخدمة في حركات مخزون أو فواتير فلن يُسمح بالحذف.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    try {
      await widget.gateway.deleteMaterialUnit(
        materialId: widget.material.id,
        unitId: unit.id,
      );
      _showMessage('تم حذف الوحدة.');
      _refresh();
    } catch (error) {
      _showError(error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('وحدات: ${widget.material.name}'),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<List<LedgerMaterialUnit>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'تعذّر تحميل وحدات المادة.\n${describeError(snapshot.error!)}',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _refresh,
                      child: const Text('إعادة المحاولة'),
                    ),
                  ],
                ),
              ),
            );
          }

          final units = snapshot.data!;
          if (units.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.straighten_outlined, size: 48),
                  const SizedBox(height: 8),
                  const Text('لا توجد وحدات لهذه المادة.'),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _addUnit,
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة وحدة'),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
            itemCount: units.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final unit = units[index];
              return ListTile(
                leading: CircleAvatar(
                  child: Icon(
                    unit.isBase ? Icons.lock_outline : Icons.straighten,
                  ),
                ),
                title: Row(
                  children: [
                    Flexible(child: Text(unit.name)),
                    if (unit.isBase) ...[
                      const SizedBox(width: 8),
                      const Chip(
                        label: Text('أساسية'),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  [
                    'معامل التحويل: ${unit.conversionFactor}',
                    if (unit.barcode != null && unit.barcode!.isNotEmpty)
                      'الباركود: ${unit.barcode}',
                    if (unit.isBase) 'الوحدة المرجعية للأسعار',
                  ].join(' • '),
                ),
                trailing: unit.isBase
                    ? const Tooltip(
                        message: 'لا يمكن حذف الوحدة الأساسية',
                        child: Icon(Icons.lock_outline),
                      )
                    : IconButton(
                        tooltip: 'حذف الوحدة',
                        onPressed: () => _deleteUnit(unit),
                        icon: const Icon(Icons.delete_outline),
                      ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addUnit,
        icon: const Icon(Icons.add),
        label: const Text('إضافة وحدة'),
      ),
    );
  }
}

class _UnitFormDialog extends StatefulWidget {
  const _UnitFormDialog({required this.gateway, required this.materialId});

  final LedgerGateway gateway;
  final String materialId;

  @override
  State<_UnitFormDialog> createState() => _UnitFormDialogState();
}

class _UnitFormDialogState extends State<_UnitFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _factor = TextEditingController(text: '1');
  final _barcode = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _factor.dispose();
    _barcode.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.gateway.addMaterialUnit(
        materialId: widget.materialId,
        name: _name.text.trim(),
        conversionFactor: _factor.text.trim(),
        barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
      );
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _error = describeError(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة وحدة'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_error != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.errorContainer,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextFormField(
                  controller: _name,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'اسم الوحدة',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'يجب إدخال اسم الوحدة.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _factor,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'معامل التحويل',
                    helperText: 'كم وحدة أساسية تحتوي هذه الوحدة؟',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    final parsed = double.tryParse(value?.trim() ?? '');
                    if (parsed == null || parsed <= 0) {
                      return 'أدخل معامل تحويل أكبر من صفر.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _barcode,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'الباركود (اختياري)',
                    border: OutlineInputBorder(),
                  ),
                  onFieldSubmitted: (_) => _saving ? null : _save(),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ'),
        ),
      ],
    );
  }
}
