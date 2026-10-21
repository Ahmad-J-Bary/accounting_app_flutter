# Accounting App (Flutter + Rust)

Arabic-first accounting and business management application for Windows, Linux and Android.

## Repository layout

| Path | Purpose |
|---|---|
| `app/` | Flutter application |
| `app/lib/ui/` | Shared design system, data table and table preferences |
| `app/lib/features/` | Independent customers, suppliers and materials pages |
| `docs/architecture/` | Layer boundaries and architectural decisions |
| `docs/ui/` | Design system, table contract, navigation and shortcuts |
| `docs/development/` | FRB codegen, Windows MSI and Linux build guides |
| `crates/domain/` | Accounting domain model and rules |
| `crates/application/` | Use cases, DTOs and repository ports |
| `crates/infrastructure/` | SQLite repositories and migrations |
| `packages/accounting_app_flutter_isolates/` | Flutter Rust Bridge package |
| `packages/core/` | Shared Rust facade (currently a health-check stub) |
| `server/api/` | Axum API server (currently `/health` only) |
| `cli/` | Diagnostic CLI |

## Pinned toolchain

- Flutter `3.41.9` via FVM (`.fvmrc`)
- Rust `1.99.1` (`rust-toolchain.toml`)
- Flutter Rust Bridge `2.13.0`
- Visual Studio 2022 Build Tools with the Desktop C++ workload (Windows)
- GTK 3, CMake, Ninja, Clang and pkg-config (Linux)
- Android SDK + NDK (Cargokit installs the required NDK automatically)

```powershell
Set-Location 'E:\My Projects\accounting_app_flutter'
fvm install
fvm use
fvm flutter pub get
```

## Quality gates

```powershell
cargo fmt --all -- --check
cargo check --workspace
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace -- --test-threads=1

Set-Location app
fvm dart format --output=none --set-exit-if-changed lib test integration_test
fvm flutter analyze
fvm flutter test test
fvm flutter test integration_test/bridge_test.dart -d windows
fvm flutter build windows --release
fvm flutter build linux --release
fvm flutter build apk --release --split-per-abi

Set-Location 'E:\My Projects\accounting_app_flutter'
Set-Location packages/accounting_app_flutter_isolates
flutter_rust_bridge_codegen generate
Set-Location 'E:\My Projects\accounting_app_flutter'
cargo fmt --all
```

GitHub Actions runs the same Rust and Flutter gates in
`.github/workflows/quality.yml`. That workflow also checks that the generated
FRB bindings are fresh, then calls the reusable
`.github/workflows/build-windows.yml`, `.github/workflows/build-linux.yml` and
`.github/workflows/build-android.yml` workflows. Each build uploads
checksummed artifacts:

- Windows portable: `accounting-app-<version>-windows-x64.zip` plus `.sha256`.
- Windows installers: `accounting-app-<version>-windows-x64-setup.exe` (Inno
  Setup) and `accounting-app-<version>-windows-x64.msi` (WiX), each with a
  `.sha256` file.
- Linux portable: `accounting-app-<version>-linux-x64.tar.gz` plus `.sha256`.
- Android: split `app-<abi>-release.apk` files plus `sha256sums.txt`.

The Inno Setup EXE is a per-user install, so it does not require administrator
privileges. The WiX MSI is a per-machine install and prompts for elevation. Both
install the same Flutter runner, Rust bridge DLL and `data/flutter_assets`
payload as the portable ZIP. The MSI is built with WiX 3.14 and verified in CI
by an administrative extraction (`msiexec /a`) that checks the executable, Rust
DLL and assets; see `docs/development/windows-msi.md` for the former `none` /
`LGHT0103` root cause and the current guardrails.

A real FFI integration test runs on Windows and covers the bridge end to end:

```powershell
Set-Location app
fvm flutter test integration_test/bridge_test.dart -d windows
```

It opens a temporary SQLite database, runs migrations, creates a company, posts
journal entries, exercises master-data CRUD, and creates/posts sales and purchase
invoices, sales and purchase returns, receipts, an expense item and an expense
voucher. Posted vouchers must reject direct deletion, proving the audit trail is
enforced by the Rust core.

`.github/workflows/release.yml` can be started manually or by pushing a `v*` tag
to build all three platforms and create or update a draft GitHub release with
those assets. The `1.x` line is intentionally marked **pre-release** until financial
year closing and partner-capital management are complete. Dependabot keeps
Cargo, pub and GitHub Actions dependencies current; semver-major updates are
ignored for Cargo and pub until they have a dedicated impact and rollback plan.

## Current status

Version `1.0.1` is the current desktop/handheld build and is published as a
GitHub **pre-release** (tag `v1.0.1`) with a portable ZIP, an Inno Setup
installer, a WiX MSI and three split Android APKs. The Phase 1 vertical
slice is complete: Rust owns the accounting rules, the SQLite migrations and the
FRB bridge; Flutter provides company setup, journal entries, a trial balance,
and full master-data management for customers, suppliers, materials, categories,
units and opening balances. The same bridge now exposes sales and purchase
invoices (draft, post, delete), sales and purchase returns, receipts, supplier
payments, expense items and expense vouchers.

The Flutter app uses a React-derived design system with the bundled Cairo font,
light/dark themes, a persistent RTL workspace shell, a dashboard, a dedicated
journal page, ERP-style tables, a `Ctrl+K` command palette and inventory
notifications. Customers, suppliers and materials are independent pages rather
than one combined master-data screen. The shared `AppDataTable` supports stable
column ids, sorting, column visibility/order/width preferences, pagination,
selection, loading/error/empty states and RTL/LTR layout. Section history backs
the top-bar back button, Android system back, `Alt+Left` and `Escape`; forms warn
before discarding unsaved changes.

Remaining work includes i18n switching, RBAC, tabs, financial-year closing,
partner/capital management, form side panels, and the Axum/PostgreSQL sync
layer. Returns currently support creation and posting only; editing or reversing
a posted return needs a dedicated use case before the UI can expose it.

Architecture and development details:

- `docs/architecture/overview.md` — DDD + hexagonal boundaries and invariants.
- `docs/ui/design-system.md` — tokens, components and the table contract.
- `docs/ui/navigation-and-shortcuts.md` — sections, back handling, shortcuts.
- `docs/development/frb-codegen.md` — pinned FRB regeneration and CI check.
- `docs/development/windows-msi.md` — WiX 3.14, the `none` root cause, MSI
  verification.
- `docs/development/linux-build.md` — Linux dependencies, bundle and tarball.

