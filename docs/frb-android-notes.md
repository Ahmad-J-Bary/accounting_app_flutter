# FRB on Android — build notes

Flutter 3.41 + Flutter Rust Bridge 2.13 needed four fixes beyond the stock
template. They are easy to lose when the FRB plugin is regenerated or upgraded.

## 1. Cargokit must recognise the Flutter Gradle plugin

Flutter 3.41 moved the Gradle plugin class to `com.flutter.gradle.FlutterPlugin`.
`packages/accounting_app_flutter_isolates/cargokit/gradle/plugin.gradle` is kept in
sync with upstream Cargokit (`irondash/cargokit`):

- plugin detection uses `com.flutter.gradle.FlutterPlugin`;
- target platforms come from
  `com.flutter.gradle.FlutterPluginUtils.getTargetPlatforms(project)`.

Without these two lines Cargokit prints:

```
Flutter plugin not found, CargoKit plugin will not be applied.
```

and the APK is produced **without** the Rust `.so` files. The Flutter app would
then fail at runtime when it calls the bridge, while the build looks successful.

## 2. The plugin Android config must match Flutter 3.41

`packages/accounting_app_flutter_isolates/android/build.gradle`:

- Android Gradle Plugin `8.11.1` (same as `app/android/settings.gradle.kts`);
- `compileSdkVersion 36` (Flutter 3.41 default);
- `minSdkVersion 24` (Flutter 3.41 default);
- Java 17.

Android SDK platform 33 is no longer required.

## 3. CMake and NDK provisioning

Flutter's Gradle plugin (`FlutterPluginUtils.forceNdkDownload`) configures an
empty CMake project so that AGP provisions the NDK. AGP 8.11.1 then requires
CMake `3.22.1` and NDK `28.2.13676358`. CI installs both explicitly:

```text
sdkmanager "ndk;28.2.13676358" "cmake;3.22.1"
```

Without CMake 3.22.1 the build fails at
`:app:configureCMakeRelease[...]` with `[CXX1300]`. Remove any malformed
`ndk/<version>` directory that has no `source.properties`; AGP scans those and
prints `[CXX1101]`.

## 4. Rust Android targets

Cargokit builds with `rustup run stable`. CI installs `stable` and the three
release targets explicitly:

```text
aarch64-linux-android
armv7-linux-androideabi
x86_64-linux-android
```

Local Windows note: Cargokit's `Rustup._installedTargets` uses the first toolchain
whose name starts with `stable-`. If both `stable-x86_64-pc-windows-gnu` and
`stable-x86_64-pc-windows-msvc` are installed, it may check the wrong one. Install
the targets for the toolchain printed by:

```powershell
rustup which --toolchain stable rustc
```

## Verification

A correct build must contain the Rust library:

- Windows: `app\build\windows\x64\runner\Release\accounting_app_flutter_isolates.dll`
- Android: `lib/<abi>/libaccounting_app_flutter_isolates.so` inside the matching
  split APK (`app-arm64-v8a-release.apk`, `app-armeabi-v7a-release.apk`, and
  `app-x86_64-release.apk` when produced). Each APK carries only its own ABI.

`.github/workflows/build-android.yml` fails the build if the ABI-specific Rust
library is missing, and `.github/workflows/build-windows.yml` does the same for
the DLL before packaging the ZIP. `quality.yml` calls both reusable workflows.
