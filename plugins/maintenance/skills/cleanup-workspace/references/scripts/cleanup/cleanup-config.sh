#!/usr/bin/env bash
# cleanup-config.sh - cleanup-config.json CRUD (Bash ラッパー版)
# 通常運用は本スクリプトを利用する。本体は cleanup-config.ps1。
# Bash 純粋実装は等価性検証コスト大のため、pwsh 薄ラッパーで起動 (動作差異ゼロ)。
set -euo pipefail

script_dir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ps1="$script_dir/cleanup-config.ps1"

[[ ! -f "$ps1" ]] && { echo "[cleanup-config] PowerShell 本体が見つかりません: $ps1" >&2; exit 2; }
command -v pwsh >/dev/null 2>&1 || { echo "[cleanup-config] pwsh (PowerShell 7+) が PATH に見つかりません。" >&2; exit 127; }

exec pwsh -NoProfile -File "$ps1" "$@"
