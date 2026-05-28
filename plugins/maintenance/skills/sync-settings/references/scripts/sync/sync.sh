#!/usr/bin/env bash
# sync.sh - Claude Code 設定の Git 経由同期 (Bash ラッパー版)
# 通常運用は本スクリプトを利用する。本体は sync.ps1 (706 行・複雑な
# git 操作 + JSON 深マージ + path traversal 対策)。
# Bash 純粋実装は等価性検証コスト大のため、pwsh 薄ラッパーで起動 (動作差異ゼロ)。
set -euo pipefail

script_dir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ps1="$script_dir/sync.ps1"

[[ ! -f "$ps1" ]] && { echo "[sync] PowerShell 本体が見つかりません: $ps1" >&2; exit 2; }
command -v pwsh >/dev/null 2>&1 || { echo "[sync] pwsh (PowerShell 7+) が PATH に見つかりません。" >&2; exit 127; }

exec pwsh -NoProfile -File "$ps1" "$@"
