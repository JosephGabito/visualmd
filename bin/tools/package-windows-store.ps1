[CmdletBinding()]
param(
    [string]$BundlePath = "build\windows\x64\runner\Release",
    [string]$OutputDirectory = "dist\windows-store",
    [Parameter(Mandatory = $true)]
    [string]$IdentityName,
    [Parameter(Mandatory = $true)]
    [string]$Publisher,
    [Parameter(Mandatory = $true)]
    [string]$PublisherDisplayName,
    [string]$MakeAppx = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))

function Resolve-RepositoryPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return Join-Path $repositoryRoot $Path
}

function Resolve-WindowsSdkTool([string]$Name, [string]$ExplicitPath) {
    if ($ExplicitPath) {
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }

    $roots = @(
        "${env:ProgramFiles(x86)}\Windows Kits\10\bin",
        "$env:ProgramFiles\Windows Kits\10\bin"
    ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) }

    $candidate = $roots |
        ForEach-Object { Get-ChildItem -LiteralPath $_ -Directory } |
        Where-Object { $_.Name -match '^\d+\.\d+\.\d+\.\d+$' } |
        Sort-Object { [version]$_.Name } -Descending |
        ForEach-Object { Join-Path $_.FullName "x64\$Name" } |
        Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } |
        Select-Object -First 1

    if (-not $candidate) {
        throw "$Name was not found. Install the Windows 10/11 SDK or pass its path explicitly."
    }
    return $candidate
}

if ($IdentityName -notmatch '^[A-Za-z0-9.-]{3,50}$') {
    throw "IdentityName must be the exact 3-50 character Package/Identity/Name value from Partner Center."
}
if ([string]::IsNullOrWhiteSpace($Publisher)) {
    throw "Publisher must be the exact Package/Identity/Publisher value from Partner Center."
}
if ([string]::IsNullOrWhiteSpace($PublisherDisplayName)) {
    throw "PublisherDisplayName must be the exact Partner Center display value."
}

$bundle = (Resolve-Path -LiteralPath (Resolve-RepositoryPath $BundlePath)).Path
$manifestTemplate = (Resolve-Path -LiteralPath (Join-Path $repositoryRoot "windows\store\AppxManifest.xml")).Path
$assetDirectory = (Resolve-Path -LiteralPath (Join-Path $repositoryRoot "windows\store\Assets")).Path
$makeAppxPath = Resolve-WindowsSdkTool "makeappx.exe" $MakeAppx

$pubspec = Get-Content -LiteralPath (Join-Path $repositoryRoot "pubspec.yaml") -Raw
if ($pubspec -notmatch '(?m)^version:\s*([0-9]+)\.([0-9]+)\.([0-9]+)\+([0-9]+)\s*$') {
    throw "pubspec.yaml must declare version as <major>.<minor>.<patch>+<build>."
}
$segments = @([int]$Matches[1], [int]$Matches[2], [int]$Matches[3])
if ($segments[0] -eq 0 -or @($segments | Where-Object { $_ -gt 65535 }).Count -ne 0) {
    throw "The Store package version segments must be 0-65535 and major must be non-zero."
}
$appVersion = "$($segments[0]).$($segments[1]).$($segments[2])"
$packageVersion = "$appVersion.0"

$output = [System.IO.Path]::GetFullPath((Resolve-RepositoryPath $OutputDirectory))
New-Item -ItemType Directory -Force -Path $output | Out-Null
$packagePath = Join-Path $output "VisualMD-$appVersion-windows-x64.msix"
$staging = Join-Path ([System.IO.Path]::GetTempPath()) "visualmd-msix-$([guid]::NewGuid())"

try {
    New-Item -ItemType Directory -Force -Path $staging | Out-Null
    Copy-Item -Path (Join-Path $bundle '*') -Destination $staging -Recurse -Force
    Copy-Item -LiteralPath $assetDirectory -Destination (Join-Path $staging "Assets") -Recurse -Force

    [xml]$manifest = Get-Content -LiteralPath $manifestTemplate -Raw
    $namespace = New-Object System.Xml.XmlNamespaceManager($manifest.NameTable)
    $namespace.AddNamespace("f", "http://schemas.microsoft.com/appx/manifest/foundation/windows10")
    $identity = $manifest.SelectSingleNode("/f:Package/f:Identity", $namespace)
    $identity.SetAttribute("Name", $IdentityName)
    $identity.SetAttribute("Publisher", $Publisher)
    $identity.SetAttribute("Version", $packageVersion)
    $publisherNode = $manifest.SelectSingleNode("/f:Package/f:Properties/f:PublisherDisplayName", $namespace)
    $publisherNode.InnerText = $PublisherDisplayName

    $manifestPath = Join-Path $staging "AppxManifest.xml"
    $settings = New-Object System.Xml.XmlWriterSettings
    $settings.Encoding = New-Object System.Text.UTF8Encoding($false)
    $settings.Indent = $true
    $writer = [System.Xml.XmlWriter]::Create($manifestPath, $settings)
    try {
        $manifest.Save($writer)
    } finally {
        $writer.Dispose()
    }

    # Keep MakeAppx diagnostics visible without mixing them into this script's
    # success pipeline. CI captures the one final pipeline value as the package
    # path for the validation step.
    & $makeAppxPath pack /d $staging /p $packagePath /o /h SHA256 | Out-Host
    if ($LASTEXITCODE -ne 0) {
        throw "MakeAppx failed with exit code $LASTEXITCODE."
    }
    if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) {
        throw "Expected Store package was not created: $packagePath"
    }
} finally {
    if (Test-Path -LiteralPath $staging) {
        Remove-Item -LiteralPath $staging -Recurse -Force
    }
}

Write-Output $packagePath
