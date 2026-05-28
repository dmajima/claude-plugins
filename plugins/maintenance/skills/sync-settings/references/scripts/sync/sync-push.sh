#!/usr/bin/env bash
# sync-push.sh - sync 結果を Git push (Bash ラッパー版)
# 通常運用は本スクリプトを利用する。本体は sync-push.ps1 (459 行・gh CLI 連携)。
set -euo pipefail

script_dir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ps1="$script_dir/sync-push.ps1"

[[ ! -f "$ps1" ]] && { echo "[sync-push] PowerShell 本体が見つかりません: $ps1" >&2; exit 2; }
command -v pwsh >/dev/null 2>&1 || { echo "[sync-push] pwsh (PowerShell 7+) が PATH に見つかりません。" >&2; exit 127; }

exec pwsh -NoProfile -File "$ps1" "$@"
