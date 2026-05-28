#!/usr/bin/env bash
# sync-common.sh - sync 共通関数 (Bash ラッパー版)
# 通常運用は本スクリプトを利用する。本体は sync-common.ps1。
set -euo pipefail

script_dir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ps1="$script_dir/sync-common.ps1"

[[ ! -f "$ps1" ]] && { echo "[sync-common] PowerShell 本体が見つかりません: $ps1" >&2; exit 2; }
command -v pwsh >/dev/null 2>&1 || { echo "[sync-common] pwsh (PowerShell 7+) が PATH に見つかりません。" >&2; exit 127; }

exec pwsh -NoProfile -File "$ps1" "$@"
