# Accounting App (Flutter + Rust)

Arabic-first accounting and business management application for Windows and Android.

## Repository layout

| Path | Purpose |
|---|---|
| `app/` | Flutter application |
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
fvm dart format --output=none --set-exit-if-changed lib test
fvm flutter analyze
fvm flutter test
fvm flutter build windows --release
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
`.github/workflows/build-windows.yml` and `.github/workflows/build-android.yml`
workflows. Each build uploads a checksummed artifact:

- Windows: `accounting-app-<version>-windows-x64.zip` plus a `.sha256` file.
- Android: split `app-<abi>-release.apk` files plus `sha256sums.txt`.

`.github/workflows/release.yml` can be started manually or by pushing a `v*` tag
to build both platforms and create or update a draft GitHub release with those
assets. Dependabot keeps Cargo, pub and GitHub Actions dependencies current;
semver-major updates are ignored for Cargo and pub until they have a dedicated
impact and rollback plan.

## Current status

The Phase 1 vertical slice is complete: Rust owns the accounting rules, the
SQLite migrations and the FRB bridge; Flutter provides company setup, journal
entries, a trial balance, and full master-data management for customers,
suppliers, materials, categories, units and opening balances.

The Flutter app now uses a React-derived design system with the bundled Cairo
font, light/dark themes, a persistent RTL workspace shell, a dashboard, a
dedicated journal page, ERP-style tables, a `Ctrl+K` command palette and
inventory notifications. Remaining work includes i18n switching, RBAC, tabs,
form side panels, financial-year closing UI, and the Axum/PostgreSQL sync layer.

