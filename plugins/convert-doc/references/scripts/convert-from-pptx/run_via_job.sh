#!/usr/bin/env bash
# convert_from_pptx.py を Bash 経由で起動するラッパー (Bash 版)
#
# 通常運用は本スクリプトを利用する。
# PowerShell フォールバック: run_via_job.ps1 （Git Bash 不調時等）
#
# Bash ツール経由なら Windows + python-pptx の `Start-Process -NoNewWindow` ハング
# 事象は再現しない（Cygwin の PTY 層が pwsh とは異なる挙動を取るため）。
# したがって PowerShell 版のような Start-Job 二段プロセス構成は不要で、
# python.exe を直接呼び出す。
# 詳細: ~/.claude/rules/tools/python-subprocess-hang-windows.md
#
# 使い方:
#   bash run_via_job.sh <input.pptx> <output.md> [--python-exe <path>] [extra args...]
#   bash run_via_job.sh -InputPath <input.pptx> -OutputPath <output.md> -PythonExe <path>
#
# 環境変数:
#   CONVERT_FROM_PPTX_PYTHON       venv の python.exe のパス
#   CONVERT_FROM_PPTX_TIMEOUT_SEC  タイムアウト秒数（既定 600）

set -euo pipefail

input_path=""
output_path=""
python_exe="${CONVERT_FROM_PPTX_PYTHON:-}"
timeout_sec=0
extra_args=()
seen_double_dash=0

while [[ $# -gt 0 ]]; do
  if [[ "$seen_double_dash" -eq 1 ]]; then
    extra_args+=("$1")
    shift
    continue
  fi
  case "$1" in
    --) seen_double_dash=1; shift ;;
    -InputPath|--input-path)
      input_path="${2:-}"; shift 2 ;;
    -OutputPath|--output-path)
      output_path="${2:-}"; shift 2 ;;
    -PythonExe|--python-exe)
      python_exe="${2:-}"; shift 2 ;;
    -TimeoutSec|--timeout-sec)
      timeout_sec="${2:-0}"; shift 2 ;;
    -*)
      extra_args+=("$1"); shift ;;
    *)
      if [[ -z "$input_path" ]]; then
        input_path="$1"
      elif [[ -z "$output_path" ]]; then
        output_path="$1"
      else
        extra_args+=("$1")
      fi
      shift ;;
  esac
done

if [[ -z "$input_path" || -z "$output_path" ]]; then
  echo "Usage: $0 <input.pptx> <output.md> [-PythonExe <path>] [extra args...]" >&2
  exit 2
fi

if [[ -z "$python_exe" || ! -f "$python_exe" ]]; then
  echo "PythonExe not found. Specify -PythonExe or set CONVERT_FROM_PPTX_PYTHON env var to venv python.exe path." >&2
  exit 2
fi

# SEC-M2: PythonExe は .exe 拡張子であることを検証
case "$(printf '%s' "$python_exe" | tr 'A-Z' 'a-z')" in
  *.exe) ;;
  *)
    echo "PythonExe must be a .exe file: $python_exe" >&2
    exit 2
    ;;
esac

# Timeout 解決
if ! [[ "$timeout_sec" =~ ^-?[0-9]+$ ]]; then
  timeout_sec=0
fi
if [[ "$timeout_sec" -le 0 ]]; then
  if [[ -n "${CONVERT_FROM_PPTX_TIMEOUT_SEC:-}" ]]; then
    if [[ "$CONVERT_FROM_PPTX_TIMEOUT_SEC" =~ ^[0-9]+$ ]]; then
      timeout_sec="$CONVERT_FROM_PPTX_TIMEOUT_SEC"
      if [[ "$timeout_sec" -le 0 ]]; then
        timeout_sec=600
      fi
    else
      echo "Invalid CONVERT_FROM_PPTX_TIMEOUT_SEC value, using default 600" >&2
      timeout_sec=600
    fi
  else
    timeout_sec=600
  fi
fi

script_dir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
convert_script="$script_dir/convert_from_pptx.py"
if [[ ! -f "$convert_script" ]]; then
  echo "convert_from_pptx.py not found at expected location: $convert_script" >&2
  exit 2
fi

# Python の UTF-8 設定（PowerShell 版と等価）
export PYTHONUTF8=1
export PYTHONIOENCODING=utf-8

# stderr を stdout にマージして実行（PowerShell 版の `2>&1` と等価）
set +e
if command -v timeout >/dev/null 2>&1; then
  timeout --foreground "$timeout_sec" \
    "$python_exe" -u "$convert_script" "$input_path" "$output_path" \
    "${extra_args[@]+"${extra_args[@]}"}" 2>&1
  rc=$?
  if [[ $rc -eq 124 ]]; then
    echo "convert_from_pptx.py timed out after $timeout_sec sec" >&2
    exit 124
  fi
else
  "$python_exe" -u "$convert_script" "$input_path" "$output_path" \
    "${extra_args[@]+"${extra_args[@]}"}" 2>&1
  rc=$?
fi
set -e
exit "$rc"
