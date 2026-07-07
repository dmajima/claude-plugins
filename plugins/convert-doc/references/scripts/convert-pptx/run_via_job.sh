#!/usr/bin/env bash
# convert_pptx.py を Bash 経由で起動するラッパー (Bash 版)
#
# python-pptx を使う convert_pptx.py は、Windows の PowerShell ツール経由の
# 直接起動でハングする既知事象があるため、本ラッパー（Bash 経由・timeout 付き）
# で起動する。convert-from-pptx/run_via_job.sh と同一の運用パターン。
#
# 使い方:
#   bash run_via_job.sh <input.md> <output.pptx> [--python-exe <path>] [extra args...]
#   bash run_via_job.sh -InputPath <input.md> -OutputPath <output.pptx> -PythonExe <path>
#
# 環境変数:
#   CONVERT_PPTX_PYTHON       venv の python.exe のパス
#   CONVERT_PPTX_TIMEOUT_SEC  タイムアウト秒数（既定 600）

set -euo pipefail

input_path=""
output_path=""
python_exe="${CONVERT_PPTX_PYTHON:-}"
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
  echo "Usage: $0 <input.md> <output.pptx> [-PythonExe <path>] [extra args...]" >&2
  exit 2
fi

if [[ -z "$python_exe" || ! -f "$python_exe" ]]; then
  echo "PythonExe not found. Specify -PythonExe or set CONVERT_PPTX_PYTHON env var to venv python.exe path." >&2
  exit 2
fi

# PythonExe は .exe 拡張子であることを検証
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
  if [[ -n "${CONVERT_PPTX_TIMEOUT_SEC:-}" ]]; then
    if [[ "$CONVERT_PPTX_TIMEOUT_SEC" =~ ^[0-9]+$ ]]; then
      timeout_sec="$CONVERT_PPTX_TIMEOUT_SEC"
      if [[ "$timeout_sec" -le 0 ]]; then
        timeout_sec=600
      fi
    else
      echo "Invalid CONVERT_PPTX_TIMEOUT_SEC value, using default 600" >&2
      timeout_sec=600
    fi
  else
    timeout_sec=600
  fi
fi

script_dir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
convert_script="$script_dir/convert_pptx.py"
if [[ ! -f "$convert_script" ]]; then
  echo "convert_pptx.py not found at expected location: $convert_script" >&2
  exit 2
fi

# Python の UTF-8 設定
export PYTHONUTF8=1
export PYTHONIOENCODING=utf-8

# stderr を stdout にマージして実行
set +e
if command -v timeout >/dev/null 2>&1; then
  timeout --foreground "$timeout_sec" \
    "$python_exe" -u "$convert_script" "$input_path" "$output_path" \
    "${extra_args[@]+"${extra_args[@]}"}" 2>&1
  rc=$?
  if [[ $rc -eq 124 ]]; then
    echo "convert_pptx.py timed out after $timeout_sec sec" >&2
    exit 124
  fi
else
  "$python_exe" -u "$convert_script" "$input_path" "$output_path" \
    "${extra_args[@]+"${extra_args[@]}"}" 2>&1
  rc=$?
fi
set -e
exit "$rc"
