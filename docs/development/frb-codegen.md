# Flutter Rust Bridge Codegen

The Flutter app talks to Rust through Flutter Rust Bridge (FRB). Generated
files are committed so a normal build does not require codegen, but they must
stay in sync with the Rust API.

## Pinned versions

| Tool | Version | Source |
|---|---|---|
| Flutter Rust Bridge runtime/codegen | `2.13.0` | `packages/accounting_app_flutter_isolates/pubspec.yaml`, `rust/Cargo.toml`, CI |
| Rust | `1.99.1` | `rust-toolchain.toml` |
| Flutter | `3.41.9` | `.fvmrc` |

Do not bump the codegen independently of the runtime dependency. The generated
glue and `flutter_rust_bridge` crate must match.

## Source of truth

- Rust API surface: `packages/accounting_app_flutter_isolates/rust/src/api/`.
- Config: `packages/accounting_app_flutter_isolates/flutter_rust_bridge.yaml`.
- Generated Dart: `packages/accounting_app_flutter_isolates/lib/src/rust/`.
- Generated Rust glue:
  `packages/accounting_app_flutter_isolates/rust/src/frb_generated.rs`.

Never hand-edit generated files. Change the Rust API or the generator config and
regenerate.

## Regenerate

From the repository root, with the pinned toolchain available:

```bash
# One-time install (pin the version).
cargo install flutter_rust_bridge_codegen --version 2.13.0 --locked

cd packages/accounting_app_flutter_isolates
flutter_rust_bridge_codegen generate
cd ../..
cargo fmt --all
```

With FVM:

```bash
fvm flutter pub get
cd packages/accounting_app_flutter_isolates
flutter_rust_bridge_codegen generate
cd ../..
cargo fmt --all
```

`cargo fmt` after generation is expected: the generator and rustfmt can order
imports differently. Treat a formatting-only diff as noise, not as a binding
change.

## CI freshness check

`.github/workflows/quality.yml` has a `codegen` job that:

1. installs `flutter_rust_bridge_codegen 2.13.0` (cached),
2. runs `flutter pub get`,
3. regenerates in `packages/accounting_app_flutter_isolates`,
4. runs `cargo fmt --all`,
5. fails if `git status` reports changes under the generated paths,
6. regenerates a second time and runs `cargo fmt --all` again,
7. fails if the second run changes the generated paths.

Step 5 catches a Rust API change that was committed without regenerating the
bindings. Steps 6–7 prove the generator is reproducible: two consecutive runs
over the same inputs must produce byte-identical output. The same two-run check
was verified locally on 2026-10-21 with codegen `2.13.0`; both runs left the
generated paths unchanged.

## Local troubleshooting

### `Missing manifest in toolchain '1.99.1-...'`

A partially installed Rust toolchain can leave `cargo +1.99.1` usable for
`--version` while `cargo-expand` cannot find its manifest. Reinstall the
toolchain:

```bash
rustup toolchain uninstall 1.99.1
rustup toolchain install 1.99.1 --profile minimal --component rustfmt --component clippy
```

As a temporary workaround for codegen only, a complete adjacent toolchain can
be used, for example:

```bash
RUSTUP_TOOLCHAIN=1.97.1 flutter_rust_bridge_codegen generate
```

Record the workaround in the PR; do not change `rust-toolchain.toml` just to
make a local toolchain work.

### `cargo-expand` is missing

```bash
cargo install cargo-expand --locked
```

Make sure the same toolchain that runs codegen can run `cargo expand`.

### Generated diff is only import order

Run `cargo fmt --all` and re-check. If the only diff is rustfmt import ordering
in `frb_generated.rs`, there is no semantic binding change. Do not commit a
formatting-only regeneration as if it changed the API.

### FVM or PATH conflicts

If an FVM shim points at an inaccessible Windows path, keep it off `PATH` for
codegen and invoke the pinned Flutter/Dart directly. The CI job does not use
FVM; it installs the pinned Flutter version explicitly.

### Generated files are stale but codegen succeeds

Check that you ran codegen in
`packages/accounting_app_flutter_isolates`, not at the repository root. The
config path is resolved from that directory.
