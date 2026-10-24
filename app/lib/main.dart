import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'app_shell.dart';
import 'ledger.dart';
import 'settings/settings_model.dart';
import 'settings/settings_page.dart';
import 'settings/settings_service.dart';
import 'settings/settings_store.dart';
import 'settings/settings_store_stub.dart'
    if (dart.library.io) 'settings/settings_store_io.dart';
import 'setup.dart';
import 'theme/app_theme.dart';
import 'theme/density_mapper.dart';
import 'ui/app_ui.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final store = await createSettingsStore();
  final settingsService = SettingsService(store);
  await settingsService.load();

  runApp(AccountingApp(
    gateway: RustLedgerGateway(),
    settingsService: settingsService,
  ));
}

class _OpenSettingsIntent extends Intent {
  const _OpenSettingsIntent();
}

class AccountingApp extends StatefulWidget {
  const AccountingApp({
    super.key,
    required this.gateway,
    this.settingsService,
  });

  final LedgerGateway gateway;
  final SettingsService? settingsService;

  @override
  State<AccountingApp> createState() => _AccountingAppState();
}

class _AccountingAppState extends State<AccountingApp> {
  final GlobalKey<NavigatorState> _navKey = GlobalKey<NavigatorState>();
  late final SettingsService _service =
      widget.settingsService ?? SettingsService(InMemorySettingsStore());

  void _openSettings() {
    _navKey.currentState?.push(
      MaterialPageRoute<void>(builder: (_) => const SettingsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SettingsService>.value(
      value: _service,
      child: AnimatedBuilder(
        animation: _service,
        builder: (context, _) {
          final a = _service.appearance;
          return MaterialApp(
            title: 'المحاسبة',
            debugShowCheckedModeBanner: false,
            navigatorKey: _navKey,
            theme: AppTheme.light().copyWith(
              visualDensity: visualDensityFor(a.density),
            ),
            darkTheme: AppTheme.dark().copyWith(
              visualDensity: visualDensityFor(a.density),
            ),
            themeMode: a.themeMode,
            builder: (context, child) => Shortcuts(
              shortcuts: const {
                SingleActivator(LogicalKeyboardKey.comma, control: true):
                    _OpenSettingsIntent(),
              },
              child: Actions(
                actions: {
                  _OpenSettingsIntent: CallbackAction<_OpenSettingsIntent>(
                    onInvoke: (_) {
                      _openSettings();
                      return null;
                    },
                  ),
                },
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(a.fontScale),
                  ),
                  child: Directionality(
                    textDirection: TextDirection.rtl,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
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
                  colors: [Color(0xFF2563EB), Color(0xFF6366F1)],
                ),
                borderRadius: BorderRadius.circular(AppRadius.xl),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.24),
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