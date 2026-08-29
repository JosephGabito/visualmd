[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InstallerPath,
    [Parameter(Mandatory = $true)]
    [string]$ExpectedVersion,
    [switch]$RequireSignature,
    [string]$ExpectedSignerSubject = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
    throw "Windows installer smoke test failed: $Message"
}

function Run-And-Wait([string]$Path, [string[]]$Arguments) {
    $process = Start-Process -FilePath $Path -ArgumentList $Arguments -PassThru -Wait
    if ($process.ExitCode -ne 0) {
        Fail "$Path exited with code $($process.ExitCode)"
    }
}

function Assert-Signature([string]$Path) {
    $signature = Get-AuthenticodeSignature -LiteralPath $Path
    if ($signature.Status -ne "Valid") {
        Fail "$(Split-Path -Leaf $Path) has signature status $($signature.Status)"
    }
    if ($signature.SignerCertificate.Subject -ne $ExpectedSignerSubject) {
        Fail "$(Split-Path -Leaf $Path) was signed by '$($signature.SignerCertificate.Subject)' instead of '$ExpectedSignerSubject'"
    }
    if ($null -eq $signature.TimeStamperCertificate) {
        Fail "$(Split-Path -Leaf $Path) does not have a trusted timestamp"
    }
}

if ($RequireSignature -and [string]::IsNullOrWhiteSpace($ExpectedSignerSubject)) {
    Fail "ExpectedSignerSubject is required when signatures are required"
}

$installer = (Resolve-Path -LiteralPath $InstallerPath).Path
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
$installDirectory = Join-Path $env:LOCALAPPDATA "Programs\Visual MD"
$startMenuShortcut = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\Visual MD\Visual MD.lnk"
$uninstallRegistryPaths = @(
    "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\{E1875246-B154-4B31-A75A-4D65902E05F5}_is1",
    "HKCU:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{E1875246-B154-4B31-A75A-4D65902E05F5}_is1"
)
$sentinel = Join-Path ([IO.Path]::GetTempPath()) "visualmd-user-file-$([guid]::NewGuid()).md"
$installArguments = @("/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/SP-")
$uninstallArguments = @("/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART")
$installed = $false

if ((Test-Path -LiteralPath $installDirectory) -or
    ($uninstallRegistryPaths | Where-Object { Test-Path -LiteralPath $_ })) {
    Fail "Visual MD is already installed; use a clean VM, snapshot, or CI runner so this destructive lifecycle test cannot replace a user's installation"
}

Set-Content -LiteralPath $sentinel -Value "This file is outside the application directory."

try {
    if ($RequireSignature) {
        Assert-Signature $installer
    }

    Run-And-Wait $installer $installArguments
    $installed = $true

    $application = Join-Path $installDirectory "visualmd.exe"
    if (-not (Test-Path -LiteralPath $application -PathType Leaf)) {
        Fail "the application executable was not installed"
    }
    if (-not (Test-Path -LiteralPath $startMenuShortcut -PathType Leaf)) {
        Fail "the Start Menu shortcut was not installed"
    }

    & (Join-Path $projectRoot "bin\tools\validate-windows-bundle.ps1") `
        -BundlePath $installDirectory `
        -ExpectedVersion $ExpectedVersion `
        -RequireSignature:$RequireSignature `
        -ExpectedSignerSubject $ExpectedSignerSubject

    $applicationProcess = Start-Process -FilePath $application -PassThru
    Start-Sleep -Seconds 5
    $applicationProcess.Refresh()
    if ($applicationProcess.HasExited) {
        Fail "the installed application exited during its launch smoke test"
    }
    Stop-Process -Id $applicationProcess.Id -Force
    $applicationProcess.WaitForExit()

    $staleLibrary = Join-Path $installDirectory "stale-plugin.dll"
    Set-Content -LiteralPath $staleLibrary -Value "obsolete"
    Run-And-Wait $installer $installArguments
    if (Test-Path -LiteralPath $staleLibrary) {
        Fail "reinstall left an obsolete application DLL behind"
    }

    $uninstaller = Get-ChildItem -LiteralPath $installDirectory -Filter "unins*.exe" -File |
        Select-Object -First 1
    if ($null -eq $uninstaller) {
        Fail "the uninstaller was not installed"
    }
    if ($RequireSignature) {
        Assert-Signature $uninstaller.FullName
    }

    Run-And-Wait $uninstaller.FullName $uninstallArguments
    $installed = $false

    if (Test-Path -LiteralPath $installDirectory) {
        Fail "uninstall left the application directory behind"
    }
    if (Test-Path -LiteralPath $startMenuShortcut) {
        Fail "uninstall left the Start Menu shortcut behind"
    }
    if (-not (Test-Path -LiteralPath $sentinel -PathType Leaf)) {
        Fail "uninstall removed a file outside the application directory"
    }

    Write-Host "Windows installer lifecycle validated: install, launch, reinstall, and uninstall"
} finally {
    if ($installed -and (Test-Path -LiteralPath $installDirectory)) {
        $remainingUninstaller = Get-ChildItem -LiteralPath $installDirectory -Filter "unins*.exe" -File |
            Select-Object -First 1
        if ($null -ne $remainingUninstaller) {
            Start-Process -FilePath $remainingUninstaller.FullName `
                -ArgumentList $uninstallArguments -Wait | Out-Null
        }
    }
    Remove-Item -LiteralPath $sentinel -Force -ErrorAction SilentlyContinue
}
