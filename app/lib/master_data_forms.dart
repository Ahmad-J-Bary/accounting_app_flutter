import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'categories.dart';
import 'ledger.dart';

String? _requiredText(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'هذا الحقل مطلوب.';
  }
  return null;
}

String? _nonNegativeNumber(String? value, {bool required = false}) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) {
    return required ? 'هذا الحقل مطلوب.' : null;
  }
  final parsed = double.tryParse(text);
  if (parsed == null) {
    return 'أدخل رقماً صحيحاً.';
  }
  if (parsed < 0) {
    return 'لا يمكن أن يكون الرقم سالباً.';
  }
  return null;
}

String? _positiveNumber(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) {
    return 'هذا الحقل مطلوب.';
  }
  final parsed = double.tryParse(text);
  if (parsed == null) {
    return 'أدخل رقماً صحيحاً.';
  }
  if (parsed <= 0) {
    return 'يجب أن يكون الرقم أكبر من صفر.';
  }
  return null;
}

String? _optional(String? value) {
  final text = value?.trim() ?? '';
  return text.isEmpty ? null : text;
}

List<String> _currencyCodes(List<CurrencyOption> currencies, String fallback) {
  final codes = currencies
      .map((currency) => currency.code)
      .where((code) => code.trim().isNotEmpty)
      .toList();
  if (fallback.trim().isNotEmpty && !codes.contains(fallback)) {
    codes.insert(0, fallback);
  }
  return codes;
}

class CustomerFormPage extends StatefulWidget {
  const CustomerFormPage({
    super.key,
    required this.gateway,
    required this.currencies,
    required this.baseCurrency,
    this.customer,
  });

  final LedgerGateway gateway;
  final List<CurrencyOption> currencies;
  final String baseCurrency;
  final LedgerCustomer? customer;

  @override
  State<CustomerFormPage> createState() => _CustomerFormPageState();
}

class _CustomerFormPageState extends State<CustomerFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _notes;
  late final TextEditingController _openingBalance;
  late String _currency;
  late bool _isActive;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.customer != null;

  @override
  void initState() {
    super.initState();
    final customer = widget.customer;
    _name = TextEditingController(text: customer?.name ?? '');
    _phone = TextEditingController(text: customer?.phone ?? '');
    _address = TextEditingController(text: customer?.address ?? '');
    _notes = TextEditingController(text: customer?.notes ?? '');
    _openingBalance = TextEditingController(
      text: customer?.openingBalance ?? '0',
    );
    _currency = customer?.currency ?? widget.baseCurrency;
    _isActive = customer?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _notes.dispose();
    _openingBalance.dispose();
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
      if (_isEdit) {
        await widget.gateway.updateCustomer(
          id: widget.customer!.id,
          code: widget.customer!.code,
          name: _name.text.trim(),
          phone: _optional(_phone.text),
          address: _optional(_address.text),
          notes: _optional(_notes.text),
          isActive: _isActive,
        );
      } else {
        await widget.gateway.createCustomer(
          name: _name.text.trim(),
          phone: _optional(_phone.text),
          address: _optional(_address.text),
          notes: _optional(_notes.text),
          currency: _currency,
          openingBalance: _openingBalance.text.trim().isEmpty
              ? '0'
              : _openingBalance.text.trim(),
        );
      }
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
    final codes = _currencyCodes(widget.currencies, _currency);

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'تعديل عميل' : 'إضافة عميل')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null) ...[
                _ErrorBanner(message: _error!),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _name,
                autofocus: !_isEdit,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'اسم العميل',
                  border: OutlineInputBorder(),
                ),
                validator: _requiredText,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'الهاتف (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'العنوان (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: codes.contains(_currency) ? _currency : null,
                decoration: const InputDecoration(
                  labelText: 'العملة',
                  border: OutlineInputBorder(),
                ),
                items: codes
                    .map(
                      (code) =>
                          DropdownMenuItem(value: code, child: Text(code)),
                    )
                    .toList(),
                onChanged: _isEdit
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _currency = value);
                        }
                      },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _openingBalance,
                enabled: !_isEdit,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: 'الرصيد الافتتاحي (مدين)',
                  helperText: _isEdit
                      ? 'يمكن تعديل الرصيد الافتتاحي من شاشة «الأرصدة الافتتاحية».'
                      : 'المبلغ الذي على العميل دفعه لنا عند بداية النظام.',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => _nonNegativeNumber(value),
              ),
              if (_isEdit) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('نشط'),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SupplierFormPage extends StatefulWidget {
  const SupplierFormPage({
    super.key,
    required this.gateway,
    required this.currencies,
    required this.baseCurrency,
    this.supplier,
  });

  final LedgerGateway gateway;
  final List<CurrencyOption> currencies;
  final String baseCurrency;
  final LedgerSupplier? supplier;

  @override
  State<SupplierFormPage> createState() => _SupplierFormPageState();
}

