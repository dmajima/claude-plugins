#!/usr/bin/env bash
# verify_md.py を Bash 経由で起動するラッパー (Bash 版)
#
#
# Bash ツール経由で python.exe を直接呼び出す。設計と挙動は run_via_job.sh と対称。
#
# 使い方:
#   bash run_verify_via_job.sh <input.pptx> <md.md> [--python-exe <path>] [extra args...]
#   bash run_verify_via_job.sh -PptxPath <input.pptx> -MdPath <md.md> -PythonExe <path>
#
# 環境変数:
#   CONVERT_FROM_PPTX_PYTHON       venv の python.exe のパス
#   CONVERT_FROM_PPTX_TIMEOUT_SEC  タイムアウト秒数（既定 600）

set -euo pipefail

pptx_path=""
md_path=""
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
    -PptxPath|--pptx-path)
      pptx_path="${2:-}"; shift 2 ;;
    -MdPath|--md-path)
      md_path="${2:-}"; shift 2 ;;
    -PythonExe|--python-exe)
      python_exe="${2:-}"; shift 2 ;;
    -TimeoutSec|--timeout-sec)
      timeout_sec="${2:-0}"; shift 2 ;;
    -*)
      extra_args+=("$1"); shift ;;
    *)
      if [[ -z "$pptx_path" ]]; then
        pptx_path="$1"
      elif [[ -z "$md_path" ]]; then
        md_path="$1"
      else
        extra_args+=("$1")
      fi
      shift ;;
  esac
done

if [[ -z "$pptx_path" || -z "$md_path" ]]; then
  echo "Usage: $0 <input.pptx> <md.md> [-PythonExe <path>] [extra args...]" >&2
  exit 2
fi

if [[ -z "$python_exe" || ! -f "$python_exe" ]]; then
  echo "PythonExe not found. Specify -PythonExe or set CONVERT_FROM_PPTX_PYTHON env var to venv python.exe path." >&2
  exit 2
fi

# SEC-M2: .exe 拡張子検証
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
verify_script="$script_dir/verify_md.py"
if [[ ! -f "$verify_script" ]]; then
  echo "verify_md.py not found at expected location: $verify_script" >&2
  exit 2
fi

export PYTHONUTF8=1
export PYTHONIOENCODING=utf-8

set +e
if command -v timeout >/dev/null 2>&1; then
  timeout --foreground "$timeout_sec" \
    "$python_exe" -u "$verify_script" "$pptx_path" "$md_path" \
    "${extra_args[@]+"${extra_args[@]}"}" 2>&1
  rc=$?
  if [[ $rc -eq 124 ]]; then
    echo "verify_md.py timed out after $timeout_sec sec" >&2
    exit 124
  fi
else
  "$python_exe" -u "$verify_script" "$pptx_path" "$md_path" \
    "${extra_args[@]+"${extra_args[@]}"}" 2>&1
  rc=$?
fi
set -e
exit "$rc"
