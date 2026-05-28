#!/usr/bin/env bash
# meeting-minutes プラグイン: generate_docx.py を Bash 経由で起動するラッパー
#
# 通常運用は本スクリプトを利用する。
# PowerShell フォールバック: run_docx_via_job.ps1 （Git Bash 不調時等）
#
# Bash ツール経由なら Windows + python-docx の Start-Process ハング事象は
# 再現しないため、PowerShell 版のような Start-Job 二段構成は不要。
# 詳細: ~/.claude/rules/tools/python-subprocess-hang-windows.md
#
# 使い方:
#   bash run_docx_via_job.sh -PythonExe <py> -ScriptPath <script> -InputJson <json> -OutputDocx <docx> [-TemplatePath <tpl>] [-TimeoutSec <sec>]

set -euo pipefail

python_exe=""
script_path=""
input_json=""
output_docx=""
template_path=""
timeout_sec=120

while [[ $# -gt 0 ]]; do
  case "$1" in
    -PythonExe|--python-exe)       python_exe="${2:-}"; shift 2 ;;
    -ScriptPath|--script-path)     script_path="${2:-}"; shift 2 ;;
    -InputJson|--input-json)       input_json="${2:-}"; shift 2 ;;
    -OutputDocx|--output-docx)     output_docx="${2:-}"; shift 2 ;;
    -TemplatePath|--template-path) template_path="${2:-}"; shift 2 ;;
    -TimeoutSec|--timeout-sec)     timeout_sec="${2:-120}"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ -z "$python_exe" || -z "$script_path" || -z "$input_json" || -z "$output_docx" ]]; then
  echo "Usage: $0 -PythonExe <py> -ScriptPath <script> -InputJson <json> -OutputDocx <docx> [-TemplatePath <tpl>] [-TimeoutSec <sec>]" >&2
  exit 2
fi

if ! [[ "$timeout_sec" =~ ^[0-9]+$ ]] || [[ "$timeout_sec" -le 0 ]]; then
  timeout_sec=120
fi

export PYTHONUTF8=1
export PYTHONIOENCODING=utf-8

cmd_args=(--input "$input_json" --output "$output_docx")
if [[ -n "$template_path" ]]; then
  cmd_args+=(--template "$template_path")
fi

set +e
if command -v timeout >/dev/null 2>&1; then
  timeout --foreground "$timeout_sec" "$python_exe" -u "$script_path" "${cmd_args[@]}"
  rc=$?
  if [[ $rc -eq 124 ]]; then
    echo "[run_docx_via_job] Timed out after ${timeout_sec}s" >&2
    exit 124
  fi
else
  "$python_exe" -u "$script_path" "${cmd_args[@]}"
  rc=$?
fi
set -e

if [[ "$rc" -ne 0 ]]; then
  echo "[run_docx_via_job] Script exited with code $rc" >&2
  exit "$rc"
fi
echo "[run_docx_via_job] Done."
