param(
    [Parameter(Mandatory=$true)]
    [string]$WorkDir
)

$VENV_DIR = Join-Path $WorkDir ".venv"

if (Test-Path $VENV_DIR) {
    Write-Host "[teardown_venv] Removing venv: $VENV_DIR"
    Remove-Item -Recurse -Force $VENV_DIR
    Write-Host "[teardown_venv] Done."
} else {
    Write-Host "[teardown_venv] No venv found at: $VENV_DIR"
}
