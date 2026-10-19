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
flutter pub get
```

## Quality gates

```powershell
cargo fmt --all -- --check
cargo check --workspace
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace -- --test-threads=1

Set-Location app
fvm flutter analyze
fvm flutter test
fvm flutter build windows
fvm flutter build apk --release
```

GitHub Actions runs the same gates for Rust, Windows and Android in
`.github/workflows/quality.yml`.

## Current status

Phase 0 (foundation) is in progress. The Rust domain, application and
infrastructure layers have been ported from the previous Tauri project and are
covered by the existing test suite. The Flutter application is still the default
counter template, and the FRB bridge currently exposes only `greet`. The next
phase is the Rust-to-Flutter adapter and the first end-to-end accounting slice.
