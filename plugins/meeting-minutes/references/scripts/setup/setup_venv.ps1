param(
    [Parameter(Mandatory=$true)]
    [string]$WorkDir
)

$ErrorActionPreference = "Stop"
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$VENV_DIR = Join-Path $WorkDir ".venv"

if (Test-Path $VENV_DIR) {
    Write-Host "[setup_venv] venv already exists: $VENV_DIR"
} else {
    Write-Host "[setup_venv] Creating venv: $VENV_DIR"
    & python -m venv $VENV_DIR
}

$PIP = Join-Path $VENV_DIR "Scripts\pip.exe"
$REQ = Join-Path $SCRIPT_DIR "requirements.txt"

Write-Host "[setup_venv] Installing packages from: $REQ"
& $PIP install -r $REQ --quiet

Write-Host "[setup_venv] Done."
