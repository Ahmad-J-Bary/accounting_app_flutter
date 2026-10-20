import 'package:flutter/material.dart';

import 'ledger.dart';

const _arabicMonths = <String>[
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// First-run setup shown before the ledger when the Rust core reports that no
/// company/currency has been configured yet.
class CompanySetupPage extends StatefulWidget {
  const CompanySetupPage({
    super.key,
    required this.gateway,
    required this.initialStatus,
    required this.currencies,
    required this.onCompleted,
  });

  final LedgerGateway gateway;
  final LedgerStatus initialStatus;
  final List<CurrencyOption> currencies;
  final Future<void> Function() onCompleted;

  @override
  State<CompanySetupPage> createState() => _CompanySetupPageState();
}

class _CompanySetupPageState extends State<CompanySetupPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _companyController;
  String _baseCode = '';
  String _secondaryCode = '';
  int _startMonth = 1;
  bool _busy = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _companyController = TextEditingController(
      text: widget.initialStatus.companyName,
    );
    _startMonth = widget.initialStatus.fiscalYearStartMonth.clamp(1, 12);

    final codes = widget.currencies.map((currency) => currency.code).toSet();
    if (widget.initialStatus.baseCurrencyCode.isNotEmpty &&
        codes.contains(widget.initialStatus.baseCurrencyCode)) {
      _baseCode = widget.initialStatus.baseCurrencyCode;
    } else if (codes.contains('SYP')) {
      _baseCode = 'SYP';
    } else if (widget.currencies.isNotEmpty) {
      _baseCode = widget.currencies.first.code;
    }
  }

  @override
  void dispose() {
    _companyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    if (_baseCode.isEmpty) {
      setState(() {
        _error = 'اختر العملة الأساسية أولاً.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.gateway.setupCompany(
        companyName: _companyController.text.trim(),
        baseCurrencyCode: _baseCode,
        secondaryCurrencyCode: _secondaryCode.isEmpty ? null : _secondaryCode,
        fiscalYearStartMonth: _startMonth,
        accountingStartMode: null,
      );
      await widget.onCompleted();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _busy = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذّر إعداد الشركة: ${describeError(error)}'),
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('إعداد الشركة')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'مرحباً بك',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'أدخل بيانات الشركة الأساسية لبدء استخدام النظام. '
                        'سيتم إنشاء دليل الحسابات الافتراضي والسنة المالية الأولى تلقائياً.',
                        style: theme.textTheme.bodyMedium,
                      ),
                      const SizedBox(height: 20),
                      Form(
                        key: _formKey,
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _companyController,
                              enabled: !_busy,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'اسم الشركة',
                                hintText: 'مثال: شركة النور للتجارة',
                                border: OutlineInputBorder(),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'اسم الشركة مطلوب.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              initialValue:
                                  _baseCode.isEmpty ? null : _baseCode,
                              decoration: const InputDecoration(
                                labelText: 'العملة الأساسية',
                                border: OutlineInputBorder(),
                              ),
                              items: widget.currencies
                                  .map(
                                    (currency) => DropdownMenuItem(
                                      value: currency.code,
                                      child: Text(
                                        '${currency.code} — ${currency.displayName}',
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _busy
                                  ? null
                                  : (value) {
                                      if (value != null) {
                                        setState(() => _baseCode = value);
                                      }
                                    },
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'اختر العملة الأساسية.';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<String>(
                              initialValue: _secondaryCode,
                              decoration: const InputDecoration(
                                labelText: 'عملة ثانوية (اختياري)',
                                border: OutlineInputBorder(),
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: '',
                                  child: Text('بدون عملة ثانوية'),
                                ),
                                ...widget.currencies
                                    .where(
                                      (currency) => currency.code != _baseCode,
                                    )
                                    .map(
                                      (currency) => DropdownMenuItem(
                                        value: currency.code,
                                        child: Text(
                                          '${currency.code} — ${currency.displayName}',
                                        ),
                                      ),
                                    ),
                              ],
                              onChanged: _busy
                                  ? null
                                  : (value) {
                                      setState(
                                        () => _secondaryCode = value ?? '',
                                      );
                                    },
                            ),
                            const SizedBox(height: 14),
                            DropdownButtonFormField<int>(
                              initialValue: _startMonth,
                              decoration: const InputDecoration(
                                labelText: 'شهر بداية السنة المالية',
                                border: OutlineInputBorder(),
                              ),
                              items: List.generate(12, (index) {
                                final month = index + 1;
                                return DropdownMenuItem(
                                  value: month,
                                  child: Text(
                                    '$month — ${_arabicMonths[index]}',
                                  ),
                                );
                              }),
                              onChanged: _busy
                                  ? null
                                  : (value) {
                                      if (value != null) {
                                        setState(() => _startMonth = value);
                                      }
                                    },
                            ),
                            if (_error != null) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                  ),
                                ),
                                child: Text(
                                  describeError(_error!),
                                  style: TextStyle(color: Colors.red.shade900),
                                ),
                              ),
                            ],
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: _busy ? null : _submit,
                              icon: _busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.rocket_launch_outlined),
                              label: Text(
                                _busy ? 'جارٍ إعداد الشركة…' : 'بدء الاستخدام',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'ملاحظة: العملة الأساسية وشهر بداية السنة المالية يُحفظان الآن. '
                'يمكن تعديل بيانات الشركة لاحقاً من شاشة الإعدادات.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
