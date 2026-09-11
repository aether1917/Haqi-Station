; 哈气站 Windows 安装包（Inno Setup 6，简体中文界面）。
; per-user 安装（%LOCALAPPDATA%\Programs\HaqiStation），无需管理员权限，
; 应用内更新时由应用以 /SILENT 静默覆盖安装并自动重启。
; CI 调用：iscc /DAppVersion=x.y.z setup.iss（版本号由 workflow 传入）。

#define MyAppName "哈气站"
#define MyAppNameEn "HaqiStation"
#define ExeName "haqi_station"
#define SrcDir "..\..\build\windows\x64\runner\Release"

#ifndef AppVersion
  #define AppVersion GetVersionNumbersString(SrcDir + "\" + ExeName + ".exe")
#endif

[Setup]
AppId={{7C3A2B9E-5D4F-4C61-8A2B-9E0D1F4C7B35}
AppVersion={#AppVersion}
AppVerName={#MyAppName} v{#AppVersion}
AppName={#MyAppName}
AppPublisher={#MyAppName}
AppUpdatesURL=https://github.com/aether1917/Haqi-Station/releases/latest
DefaultDirName={autopf}\{#MyAppNameEn}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
OutputDir=..\..\build\installer
OutputBaseFilename=haqi-station-v{#AppVersion}-windows-setup
SetupIconFile=..\runner\resources\app_icon.ico
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesInstallIn64BitMode=x64
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\{#ExeName}.exe
CloseApplications=yes

[Languages]
Name: "chinese"; MessagesFile: "ChineseSimplified.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; \
    GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SrcDir}\*"; DestDir: "{app}"; Flags: ignoreversion \
    recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#ExeName}.exe"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#ExeName}.exe"; \
    Tasks: desktopicon

[Run]
; 手动安装：完成页提供「启动」勾选；应用内静默更新时由第二条在
; 安装完成后自动重启应用。
Filename: "{app}\{#ExeName}.exe"; Description: "{cm:LaunchProgram,{#MyAppName}}"; \
    Flags: nowait postinstall skipifsilent
Filename: "{app}\{#ExeName}.exe"; Flags: nowait; Check: WizardSilent
