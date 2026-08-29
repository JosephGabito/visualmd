#ifndef AppVersion
  #error AppVersion must be supplied with /DAppVersion
#endif
#ifndef SourceDir
  #error SourceDir must be supplied with /DSourceDir
#endif
#ifndef OutputDir
  #error OutputDir must be supplied with /DOutputDir
#endif

[Setup]
AppId={{E1875246-B154-4B31-A75A-4D65902E05F5}
AppName=Visual MD
AppVersion={#AppVersion}
AppVerName=Visual MD {#AppVersion}
AppPublisher=Visual MD
AppPublisherURL=https://visualmd.gabi.to/
AppSupportURL=https://visualmd.gabi.to/support/
AppUpdatesURL=https://github.com/JosephGabito/visualmd/releases
DefaultDirName={localappdata}\Programs\Visual MD
DefaultGroupName=Visual MD
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0.17763
OutputDir={#OutputDir}
OutputBaseFilename=VisualMD-{#AppVersion}-windows-x64-setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\visualmd.exe
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes
RestartApplications=no
VersionInfoVersion={#AppVersion}.0
VersionInfoCompany=Visual MD
VersionInfoDescription=Visual MD installer
VersionInfoProductName=Visual MD
VersionInfoProductVersion={#AppVersion}
#ifdef SignedBuild
SignTool=visualmd
SignedUninstaller=yes
SignToolRetryCount=3
SignToolRetryDelay=1000
#endif

[InstallDelete]
Type: filesandordirs; Name: "{app}\data"
Type: files; Name: "{app}\*.dll"
Type: files; Name: "{app}\visualmd.exe"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\Visual MD"; Filename: "{app}\visualmd.exe"
Name: "{autodesktop}\Visual MD"; Filename: "{app}\visualmd.exe"; Tasks: desktopicon

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional shortcuts:"; Flags: unchecked

[Run]
Filename: "{app}\visualmd.exe"; Description: "Launch Visual MD"; Flags: nowait postinstall skipifsilent
