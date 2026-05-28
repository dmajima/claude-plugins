# tests/parity/lib/pwsh_runner.ps1
# parity test 用の PowerShell ラッパー。
# Console エンコーディングを UTF-8 に強制してから本来のスクリプトを呼び出すことで、
# Bash 側 (UTF-8) との出力比較で文字化けが起きないようにする。
#
# 使い方:
#   pwsh -NoProfile -File pwsh_runner.ps1 <script_path> <args...>
#
# 注意:
#   この runner は parity test 専用。実プラグインの .ps1 スクリプトには
#   既に必須プリフィクス（global rule console-encoding.md 準拠）が
#   組み込まれているため、本 runner と二重に設定しても害はない。

param(
    [Parameter(Mandatory = $true, Position = 0)][string]$Script,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$RemainingArgs
)

# UTF-8 を強制
& chcp.com 65001 | Out-Null
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8
$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"

if (-not (Test-Path -LiteralPath $Script)) {
    [Console]::Error.WriteLine("[pwsh_runner] script not found: $Script")
    exit 127
}

if ($RemainingArgs) {
    & $Script @RemainingArgs
} else {
    & $Script
}
exit $LASTEXITCODE
