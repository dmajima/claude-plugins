# teardown_venv.ps1 - convert-doc プラグイン共通 venv 削除スクリプト (PowerShell 7+ 版、ADR-024 準拠)
#
# 使い方:
#   pwsh -NoProfile -File "${env:CLAUDE_PLUGIN_ROOT}/references/scripts/setup/teardown_venv.ps1" -WorkDir <WORK_DIR>

param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$WorkDir
)

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrEmpty($WorkDir)) {
    [Console]::Error.WriteLine("エラー: WorkDir を第1引数に指定してください。例: -WorkDir .claude/.local/work/(session)/workspace")
    exit 1
}

$venvDir = Join-Path $WorkDir '.venv'

if (Test-Path -LiteralPath $venvDir -PathType Container) {
    Remove-Item -Recurse -Force -LiteralPath $venvDir
    Write-Host "削除しました: $venvDir"
} else {
    Write-Host "スキップ (存在しない): $venvDir"
}
