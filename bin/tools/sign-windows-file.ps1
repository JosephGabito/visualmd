[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$FilePath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$requiredEnvironment = @(
    "AZURE_ARTIFACT_SIGNING_ENDPOINT",
    "AZURE_ARTIFACT_SIGNING_ACCOUNT",
    "AZURE_ARTIFACT_SIGNING_PROFILE"
)
foreach ($name in $requiredEnvironment) {
    if ([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name))) {
        throw "$name is required to sign Windows artifacts"
    }
}

$file = (Resolve-Path -LiteralPath $FilePath).Path
Import-Module ArtifactSigning -RequiredVersion 0.1.8 -ErrorAction Stop

$parameters = @{
    Endpoint = $env:AZURE_ARTIFACT_SIGNING_ENDPOINT
    CodeSigningAccountName = $env:AZURE_ARTIFACT_SIGNING_ACCOUNT
    CertificateProfileName = $env:AZURE_ARTIFACT_SIGNING_PROFILE
    Files = $file
    FileDigest = "SHA256"
    TimestampRfc3161 = "http://timestamp.acs.microsoft.com"
    TimestampDigest = "SHA256"
    ExcludeWorkloadIdentityCredential = $true
    ExcludeAzureCliCredential = $false
}

Invoke-ArtifactSigning @parameters

$signature = Get-AuthenticodeSignature -LiteralPath $file
if ($signature.Status -ne "Valid" -or $null -eq $signature.TimeStamperCertificate) {
    throw "Artifact Signing did not produce a valid timestamped signature for $file"
}
