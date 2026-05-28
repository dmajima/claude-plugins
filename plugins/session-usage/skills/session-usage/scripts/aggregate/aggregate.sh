#!/usr/bin/env bash
# aggregate.sh - Claude Code セッション JSONL からトークン消費量を集計 (Bash ラッパー版)
#
# 通常運用は本スクリプトを利用する。
# 本体は aggregate.ps1 (312 行・.NET StreamReader / ConvertFrom-Json /
# Set-Clipboard / 全角幅計算など PowerShell 専用機能を多用)。
# Bash 純粋実装または Python 再実装は等価性検証コストが大きいため、
# pwsh -File 経由で起動する薄ラッパーとして提供 (動作差異ゼロ保証)。
#
# 引数は PowerShell 版にそのまま透過する。

set -euo pipefail

script_dir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ps1="$script_dir/aggregate.ps1"

if [[ ! -f "$ps1" ]]; then
  echo "[aggregate] PowerShell 本体が見つかりません: $ps1" >&2
  exit 2
fi
if ! command -v pwsh >/dev/null 2>&1; then
  echo "[aggregate] pwsh (PowerShell 7+) が PATH に見つかりません。" >&2
  echo "  本機能は PowerShell 専用 (.NET StreamReader / Set-Clipboard / 全角幅計算) のため、pwsh が必須です。" >&2
  exit 127
fi

exec pwsh -NoProfile -File "$ps1" "$@"
