[CmdletBinding()]
param(
    [string]$BundlePath = "build\windows\x64\runner\Release",
    [string]$OutputDirectory = "dist\windows",
    [string]$InnoCompiler = "",
    [string]$ExpectedInnoVersion = "6.7.3",
    [switch]$Sign
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
Set-Location -LiteralPath $projectRoot

$versionLine = Get-Content -LiteralPath "pubspec.yaml" |
    Where-Object { $_ -match '^version:\s*' } |
    Select-Object -First 1
if (-not $versionLine -or $versionLine -notmatch '^version:\s*([^+\s]+)\+(\d+)\s*$') {
    throw "pubspec.yaml must declare version as <name>+<build>"
}
$appVersion = $Matches[1]

$bundle = (Resolve-Path -LiteralPath $BundlePath).Path
$output = [IO.Path]::GetFullPath((Join-Path $projectRoot $OutputDirectory))
New-Item -ItemType Directory -Path $output -Force | Out-Null

if (-not $InnoCompiler) {
    $candidates = @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "$env:ProgramFiles\Inno Setup 6\ISCC.exe",
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe"
    )
    $InnoCompiler = $candidates |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1
}
if (-not $InnoCompiler -or -not (Test-Path -LiteralPath $InnoCompiler -PathType Leaf)) {
    throw "ISCC.exe was not found. Install Inno Setup 6 or pass -InnoCompiler."
}

$compilerDirectory = Split-Path -Parent $InnoCompiler
$uninstallRoots = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
)
$innoEntries = @(
    foreach ($root in $uninstallRoots) {
        Get-ItemProperty -Path $root -ErrorAction SilentlyContinue |
            Where-Object {
                $null -ne $_.PSObject.Properties["DisplayName"] -and
                $_.DisplayName -like "Inno Setup*"
            }
    }
)
$matchingEntry = $innoEntries | Where-Object {
    $null -ne $_.PSObject.Properties["DisplayVersion"] -and
    $null -ne $_.PSObject.Properties["InstallLocation"] -and
    $_.DisplayVersion -eq $ExpectedInnoVersion -and
    -not [string]::IsNullOrWhiteSpace($_.InstallLocation) -and
    $_.InstallLocation.TrimEnd("\") -eq $compilerDirectory.TrimEnd("\")
} | Select-Object -First 1
if ($null -eq $matchingEntry) {
    $foundVersions = ($innoEntries.DisplayVersion | Sort-Object -Unique) -join ", "
    throw "Expected registered Inno Setup $ExpectedInnoVersion at $compilerDirectory; found versions: $foundVersions"
}

$arguments = @(
    "/DAppVersion=$appVersion",
    "/DSourceDir=$bundle",
    "/DOutputDir=$output"
)
if ($Sign) {
    $signScript = (Resolve-Path -LiteralPath "bin\tools\sign-windows-file.ps1").Path
    $powerShellExecutable = (Get-Process -Id $PID).Path
    $signCommand = '$q' + $powerShellExecutable +
        '$q -NoLogo -NoProfile -ExecutionPolicy Bypass -File $q' +
        $signScript + '$q -FilePath $f'
    $arguments += "/DSignedBuild"
    $arguments += "/Svisualmd=$signCommand"
}
$arguments += "windows\installer\visualmd.iss"

& $InnoCompiler $arguments |
    ForEach-Object { Write-Host $_ }
if ($LASTEXITCODE -ne 0) {
    throw "Inno Setup failed with exit code $LASTEXITCODE"
}

$installer = Join-Path $output "VisualMD-$appVersion-windows-x64-setup.exe"
if (-not (Test-Path -LiteralPath $installer -PathType Leaf)) {
    throw "Expected installer was not created: $installer"
}

Write-Output $installer
