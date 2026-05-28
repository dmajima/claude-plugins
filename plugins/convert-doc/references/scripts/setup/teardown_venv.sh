#!/usr/bin/env bash
# convert-doc プラグイン venv 削除スクリプト (Bash 版)
#
# 通常運用は本スクリプトを利用する。
# PowerShell フォールバック: teardown_venv.ps1 （Git Bash 不調時等）
#
# PowerShell 版 (teardown_venv.ps1) と完全に同じメッセージ・終了コード・副作用を持つ。
#
# 使い方:
#   bash teardown_venv.sh <work_dir>
#   bash teardown_venv.sh -WorkDir <path>
set -euo pipefail

work_dir=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -WorkDir|--work-dir)
      work_dir="${2:-}"; shift 2 ;;
    *)
      if [[ -z "$work_dir" ]]; then
        work_dir="$1"
      fi
      shift ;;
  esac
done

if [[ -z "$work_dir" ]]; then
  echo "Usage: $0 <work_dir>" >&2
  exit 2
fi

venv_path="$work_dir/.venv"

if [[ -d "$venv_path" ]]; then
  echo "[OK] Removing venv at $venv_path"
  rm -rf -- "$venv_path"
fi

echo "[DONE] venv removed"
