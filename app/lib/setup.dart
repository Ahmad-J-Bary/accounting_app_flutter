import 'package:flutter/material.dart';

import 'ledger.dart';
import 'theme/app_theme.dart';
import 'ui/app_ui.dart';

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
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعداد الشركة'),
        actions: [
          IconButton(
            tooltip: Theme.of(context).brightness == Brightness.dark
                ? 'الوضع الفاتح'
                : 'الوضع الداكن',
            onPressed: () => AppThemeScope.of(context).toggle(),
            icon: Icon(
              Theme.of(context).brightness == Brightness.dark
                  ? Icons.light_mode_outlined
                  : Icons.dark_mode_outlined,
            ),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1000;
          if (!wide) {
            return ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                _SetupFormCard(
                  formKey: _formKey,
                  companyController: _companyController,
                  currencies: widget.currencies,
                  baseCode: _baseCode,
                  secondaryCode: _secondaryCode,
                  startMonth: _startMonth,
                  busy: _busy,
                  error: _error,
                  onBaseChanged: (value) => setState(() => _baseCode = value),
                  onSecondaryChanged: (value) =>
                      setState(() => _secondaryCode = value),
                  onMonthChanged: (value) =>
                      setState(() => _startMonth = value),
                  onSubmit: _submit,
                ),
              ],
            );
          }
          return Row(
            children: [
              const Expanded(flex: 5, child: _SetupBrandPanel()),
              Expanded(
                flex: 6,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.xxl),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: _SetupFormCard(
                        formKey: _formKey,
                        companyController: _companyController,
                        currencies: widget.currencies,
                        baseCode: _baseCode,
                        secondaryCode: _secondaryCode,
                        startMonth: _startMonth,
                        busy: _busy,
                        error: _error,
                        onBaseChanged: (value) =>
                            setState(() => _baseCode = value),
                        onSecondaryChanged: (value) =>
                            setState(() => _secondaryCode = value),
                        onMonthChanged: (value) =>
                            setState(() => _startMonth = value),
                        onSubmit: _submit,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SetupBrandPanel extends StatelessWidget {
  const _SetupBrandPanel();

  @override
  Widget build(BuildContext context) {
    final semantic = context.semanticColors;
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
          colors: [semantic.sidebarBackground, const Color(0xFF16375C)],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xxl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                  size: 26,
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                'المحاسبة',
                style: theme.textTheme.displaySmall?.copyWith(
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'نظام محاسبي مكتبي يعمل محلياً فوق قاعدة بيانات SQLite مع نواة Rust موثوقة.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),
              const _SetupFeature(
                icon: Icons.account_tree_outlined,
                title: 'دليل حسابات جاهز',
                message: 'يُنشأ تلقائياً مع السنة المالية الأولى.',
              ),
              const _SetupFeature(
                icon: Icons.menu_book_outlined,
                title: 'قيود متوازنة',
                message: 'تحقق مزدوج للطرف المدين والدائن.',
              ),
              const _SetupFeature(
                icon: Icons.inventory_2_outlined,
                title: 'مخزون ووحدات',
                message: 'أصناف، وحدات متعددة، وأسعار شراء وبيع.',
              ),
              const _SetupFeature(
                icon: Icons.lock_outline,
                title: 'بيانات على جهازك',
                message: 'لا اتصال خارجي ولا تخزين سحابي.',
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'يمكن تعديل بيانات الشركة لاحقاً من الإعدادات.',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SetupFeature extends StatelessWidget {
  const _SetupFeature({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetupFormCard extends StatelessWidget {
  const _SetupFormCard({
    required this.formKey,
    required this.companyController,
    required this.currencies,
    required this.baseCode,
    required this.secondaryCode,
    required this.startMonth,
    required this.busy,
    required this.error,
    required this.onBaseChanged,
    required this.onSecondaryChanged,
    required this.onMonthChanged,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController companyController;
  final List<CurrencyOption> currencies;
  final String baseCode;
  final String secondaryCode;
  final int startMonth;
  final bool busy;
  final Object? error;
  final ValueChanged<String> onBaseChanged;
  final ValueChanged<String> onSecondaryChanged;
  final ValueChanged<int> onMonthChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AppCard(
      radius: AppRadius.xxl,
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const AppIconTile(
                icon: Icons.rocket_launch_outlined,
                size: 44,
                iconSize: 22,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('مرحباً بك', style: theme.textTheme.headlineSmall),
                    Text(
                      'أدخل بيانات الشركة الأساسية لبدء استخدام النظام.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: companyController,
                  enabled: !busy,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'اسم الشركة',
                    hintText: 'مثال: شركة النور للتجارة',
                    prefixIcon: Icon(Icons.storefront_outlined, size: 19),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'اسم الشركة مطلوب.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<String>(
                  initialValue: baseCode.isEmpty ? null : baseCode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'العملة الأساسية',
                    prefixIcon: Icon(Icons.payments_outlined, size: 19),
                  ),
                  items: currencies
                      .map(
                        (currency) => DropdownMenuItem(
                          value: currency.code,
                          child: Text(
                            '${currency.code} — ${currency.displayName}',
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: busy
                      ? null
                      : (value) {
                          if (value != null) {
                            onBaseChanged(value);
                          }
                        },
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'اختر العملة الأساسية.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<String>(
                  initialValue: secondaryCode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'عملة ثانوية (اختياري)',
                    prefixIcon: Icon(
                      Icons.currency_exchange_outlined,
                      size: 19,
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('بدون عملة ثانوية'),
                    ),
                    ...currencies
                        .where((currency) => currency.code != baseCode)
                        .map(
                          (currency) => DropdownMenuItem(
                            value: currency.code,
                            child: Text(
                              '${currency.code} — ${currency.displayName}',
                            ),
                          ),
                        ),
                  ],
                  onChanged: busy
                      ? null
                      : (value) => onSecondaryChanged(value ?? ''),
                ),
                const SizedBox(height: AppSpacing.lg),
                DropdownButtonFormField<int>(
                  initialValue: startMonth,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'شهر بداية السنة المالية',
                    prefixIcon: Icon(Icons.calendar_month_outlined, size: 19),
                  ),
                  items: List.generate(12, (index) {
                    final month = index + 1;
                    return DropdownMenuItem(
                      value: month,
                      child: Text('$month — ${_arabicMonths[index]}'),
                    );
                  }),
                  onChanged: busy
                      ? null
                      : (value) {
                          if (value != null) {
                            onMonthChanged(value);
                          }
                        },
                ),
                if (error != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  AppInfoBanner(
                    title: 'تعذّر إكمال الإعداد',
                    message: describeError(error!),
                    icon: Icons.error_outline,
                    tone: AppBadgeTone.danger,
                  ),
                ],
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  onPressed: busy ? null : onSubmit,
                  icon: busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.rocket_launch_outlined, size: 18),
                  label: Text(busy ? 'جارٍ إعداد الشركة…' : 'بدء الاستخدام'),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'ملاحظة: العملة الأساسية وشهر بداية السنة المالية يُحفظان الآن، '
                  'ويمكن تعديل بيانات الشركة لاحقاً من الإعدادات.',
                  style: theme.textTheme.labelSmall,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
