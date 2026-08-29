[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PackagePath,
    [Parameter(Mandatory = $true)]
    [string]$IdentityName,
    [Parameter(Mandatory = $true)]
    [string]$Publisher,
    [Parameter(Mandatory = $true)]
    [string]$PublisherDisplayName,
    [string]$ExpectedVersion = "",
    [string]$MakeAppx = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))

function Resolve-RepositoryPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return Join-Path $repositoryRoot $Path
}

function Fail([string]$Message) {
    throw "Windows Store package validation failed: $Message"
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
        Fail "$Name was not found"
    }
    return $candidate
}

$package = (Resolve-Path -LiteralPath (Resolve-RepositoryPath $PackagePath)).Path
if ([System.IO.Path]::GetExtension($package) -ne ".msix") {
    Fail "the package must use the .msix extension"
}
$makeAppxPath = Resolve-WindowsSdkTool "makeappx.exe" $MakeAppx
$unpacked = Join-Path ([System.IO.Path]::GetTempPath()) "visualmd-msix-audit-$([guid]::NewGuid())"

try {
    & $makeAppxPath unpack /p $package /d $unpacked /o
    if ($LASTEXITCODE -ne 0) {
        Fail "MakeAppx could not unpack the package"
    }

    [xml]$manifest = Get-Content -LiteralPath (Join-Path $unpacked "AppxManifest.xml") -Raw
    $namespace = New-Object System.Xml.XmlNamespaceManager($manifest.NameTable)
    $namespace.AddNamespace("f", "http://schemas.microsoft.com/appx/manifest/foundation/windows10")
    $namespace.AddNamespace("uap", "http://schemas.microsoft.com/appx/manifest/uap/windows10")
    $namespace.AddNamespace("uap10", "http://schemas.microsoft.com/appx/manifest/uap/windows10/10")
    $namespace.AddNamespace("rescap", "http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities")

    $identity = $manifest.SelectSingleNode("/f:Package/f:Identity", $namespace)
    if ($identity.Name -ne $IdentityName) { Fail "identity name '$($identity.Name)' does not match Partner Center" }
    if ($identity.Publisher -ne $Publisher) { Fail "publisher '$($identity.Publisher)' does not match Partner Center" }
    if ($identity.ProcessorArchitecture -ne "x64") { Fail "architecture is '$($identity.ProcessorArchitecture)'" }
    if ($ExpectedVersion -and $identity.Version -ne "$ExpectedVersion.0") {
        Fail "package version '$($identity.Version)' does not match $ExpectedVersion.0"
    }

    $publisherNode = $manifest.SelectSingleNode("/f:Package/f:Properties/f:PublisherDisplayName", $namespace)
    if ($publisherNode.InnerText -ne $PublisherDisplayName) { Fail "publisher display name does not match Partner Center" }

    $family = $manifest.SelectSingleNode("/f:Package/f:Dependencies/f:TargetDeviceFamily", $namespace)
    if ($family.Name -ne "Windows.Desktop" -or $family.MinVersion -ne "10.0.19041.0") {
        Fail "the package must target Windows.Desktop 10.0.19041.0 or later"
    }
    $application = $manifest.SelectSingleNode("/f:Package/f:Applications/f:Application", $namespace)
    if ($application.Executable -ne "visualmd.exe" -or $application.Id -ne "VisualMD") {
        Fail "the application entry point is not Visual MD"
    }
    if ($application.GetAttribute("RuntimeBehavior", "http://schemas.microsoft.com/appx/manifest/uap/windows10/10") -ne "packagedClassicApp") {
        Fail "the application is not declared as a packaged classic app"
    }
    if ($application.GetAttribute("TrustLevel", "http://schemas.microsoft.com/appx/manifest/uap/windows10/10") -ne "mediumIL") {
        Fail "the application trust level is not mediumIL"
    }
    $capabilities = @($manifest.SelectNodes("/f:Package/f:Capabilities/*", $namespace))
    if ($capabilities.Count -ne 1 -or $capabilities[0].NamespaceURI -ne "http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities" -or $capabilities[0].Name -ne "runFullTrust") {
        Fail "runFullTrust must be the package's only declared capability"
    }

    $required = @(
        "visualmd.exe",
        "flutter_windows.dll",
        "data\app.so",
        "data\icudtl.dat",
        "data\flutter_assets\AssetManifest.bin",
        "data\flutter_assets\FontManifest.json",
        "data\flutter_assets\NOTICES.Z",
        "Assets\StoreLogo.png",
        "Assets\Square44x44Logo.png",
        "Assets\Square150x150Logo.png",
        "Assets\Square44x44Logo.targetsize-16.png",
        "Assets\Square44x44Logo.targetsize-256.png",
        "Assets\Square150x150Logo.scale-400.png"
    )
    foreach ($relativePath in $required) {
        if (-not (Test-Path -LiteralPath (Join-Path $unpacked $relativePath) -PathType Leaf)) {
            Fail "missing $relativePath"
        }
    }
    $debugFiles = @(Get-ChildItem -LiteralPath $unpacked -Recurse -File | Where-Object { $_.Extension -in @(".pdb", ".ilk") })
    if ($debugFiles.Count -ne 0) {
        Fail "debug files are present: $($debugFiles.Name -join ', ')"
    }
} finally {
    if (Test-Path -LiteralPath $unpacked) {
        Remove-Item -LiteralPath $unpacked -Recurse -Force
    }
}

$item = Get-Item -LiteralPath $package
$hash = (Get-FileHash -LiteralPath $package -Algorithm SHA256).Hash.ToLowerInvariant()
Write-Host "Windows Store package validated: $package"
Write-Host "Bytes: $($item.Length)"
Write-Host "SHA-256: $hash"
