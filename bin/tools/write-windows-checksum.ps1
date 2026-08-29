[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InstallerPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$installer = Get-Item -LiteralPath $InstallerPath
$hash = (Get-FileHash -LiteralPath $installer.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
$checksumPath = "$($installer.FullName).sha256"
$line = "$hash  $($installer.Name)`n"
[IO.File]::WriteAllText($checksumPath, $line, [Text.UTF8Encoding]::new($false))

Write-Output $checksumPath
