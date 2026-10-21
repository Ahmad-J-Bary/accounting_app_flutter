; Inno Setup script for the Accounting App Windows installer.
; AppVersion and SourceDir are supplied by the build workflow:
;   ISCC.exe /DAppVersion=1.0.2 /DSourceDir=<release> /DOutputDir=<dist> accounting_app.iss
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\..\app\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\..\dist"
#endif

[Setup]
AppId={{6F2B3C1A-7D4E-4A9B-9C21-5E8D3A4F7B10}
AppName=Accounting App
AppVersion={#AppVersion}
AppVerName=Accounting App {#AppVersion}
AppPublisher=Accounting App
DefaultDirName={localappdata}\Programs\AccountingApp
DefaultGroupName=Accounting App
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir={#OutputDir}
OutputBaseFilename=accounting-app-{#AppVersion}-windows-x64-setup
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
UninstallDisplayIcon={app}\accounting_app_flutter.exe
CloseApplications=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Accounting App"; Filename: "{app}\accounting_app_flutter.exe"
Name: "{group}\{cm:UninstallProgram,Accounting App}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\Accounting App"; Filename: "{app}\accounting_app_flutter.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\accounting_app_flutter.exe"; Description: "{cm:LaunchProgram,Accounting App}"; Flags: nowait postinstall skipifsilent
