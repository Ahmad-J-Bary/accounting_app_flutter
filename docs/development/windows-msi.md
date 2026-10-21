# Windows MSI Packaging (WiX 3.14)

The Windows release produces three artifacts:

- portable ZIP (`accounting-app-<version>-windows-x64.zip`),
- per-user Inno Setup installer (`...-setup.exe`),
- per-machine WiX MSI (`...-windows-x64.msi`).

This document focuses on the MSI and the `none` failure that used to break it.

## Root cause of the `none` / LGHT0103 failure

The old workflow passed this to `light.exe`:

```text
-pdbtype none
```

`-pdbtype` is **not a WiX 3 `light.exe` switch** (WiX 3 uses `-pdbout <file>` or
`-spdb` to suppress the `.wixpdb`). It is also not a binder switch. Therefore:

1. `light.exe` did not recognise `-pdbtype` and passed it through as an
   unparsed argument.
2. `none` was left as a bare positional argument.
3. `Light.ParseCommandLinePassTwo` handles every positional argument with
   `AppCommon.GetFiles(arg, "Source")`, so it tried to read a source file named
   `none`.
4. `light.exe` failed with `LGHT0103` ("The file 'none' cannot be found") before
   it ever linked the MSI.

The current workflow does not pass `-pdbtype` at all. It also validates the
harvested `Files.wxs` before linking, so a stray `Source="none"` or a missing
source path fails with a clear message instead of a cryptic WiX error.

Relevant WiX 3 source locations:

- `src/tools/light/light.cs` — `ParseCommandLinePassTwo` calls
  `AppCommon.GetFiles(arg, "Source")` for positional arguments.
- `src/tools/wix/Binder.cs` — supported binder switches include `-pdbout` and
  `-spdb`; there is no `-pdbtype`.

## WiX version policy

`installer/windows/Product.wxs` uses the WiX 3 namespace
(`http://schemas.microsoft.com/wix/2006/wi`). The build therefore requires
**WiX 3.14.x**:

- The workflow installs the pinned Chocolatey package
  `wixtoolset 3.14.1.20250415`.
- It asserts that `candle.exe -?` reports `version 3.14.` and fails otherwise.
- Do not "fix" a WiX 4 warning by adding WiX 4 switches such as `-arch x64os`
  or `-arch x64compatible`. Those switches do not exist in WiX 3.14, and the
  authoring would need a v4 migration first.
- `-arch x64` is correct for WiX 3.14.

## Pipeline

`.github/workflows/build-windows.yml` runs:

1. **Build** — `flutter build windows --release`.
2. **Preflight** — verify the release bundle contains:
   - `accounting_app_flutter.exe`
   - `accounting_app_flutter_isolates.dll` (Rust bridge)
   - `flutter_windows.dll`
   - `data/app.so`, `data/icudtl.dat`
   - `data/flutter_assets/AssetManifest.bin`
   - the bundled Cairo font
3. **Install tools** — pin WiX 3.14, install Inno Setup if missing.
4. **Harvest** — `heat dir <release> -cg AppFiles -gg -scom -sreg -sfrag -srd
   -dr INSTALLFOLDER -var var.SourceDir -out Files.wxs`.
5. **Validate harvest** — parse `Files.wxs`:
   - at least one `<File>` element,
   - no empty `Source`,
   - no literal `Source="none"`,
   - every expanded source path exists in the release bundle.
6. **Compile** — `candle.exe -arch x64 -dAppVersion=<version>
   -dSourceDir=<release> Product.wxs Files.wxs`.
7. **Link** — `light.exe -ext WixUIExtension -cultures:en-us -out <msi>
   Product.wixobj Files.wixobj`. No `-pdbtype`, no stray positional arguments.
8. **Verify** — run an administrative install:
   `msiexec /a <msi> /qn TARGETDIR=<temp>` and check that the extracted payload
   contains the executable, Rust DLL, Flutter DLL, `app.so`, `icudtl.dat` and
   `AssetManifest.bin`. The extracted executable size must match the release.