class _SupplierFormPageState extends State<SupplierFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _address;
  late final TextEditingController _notes;
  late final TextEditingController _openingBalance;
  late String _currency;
  late bool _isActive;
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.supplier != null;

  @override
  void initState() {
    super.initState();
    final supplier = widget.supplier;
    _name = TextEditingController(text: supplier?.name ?? '');
    _phone = TextEditingController(text: supplier?.phone ?? '');
    _address = TextEditingController(text: supplier?.address ?? '');
    _notes = TextEditingController(text: supplier?.notes ?? '');
    _openingBalance = TextEditingController(
      text: supplier?.openingBalance ?? '0',
    );
    _currency = supplier?.currency ?? widget.baseCurrency;
    _isActive = supplier?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _address.dispose();
    _notes.dispose();
    _openingBalance.dispose();
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
      if (_isEdit) {
        await widget.gateway.updateSupplier(
          id: widget.supplier!.id,
          code: widget.supplier!.code,
          name: _name.text.trim(),
          phone: _optional(_phone.text),
          address: _optional(_address.text),
          notes: _optional(_notes.text),
          isActive: _isActive,
        );
      } else {
        await widget.gateway.createSupplier(
          name: _name.text.trim(),
          phone: _optional(_phone.text),
          address: _optional(_address.text),
          notes: _optional(_notes.text),
          currency: _currency,
          openingBalance: _openingBalance.text.trim().isEmpty
              ? '0'
              : _openingBalance.text.trim(),
        );
      }
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
    final codes = _currencyCodes(widget.currencies, _currency);

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'تعديل مورد' : 'إضافة مورد')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null) ...[
                _ErrorBanner(message: _error!),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _name,
                autofocus: !_isEdit,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'اسم المورد',
                  border: OutlineInputBorder(),
                ),
                validator: _requiredText,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                textInputAction: TextInputAction.next,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'الهاتف (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _address,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'العنوان (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: codes.contains(_currency) ? _currency : null,
                decoration: const InputDecoration(
                  labelText: 'العملة',
                  border: OutlineInputBorder(),
                ),
                items: codes
                    .map(
                      (code) =>
                          DropdownMenuItem(value: code, child: Text(code)),
                    )
                    .toList(),
                onChanged: _isEdit
                    ? null
                    : (value) {
                        if (value != null) {
                          setState(() => _currency = value);
                        }
                      },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _openingBalance,
                enabled: !_isEdit,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                ],
                decoration: InputDecoration(
                  labelText: 'الرصيد الافتتاحي (دائن)',
                  helperText: _isEdit
                      ? 'يمكن تعديل الرصيد الافتتاحي من شاشة «الأرصدة الافتتاحية».'
                      : 'المبلغ الذي علينا دفعه للمورد عند بداية النظام.',
                  border: const OutlineInputBorder(),
                ),
                validator: (value) => _nonNegativeNumber(value),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              if (_isEdit) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('نشط'),
                  subtitle: const Text(
                    'المورد غير النشط يبقى في السجلات ولا يظهر في القوائم التشغيلية.',
                  ),
                  value: _isActive,
                  onChanged: (value) => setState(() => _isActive = value),
                ),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MaterialFormPage extends StatefulWidget {
  const MaterialFormPage({
    super.key,
    required this.gateway,
    required this.currencies,
    required this.baseCurrency,
    required this.categories,
    this.material,
  });

  final LedgerGateway gateway;
  final List<CurrencyOption> currencies;
  final String baseCurrency;
  final List<LedgerCategory> categories;
  final LedgerMaterial? material;

  @override
  State<MaterialFormPage> createState() => _MaterialFormPageState();
}

