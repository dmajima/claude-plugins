param(
    [Parameter(Mandatory = $true)][string]$WorkDir
)

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$ErrorActionPreference = 'Stop'

$VenvPath = Join-Path $WorkDir ".venv"

if (Test-Path $VenvPath) {
    Write-Output "[OK] Removing venv at $VenvPath"
    Remove-Item -Recurse -Force $VenvPath
}

Write-Output "[DONE] venv removed"
