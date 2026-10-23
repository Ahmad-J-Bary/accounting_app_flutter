import 'package:flutter/material.dart';

import 'app_shell.dart';
import 'ledger.dart';
import 'setup.dart';
import 'theme/app_theme.dart';
import 'ui/app_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsService = SettingsService(InMemorySettingsRepository());
  await settingsService.load();

  runApp(
    ChangeNotifierProvider<SettingsService>.value(
      value: settingsService,
      child: AccountingApp(gateway: RustLedgerGateway()),
    ),
  );
}

class AccountingApp extends StatefulWidget {
  const AccountingApp({
    super.key,
    required this.gateway,
    this.initialThemeMode = ThemeMode.light,
  });

  final LedgerGateway gateway;
  final ThemeMode initialThemeMode;

  @override
  State<AccountingApp> createState() => _AccountingAppState();
}

class _AccountingAppState extends State<AccountingApp> {
  late final AppThemeController _themeController = AppThemeController(
    initialMode: widget.initialThemeMode,
  );

  @override
  void dispose() {
    _themeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppThemeScope(
      controller: _themeController,
      child: AnimatedBuilder(
        animation: _themeController,
        builder: (context, _) {
          return MaterialApp(
            title: 'المحاسبة',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: _themeController.mode,
            builder: (context, child) => Directionality(
              textDirection: TextDirection.rtl,
              child: child ?? const SizedBox.shrink(),
            ),
            home: LedgerHomePage(gateway: widget.gateway),
          );
        },
      ),
    );
  }
}

/// Boots the Rust core, shows the first-run setup when needed and then hands
/// control to the persistent workspace shell.
class LedgerHomePage extends StatefulWidget {
  const LedgerHomePage({super.key, required this.gateway});

  final LedgerGateway gateway;

  @override
  State<LedgerHomePage> createState() => _LedgerHomePageState();
}

class _LedgerHomePageState extends State<LedgerHomePage> {
  LedgerStatus? _status;
  List<CurrencyOption> _currencies = const [];
  Object? _error;
  bool _bootstrapping = true;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    setState(() {
      _bootstrapping = true;
      _error = null;
    });

    try {
      final status = await widget.gateway.loadStatus();
      if (!mounted) {
        return;
      }

      if (!status.setupComplete) {
        final currencies = await widget.gateway.availableCurrencies();
        if (!mounted) {
          return;
        }
        setState(() {
          _status = status;
          _currencies = currencies;
          _bootstrapping = false;
        });
        return;
      }

      setState(() {
        _status = status;
        _bootstrapping = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = error;
        _bootstrapping = false;
      });
    }
  }

  Future<void> _completeSetup() async {
    final status = await widget.gateway.loadStatus();
    if (!mounted) {
      return;
    }
    setState(() => _status = status);
  }

  @override
  Widget build(BuildContext context) {
    if (_bootstrapping) {
      return const _BootstrapScaffold();
    }

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: AppErrorState(
                title: 'تعذّر فتح قاعدة البيانات',
                message: describeError(_error!),
                onRetry: _bootstrap,
              ),
            ),
          ),
        ),
      );
    }

    final status = _status;
    if (status != null && !status.setupComplete) {
      return CompanySetupPage(
        gateway: widget.gateway,
        initialStatus: status,
        currencies: _currencies,
        onCompleted: _completeSetup,
      );
    }

    return WorkspaceShell(gateway: widget.gateway);
  }
}

class _BootstrapScaffold extends StatelessWidget {
  const _BootstrapScaffold();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                  colors: [Color(0xFF3B6EA5), Color(0xFF1F3A61)],
                ),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1F3A61).withValues(alpha: 0.22),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.account_balance_wallet_outlined,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('المحاسبة', style: theme.textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.5),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'جارٍ تهيئة قاعدة البيانات…',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
