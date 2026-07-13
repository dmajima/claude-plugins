#!/usr/bin/env bash
# run_via_job.sh — PowerShell ツール経由で Python を起動する際の Start-Job ラッパー（connector 共通）
#
# 背景: Windows + Claude Code の PowerShell ツール + 特定ライブラリの組み合わせで
#   Python 子プロセスがハングする既知事象への対策（グローバルルール
#   python-subprocess-hang-windows.md。convert-doc プラグインの run_via_job.ps1 と同趣旨）。
#   通常運用（Bash ツール経由）ではハング事象は再現しないため、pwsh 不在環境では
#   直接実行にフォールバックする。
#
# 使い方:
#   bash run_via_job.sh [-t <timeout_sec>] <python-exe> <script.py> [args...]
# 例:
#   bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/run_via_job.sh" \
#     "$WORK_DIR/.venv/Scripts/python.exe" \
#     "${CLAUDE_SKILL_DIR}/references/scripts/resolve/urlkey.py" "<urlKey>"
set -euo pipefail

usage() { echo "usage: run_via_job.sh [-t <timeout_sec>] <python-exe> <script.py> [args...]" >&2; exit 2; }

TIMEOUT_SEC=600
if [ "${1:-}" = "-t" ]; then
  TIMEOUT_SEC="${2:?timeout value required}"
  shift 2
fi
[ $# -ge 2 ] || usage
RVJ_PY="$1"; shift
RVJ_SCRIPT="$1"; shift

# 引数は環境変数（改行区切り）で pwsh へ受け渡すため、改行を含む引数は拒否する
for a in "$@"; do
  case "$a" in (*$'\n'*|*$'\r'*) echo "run_via_job: 引数に改行を含めることはできない" >&2; exit 2;; esac
done

if ! command -v pwsh >/dev/null 2>&1; then
  # Bash 直接経路（通常運用）: PowerShell ツール固有のハング事象は発生しないため直接実行
  exec "$RVJ_PY" -u "$RVJ_SCRIPT" "$@"
fi

RVJ_ARGS=""
if [ $# -gt 0 ]; then RVJ_ARGS="$(printf '%s\n' "$@")"; fi
RVJ_TIMEOUT="$TIMEOUT_SEC"
export RVJ_PY RVJ_SCRIPT RVJ_ARGS RVJ_TIMEOUT

# Start-Job 経由で Python を隔離起動（python-subprocess-hang-windows.md 準拠）
exec pwsh -NoProfile -Command '
  & chcp.com 65001 | Out-Null
  [Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
  $OutputEncoding = [System.Text.Encoding]::UTF8
  $jobArgs = @()
  if ($env:RVJ_ARGS) { $jobArgs = @($env:RVJ_ARGS -split "`n" | Where-Object { $_ -ne "" }) }
  $job = Start-Job -ScriptBlock {
    param($py, $script, $a)
    $env:PYTHONUTF8 = "1"
    $env:PYTHONIOENCODING = "utf-8"
    & $py -u $script @a
    if ($LASTEXITCODE -ne 0) { throw "python exited with code $LASTEXITCODE" }
  } -ArgumentList $env:RVJ_PY, $env:RVJ_SCRIPT, (,$jobArgs)
  $timeout = [int]$env:RVJ_TIMEOUT
  if (-not (Wait-Job $job -Timeout $timeout)) {
    Stop-Job $job -ErrorAction SilentlyContinue
    Remove-Job $job -Force
    Write-Error "run_via_job: timed out after $timeout sec"
    exit 124
  }
  Receive-Job $job
  $state = $job.ChildJobs[0].JobStateInfo.State
  Remove-Job $job -Force
  if ($state -ne "Completed") { exit 1 }
  exit 0
'
