param(
    [Parameter(Mandatory = $true)][string]$WorkDir,
    [string]$RequirementsPath = ""
)

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path $WorkDir)) {
    New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
}

$VenvPath = Join-Path $WorkDir ".venv"

if (-not (Test-Path $VenvPath)) {
    Write-Output "[OK] Creating venv at $VenvPath"
    & python -m venv $VenvPath
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create venv at $VenvPath"
    }
}

$IsWin = ($IsWindows -or ($env:OS -like "Windows*"))
$PythonExe = if ($IsWin) {
    Join-Path $VenvPath "Scripts/python.exe"
} else {
    Join-Path $VenvPath "bin/python"
}

if (-not (Test-Path $PythonExe)) {
    throw "venv python not found at $PythonExe"
}

if (-not $RequirementsPath) {
    $RequirementsPath = Join-Path (Split-Path -Parent $PSCommandPath) "requirements.txt"
}

if (Test-Path $RequirementsPath) {
    Write-Output "[OK] Installing requirements from $RequirementsPath"
    & $PythonExe -m pip install --quiet --upgrade pip
    if ($LASTEXITCODE -ne 0) { throw "pip upgrade failed" }
    & $PythonExe -m pip install --quiet -r $RequirementsPath
    if ($LASTEXITCODE -ne 0) { throw "pip install failed" }
} else {
    Write-Output "[WARN] requirements.txt not found at $RequirementsPath"
}

Write-Output "[DONE] venv ready: $VenvPath"
