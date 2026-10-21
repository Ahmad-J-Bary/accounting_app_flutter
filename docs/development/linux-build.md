# Linux Build

Linux is a first-class desktop target for local development and CI. It builds
the same Flutter UI and Rust bridge as Windows; only the native toolchain and
packaging differ.

## Prerequisites

Ubuntu/Debian:

```bash
sudo apt-get update
sudo apt-get install -y \
  clang \
  cmake \
  ninja-build \
  pkg-config \
  libgtk-3-dev \
  liblzma-dev \
  libstdc++-12-dev
```

Also install the pinned toolchains:

- Flutter `3.41.9` (FVM or a direct SDK checkout)
- Rust `1.99.1` (from `rust-toolchain.toml`)

`cargokit` builds the Rust `cdylib`/`staticlib` through Cargo, so no separate
`cargo build` step is required before `flutter build linux`.

## Build

```bash
flutter pub get
cd app
flutter build linux --release
```

Output bundle:

```text
app/build/linux/x64/release/bundle/
  accounting_app_flutter
  lib/
    libaccounting_app_flutter_isolates.so
    libapp.so
  data/
    icudtl.dat
    flutter_assets/
```

Run it from the bundle directory so the executable can resolve its relative
libraries:

```bash
cd app/build/linux/x64/release/bundle
./accounting_app_flutter
```

Do not run the unbundled CMake output in `intermediates_do_not_run`; it expects
a different relative layout.

## CI

`.github/workflows/build-linux.yml`:

1. installs the GTK/CMake/Clang dependencies,
2. installs the pinned Rust toolchain and Flutter,
3. runs `flutter pub get`,
4. runs `flutter build linux --release`,
5. verifies the executable, Rust `.so`, `libapp.so`, `icudtl.dat`, asset
   manifest and bundled Cairo font,
6. checks `ldd` for unresolved shared libraries,
7. creates `accounting-app-<version>-linux-x64.tar.gz` plus `.sha256`,
8. uploads the artifact.

The workflow is called by `quality.yml` and `release.yml`. The release job
downloads `linux-x64-<version>`, verifies the checksum, and uploads the tarball
to the draft release.

## What the tarball contains

The archive is rooted at the bundle directory:

```text
./accounting_app_flutter
./lib/libaccounting_app_flutter_isolates.so
./lib/libapp.so
./data/...
```

It preserves the executable bit. Extract and run:

```bash
mkdir accounting-app
tar -xzf accounting-app-1.0.1-linux-x64.tar.gz -C accounting-app
cd accounting-app
./accounting_app_flutter
```

## Data location

`RustLedgerGateway` opens `accounting.db` through
`getApplicationSupportDirectory()`. On Linux this is typically
`$XDG_DATA_HOME/<app>` or `~/.local/share/<app>`. Table preferences live next
to it as `table_preferences.json`.

The tarball is a portable bundle, not a system package. It does not write to
`/usr` and does not need root.

## Known limitations

- There is no `.deb`, Flatpak or AppImage packaging yet; the tarball is the
  supported Linux artifact.
- The Linux build does not run the Windows-only FFI integration test. Widget
  tests and Rust workspace tests run on Linux via the quality gates.
- `jni` is pulled in transitively by the Flutter plugin graph. Its native
  target is optional on Linux when no JDK is present; the app does not use JNI
  on desktop.
- If `ldd` reports a missing GTK library, install `libgtk-3-dev` (build) and the
  corresponding runtime package (`libgtk-3-0`) on the target machine.
