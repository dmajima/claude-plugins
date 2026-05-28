# tests/parity/lib/pwsh_runner.ps1
# parity test 用の PowerShell ラッパー。
# Console エンコーディングを UTF-8 に強制してから本来のスクリプトを呼び出すことで、
# Bash 側 (UTF-8) との出力比較で文字化けが起きないようにする。
#
# 使い方:
#   pwsh -NoProfile -NonInteractive -File pwsh_runner.ps1 <script_path> <args...>
#
# 設計上の注意:
#   - 本ファイルは `param()` を使わず、全引数を `$args` 自動変数で受け取る。
#     `param([string]$Script, [string[]]$RemainingArgs)` 形式だと、
#     呼び出し対象スクリプト用の `-WorkDir` 等の引数が runner 自身の
#     パラメータと誤解釈されてエラーになるため。
#
# 注意:
#   この runner は parity test 専用。実プラグインの .ps1 スクリプトには
#   既に必須プリフィクス（global rule console-encoding.md 準拠）が
#   組み込まれているため、本 runner と二重に設定しても害はない。

# UTF-8 を強制
& chcp.com 65001 | Out-Null
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8
$env:PYTHONUTF8 = "1"
$env:PYTHONIOENCODING = "utf-8"

# PowerShell 7+ のデフォルトは ConciseView (色付き多行装飾) で、normalize.sh の
# ps_error_decoration ルール (PowerShell 5.1 互換の NormalView 想定) では剥がせない。
# NormalView に切り替え + ANSI カラー出力を無効化することで、parity 比較を成立させる。
$ErrorView = 'NormalView'
$PSStyle.OutputRendering = 'PlainText'

if ($args.Count -lt 1) {
    [Console]::Error.WriteLine("[pwsh_runner] usage: pwsh_runner.ps1 <script> [args...]")
    exit 127
}

$ScriptPath = $args[0]
$ScriptArgs = if ($args.Count -gt 1) { $args[1..($args.Count - 1)] } else { @() }

if (-not (Test-Path -LiteralPath $ScriptPath)) {
    [Console]::Error.WriteLine("[pwsh_runner] script not found: $ScriptPath")
    exit 127
}

if ($ScriptArgs.Count -gt 0) {
    & $ScriptPath @ScriptArgs
} else {
    & $ScriptPath
}
exit $LASTEXITCODE