class _MaterialFormPageState extends State<MaterialFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _nameEn;
  late final TextEditingController _barcode;
  late final TextEditingController _code;
  late final TextEditingController _minimumStock;
  late final TextEditingController _unitName;
  late final TextEditingController _conversionFactor;
  late final TextEditingController _purchasePrice;
  late final TextEditingController _salePrice;
  late final TextEditingController _notes;
  late final TextEditingController _expiryDays;
  late String _currency;
  late bool _hasExpiry;
  final Set<String> _selectedCategoryIds = {};
  final List<_ExtraUnitControllers> _extraUnits = [];
  bool _saving = false;
  String? _error;

  bool get _isEdit => widget.material != null;

  @override
  void initState() {
    super.initState();
    final material = widget.material;
    _name = TextEditingController(text: material?.name ?? '');
    _nameEn = TextEditingController(text: material?.nameEn ?? '');
    _barcode = TextEditingController(text: material?.barcode ?? '');
    _code = TextEditingController(text: material?.code ?? '');
    _minimumStock = TextEditingController(text: material?.minimumStock ?? '0');
    _unitName = TextEditingController(text: material?.unitName ?? '');
    _conversionFactor = TextEditingController(
      text: material?.conversionFactor ?? '1',
    );
    _purchasePrice = TextEditingController(text: material?.purchasePrice ?? '');
    _salePrice = TextEditingController(text: material?.salePrice ?? '');
    _notes = TextEditingController(text: material?.notes ?? '');
    _expiryDays = TextEditingController(
      text: (material?.expiryAlertBeforeDays ?? 30).toString(),
    );
    _currency = material?.currency ?? widget.baseCurrency;
    _hasExpiry = material?.hasExpiry ?? false;
    _selectedCategoryIds.addAll(material?.categoryIds ?? const []);
    if (_selectedCategoryIds.isEmpty) {
      for (final category in widget.categories) {
        if (category.isSystem) {
          _selectedCategoryIds.add(category.id);
          break;
        }
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _nameEn.dispose();
    _barcode.dispose();
    _code.dispose();
    _minimumStock.dispose();
    _unitName.dispose();
    _conversionFactor.dispose();
    _purchasePrice.dispose();
    _salePrice.dispose();
    _notes.dispose();
    _expiryDays.dispose();
    for (final unit in _extraUnits) {
      unit.dispose();
    }
    super.dispose();
  }

  void _addExtraUnit() {
    setState(() {
      _extraUnits.add(_ExtraUnitControllers());
    });
  }

  void _removeExtraUnit(int index) {
    setState(() {
      final unit = _extraUnits.removeAt(index);
      unit.dispose();
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final expiryDays = int.tryParse(_expiryDays.text.trim()) ?? 30;
    final extraUnits = _extraUnits
        .map(
          (unit) => MaterialUnitDraft(
            name: unit.name.text.trim(),
            conversionFactor: unit.factor.text.trim().isEmpty
                ? '1'
                : unit.factor.text.trim(),
            barcode: _optional(unit.barcode.text),
          ),
        )
        .toList();

    try {
      if (_isEdit) {
        await widget.gateway.updateMaterial(
          id: widget.material!.id,
          name: _name.text.trim(),
          nameEn: _nameEn.text.trim(),
          barcode: _barcode.text.trim(),
          code: _code.text.trim().isEmpty
              ? widget.material!.code
              : _code.text.trim(),
          minimumStock: _minimumStock.text.trim().isEmpty
              ? '0'
              : _minimumStock.text.trim(),
          categoryIds: _selectedCategoryIds.toList(),
          notes: _optional(_notes.text),
          purchasePrice: _optional(_purchasePrice.text),
          salePrice: _optional(_salePrice.text),
          currency: _currency,
          hasExpiry: _hasExpiry,
          expiryAlertBeforeDays: expiryDays,
        );
      } else {
        await widget.gateway.createMaterial(
          name: _name.text.trim(),
          nameEn: _optional(_nameEn.text),
          barcode: _optional(_barcode.text),
          code: _optional(_code.text),
          minimumStock: _minimumStock.text.trim().isEmpty
              ? '0'
              : _minimumStock.text.trim(),
          unitName: _unitName.text.trim(),
          conversionFactor: _conversionFactor.text.trim().isEmpty
              ? '1'
              : _conversionFactor.text.trim(),
          extraUnits: extraUnits,
          categoryIds: _selectedCategoryIds.toList(),
          purchasePrice: _optional(_purchasePrice.text),
          salePrice: _optional(_salePrice.text),
          currency: _currency,
          notes: _optional(_notes.text),
          hasExpiry: _hasExpiry,
          expiryAlertBeforeDays: expiryDays,
        );
      }
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

  Widget _buildCategoryChips() {
    final visible = widget.categories
        .where(
          (category) =>
              category.isActive || _selectedCategoryIds.contains(category.id),
        )
        .toList();
    if (visible.isEmpty) {
      return const Text(
        'لا توجد تصنيفات نشطة. أنشئ تصنيفًا من شاشة التصنيفات.',
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: visible
          .map(
            (category) => FilterChip(
              label: Text(categoryLabel(category, widget.categories)),
              selected: _selectedCategoryIds.contains(category.id),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    if (category.isSystem) {
                      _selectedCategoryIds.clear();
                    } else {
                      _selectedCategoryIds.removeWhere(
                        (id) => widget.categories.any(
                          (candidate) =>
                              candidate.id == id && candidate.isSystem,
                        ),
                      );
                    }
                    _selectedCategoryIds.add(category.id);
                  } else {
                    _selectedCategoryIds.remove(category.id);
                  }
                });
              },
            ),
          )
          .toList(),
    );
  }

  Widget _buildExtraUnits() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'وحدات إضافية',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                TextButton.icon(
                  onPressed: _addExtraUnit,
                  icon: const Icon(Icons.add),
                  label: const Text('إضافة وحدة'),
                ),
              ],
            ),
            Text(
              'الوحدة الأساسية هي وحدة المخزون والأسعار. أضف وحدات مثل الكرتونة أو الكيس مع معامل التحويل.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (_extraUnits.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text('لم تُضف وحدات إضافية.'),
              ),
            ..._extraUnits.asMap().entries.map((entry) {
              final index = entry.key;
              final unit = entry.value;
              return Column(
                key: ObjectKey(unit),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: unit.name,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'اسم الوحدة',
                            border: OutlineInputBorder(),
                          ),
                          validator: _requiredText,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: unit.factor,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.]'),
                            ),
                          ],
                          decoration: const InputDecoration(
                            labelText: 'معامل التحويل',
                            border: OutlineInputBorder(),
                          ),
                          validator: _positiveNumber,
                        ),
                      ),
                      IconButton(
                        tooltip: 'حذف الوحدة',
                        onPressed: () => _removeExtraUnit(index),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: unit.barcode,
                    decoration: const InputDecoration(
                      labelText: 'باركود الوحدة (اختياري)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final codes = _currencyCodes(widget.currencies, _currency);

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'تعديل مادة' : 'إضافة مادة')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null) ...[
                _ErrorBanner(message: _error!),
                const SizedBox(height: 12),
              ],
              if (_isEdit) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      'لا يمكن تغيير وحدة القياس أو معامل التحويل بعد إنشاء المادة. '
                      'يمكن تعديل الأسعار والبيانات الوصفية.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _name,
                autofocus: !_isEdit,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'اسم المادة',
                  border: OutlineInputBorder(),
                ),
                validator: _requiredText,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameEn,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'الاسم الإنجليزي (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _code,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'رمز المادة (اختياري)',
                  helperText: _isEdit
                      ? null
                      : 'اتركه فارغاً ليُولَّد تلقائياً.',
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _barcode,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'الباركود (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'التصنيفات',
                  helperText:
                      'يمكن اختيار أكثر من تصنيف. يُستخدم التصنيف الافتراضي عند عدم الاختيار.',
                  border: OutlineInputBorder(),
                ),
                child: _buildCategoryChips(),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _unitName,
                      enabled: !_isEdit,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'وحدة القياس',
                        border: OutlineInputBorder(),
                      ),
                      validator: _isEdit ? null : _requiredText,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _conversionFactor,
                      enabled: !_isEdit,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'معامل التحويل',
                        border: OutlineInputBorder(),
                      ),
                      validator: _isEdit ? null : _positiveNumber,
                    ),
                  ),
                ],
              ),
              if (!_isEdit) ...[const SizedBox(height: 12), _buildExtraUnits()],
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _minimumStock,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'الحد الأدنى للمخزون',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => _nonNegativeNumber(value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: codes.contains(_currency)
                          ? _currency
                          : null,
                      decoration: const InputDecoration(
                        labelText: 'عملة الأسعار',
                        border: OutlineInputBorder(),
                      ),
                      items: codes
                          .map(
                            (code) => DropdownMenuItem(
                              value: code,
                              child: Text(code),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => _currency = value);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _purchasePrice,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'سعر الشراء (اختياري)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => _nonNegativeNumber(value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _salePrice,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'سعر البيع (اختياري)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) => _nonNegativeNumber(value),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('له تاريخ صلاحية'),
                value: _hasExpiry,
                onChanged: (value) => setState(() => _hasExpiry = value),
              ),
              if (_hasExpiry) ...[
                const SizedBox(height: 4),
                TextFormField(
                  controller: _expiryDays,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'تنبيه قبل انتهاء الصلاحية (أيام)',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => _nonNegativeNumber(value),
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? 'جارٍ الحفظ…' : 'حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExtraUnitControllers {
  final name = TextEditingController();
  final factor = TextEditingController(text: '1');
  final barcode = TextEditingController();

  void dispose() {
    name.dispose();
    factor.dispose();
    barcode.dispose();
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}