9. **Package** — ZIP, EXE, MSI plus `.sha256` files.

The administrative install does not install into `Program Files`; it only
extracts the MSI payload, which makes it safe on a CI runner.

## Local reproduction

On a Windows machine with WiX 3.14 and Inno Setup 6:

```powershell
Set-Location app
flutter build windows --release

$release = (Resolve-Path 'build/windows/x64/runner/Release').Path
$wix = "${env:ProgramFiles(x86)}\WiX Toolset v3.14\bin"
$msiBuild = Join-Path (Get-Location) 'build/msi'
New-Item -ItemType Directory -Path $msiBuild -Force | Out-Null

& "$wix\heat.exe" dir $release -cg AppFiles -gg -scom -sreg -sfrag -srd `
  -dr INSTALLFOLDER -var var.SourceDir -out "$msiBuild\Files.wxs"

Push-Location $msiBuild
try {
  & "$wix\candle.exe" -arch x64 -dAppVersion=1.0.2 "-dSourceDir=$release" `
    '..\..\..\installer\windows\Product.wxs' 'Files.wxs'
  & "$wix\light.exe" -ext WixUIExtension -cultures:en-us `
    -out 'accounting-app-1.0.2-windows-x64.msi' 'Product.wixobj' 'Files.wixobj'
} finally {
  Pop-Location
}
```

Then verify:

```powershell
$msi = 'app\build\msi\accounting-app-1.0.2-windows-x64.msi'
$extract = Join-Path $env:TEMP 'accounting-msi-check'
Remove-Item $extract -Recurse -Force -ErrorAction SilentlyContinue
msiexec /a $msi /qn TARGETDIR=$extract /l*v "$env:TEMP\msi-check.log"
Get-ChildItem $extract -Recurse -Filter accounting_app_flutter.exe
```

## Common failures

| Symptom | Cause | Fix |
|---|---|---|
| `LGHT0103: The file 'none' cannot be found` | A stray positional argument (historically from `-pdbtype none`) was treated as a source file | Remove `-pdbtype`; pass only `.wixobj` files and recognised switches |
| `candle.exe : error CNDL...` about the namespace | WiX 4/5 compiler reading WiX 3 authoring | Install/assert WiX 3.14; do not mix versions |
| `The Windows release bundle is missing ...` | `flutter build windows` did not finish or the Rust DLL was not copied | Check the Flutter build log and the Cargokit output |
| `Harvested source does not exist` | `heat` ran against a stale release directory | Rebuild, then re-run heat |
| `msiexec /a` returns non-zero | Corrupt MSI, missing cab, or blocked extraction | Inspect the `/l*v` log printed by the workflow |
| `light.exe` warns about ICE60 | Informational ICE warning for versionless files | Not fatal; do not suppress blindly |

## Install behaviour and data location

- The MSI is a **per-machine** install under `Program Files\Accounting App`
  and prompts for elevation.
- The Inno Setup EXE is **per-user** and installs under
  `%LOCALAPPDATA%\Programs\AccountingApp`.
- The live database is **not** stored in the install directory. The Flutter
  gateway opens `accounting.db` in `getApplicationSupportDirectory()`
  (typically `%APPDATA%\<app>` on Windows). Upgrading or uninstalling the
  application therefore does not silently move or delete the accounting data.
- Table preferences are stored as `table_preferences.json` in the same
  application-support directory.
- The MSI uses a fixed `UpgradeCode` and a `MajorUpgrade`; keep the
  `UpgradeCode` stable across releases.

## Verification status

- The MSI build and `/a` extraction run in GitHub Actions on `windows-latest`.
- They cannot be executed on the Linux development machine used for the UI
  work; the Linux-side verification covers Flutter/Rust tests and the Linux
  bundle only.
- If CI fails, the workflow prints the MSI extraction log tail and the exact
  failing preflight path.
