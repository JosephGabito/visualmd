[CmdletBinding()]
param(
    [string]$BundlePath = "build\windows\x64\runner\Release",
    [string]$ExpectedVersion = "",
    [switch]$RequireSignature,
    [string]$ExpectedSignerSubject = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Fail([string]$Message) {
    throw "Windows bundle validation failed: $Message"
}

$bundle = (Resolve-Path -LiteralPath $BundlePath).Path
$required = @(
    "visualmd.exe",
    "flutter_windows.dll",
    "data\app.so",
    "data\icudtl.dat",
    "data\flutter_assets\AssetManifest.bin",
    "data\flutter_assets\FontManifest.json",
    "data\flutter_assets\NOTICES.Z"
)

foreach ($relativePath in $required) {
    if (-not (Test-Path -LiteralPath (Join-Path $bundle $relativePath) -PathType Leaf)) {
        Fail "missing $relativePath"
    }
}

$licencePatterns = @(
    "data\flutter_assets\assets\fonts\LICENSE-*.txt",
    "data\flutter_assets\assets\licenses\*-THIRD_PARTY_NOTICES.md"
)
foreach ($pattern in $licencePatterns) {
    if (@(Get-ChildItem -Path (Join-Path $bundle $pattern) -File).Count -eq 0) {
        Fail "missing shipped licence files matching $pattern"
    }
}

$debugFiles = @(
    Get-ChildItem -LiteralPath $bundle -Recurse -File |
        Where-Object { $_.Extension -in @(".pdb", ".ilk") }
)
if ($debugFiles.Count -ne 0) {
    Fail "debug files are present: $($debugFiles.Name -join ', ')"
}

$executable = Get-Item -LiteralPath (Join-Path $bundle "visualmd.exe")
$version = $executable.VersionInfo
if ($version.ProductName -ne "Visual MD") {
    Fail "ProductName is '$($version.ProductName)'"
}
if ($version.FileDescription -ne "Visual MD") {
    Fail "FileDescription is '$($version.FileDescription)'"
}
if ($ExpectedVersion) {
    $declaredVersion = $version.FileVersion.Split("+")[0]
    if ($declaredVersion -ne $ExpectedVersion) {
        Fail "file version '$($version.FileVersion)' does not match $ExpectedVersion"
    }
}

$portableExecutables = @(
    Get-ChildItem -LiteralPath $bundle -Recurse -File |
        Where-Object { $_.Extension -in @(".exe", ".dll") }
)
if ($RequireSignature) {
    if ([string]::IsNullOrWhiteSpace($ExpectedSignerSubject)) {
        Fail "ExpectedSignerSubject is required when signatures are required"
    }
    foreach ($file in $portableExecutables) {
        $signature = Get-AuthenticodeSignature -LiteralPath $file.FullName
        if ($signature.Status -ne "Valid") {
            Fail "$($file.Name) has signature status $($signature.Status)"
        }
        if ($signature.SignerCertificate.Subject -ne $ExpectedSignerSubject) {
            Fail "$($file.Name) was signed by '$($signature.SignerCertificate.Subject)' instead of '$ExpectedSignerSubject'"
        }
        if ($null -eq $signature.TimeStamperCertificate) {
            Fail "$($file.Name) does not have a trusted timestamp"
        }
    }
}

$files = @(Get-ChildItem -LiteralPath $bundle -Recurse -File)
$bytes = ($files | Measure-Object -Property Length -Sum).Sum
$hash = (Get-FileHash -LiteralPath $executable.FullName -Algorithm SHA256).Hash.ToLowerInvariant()

Write-Host "Windows bundle validated: $bundle"
Write-Host "Files: $($files.Count)"
Write-Host "Bytes: $bytes"
Write-Host "Executable SHA-256: $hash"
if (-not $RequireSignature) {
    Write-Host "Signatures: not required for this development validation"
}
