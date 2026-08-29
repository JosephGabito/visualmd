[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$PackagePath,
    [Parameter(Mandatory = $true)]
    [string]$IdentityName,
    [Parameter(Mandatory = $true)]
    [string]$Publisher,
    [string]$SignTool = "",
    [switch]$RunCertificationKit,
    [string]$CertificationReport = "dist\windows-store\wack-report.xml"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$repositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot "..\.."))

function Resolve-RepositoryPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return Join-Path $repositoryRoot $Path
}

function Fail([string]$Message) {
    throw "Windows Store package smoke test failed: $Message"
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
    if (-not $candidate) { Fail "$Name was not found" }
    return $candidate
}

$package = (Resolve-Path -LiteralPath (Resolve-RepositoryPath $PackagePath)).Path
$signToolPath = Resolve-WindowsSdkTool "signtool.exe" $SignTool
$currentIdentity = [System.Security.Principal.WindowsIdentity]::GetCurrent()
if ($currentIdentity.IsSystem) {
    Fail "run this smoke test from the signed-in Windows desktop user, not Local System"
}
$existingPackage = Get-AppxPackage -Name $IdentityName -ErrorAction SilentlyContinue
if ($null -ne $existingPackage) {
    Fail "$IdentityName is already installed; remove the test package before retrying"
}

$temporary = Join-Path ([System.IO.Path]::GetTempPath()) "visualmd-msix-test-$([guid]::NewGuid())"
$signedPackage = Join-Path $temporary "VisualMD-test-signed.msix"
$certificatePath = Join-Path $temporary "VisualMD-test.cer"
$certificate = $null
$trustedCertificate = $null
$trustedStoreLocation = $null
$installed = $false
$newProcesses = @()

try {
    New-Item -ItemType Directory -Force -Path $temporary | Out-Null
    Copy-Item -LiteralPath $package -Destination $signedPackage

    $certificate = New-SelfSignedCertificate `
        -Type Custom `
        -Subject $Publisher `
        -KeyUsage DigitalSignature `
        -KeyAlgorithm RSA `
        -KeyLength 2048 `
        -HashAlgorithm SHA256 `
        -CertStoreLocation "Cert:\CurrentUser\My" `
        -NotAfter (Get-Date).AddDays(7) `
        -TextExtension @("2.5.29.37={text}1.3.6.1.5.5.7.3.3")
    Export-Certificate -Cert $certificate -FilePath $certificatePath | Out-Null
    $trustedStoreLocation = [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser
    $trustedCertificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new($certificatePath)
    $rootStore = [System.Security.Cryptography.X509Certificates.X509Store]::new(
        [System.Security.Cryptography.X509Certificates.StoreName]::Root,
        $trustedStoreLocation
    )
    try {
        $rootStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
        $rootStore.Add($trustedCertificate)
    } finally {
        $rootStore.Close()
    }

    & $signToolPath sign /fd SHA256 /sha1 $certificate.Thumbprint $signedPackage
    if ($LASTEXITCODE -ne 0) { Fail "SignTool failed with exit code $LASTEXITCODE" }

    if ($RunCertificationKit) {
        $appCertCandidates = @(
            "$env:ProgramFiles\Windows Kits\10\App Certification Kit\appcert.exe",
            "${env:ProgramFiles(x86)}\Windows Kits\10\App Certification Kit\appcert.exe"
        ) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) }
        $appCert = $appCertCandidates | Select-Object -First 1
        if (-not $appCert) {
            Fail "appcert.exe was not found; install the Windows App Certification Kit"
        }
        $report = [System.IO.Path]::GetFullPath((Resolve-RepositoryPath $CertificationReport))
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $report) | Out-Null
        & $appCert reset
        if ($LASTEXITCODE -ne 0) { Fail "the certification kit reset failed" }
        & $appCert test -appxpackagepath $signedPackage -reportoutputpath $report
        if ($LASTEXITCODE -ne 0) { Fail "the Windows App Certification Kit failed; inspect $report" }
        Write-Host "Windows App Certification Kit report: $report"
    }

    $before = @(Get-Process -Name "visualmd" -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Id)
    Add-AppxPackage -Path $signedPackage
    $installed = $true
    $installedPackage = Get-AppxPackage -Name $IdentityName -ErrorAction Stop
    Start-Process "explorer.exe" "shell:AppsFolder\$($installedPackage.PackageFamilyName)!VisualMD"

    $deadline = (Get-Date).AddSeconds(20)
    do {
        Start-Sleep -Milliseconds 500
        $newProcesses = @(
            Get-Process -Name "visualmd" -ErrorAction SilentlyContinue |
                Where-Object { $_.Id -notin $before }
        )
    } while ($newProcesses.Count -eq 0 -and (Get-Date) -lt $deadline)
    if ($newProcesses.Count -eq 0) { Fail "the packaged application did not launch" }

    Write-Host "Windows Store package lifecycle validated: signed locally, installed, and launched"
} finally {
    foreach ($process in $newProcesses) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }
    if ($installed) {
        Get-AppxPackage -Name $IdentityName -ErrorAction SilentlyContinue |
            Remove-AppxPackage -ErrorAction SilentlyContinue
    }
    if ($null -ne $trustedCertificate) {
        $rootStore = [System.Security.Cryptography.X509Certificates.X509Store]::new(
            [System.Security.Cryptography.X509Certificates.StoreName]::Root,
            $trustedStoreLocation
        )
        try {
            $rootStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
            $rootStore.Remove($trustedCertificate)
        } finally {
            $rootStore.Close()
        }
    }
    if ($null -ne $certificate) {
        Remove-Item -LiteralPath "Cert:\CurrentUser\My\$($certificate.Thumbprint)" -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path -LiteralPath $temporary) {
        Remove-Item -LiteralPath $temporary -Recurse -Force
    }
}
