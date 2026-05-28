#!/usr/bin/env bash
# cleanup.sh - .claude/.local/work/ 配下のセッションフォルダクリーンアップ (Bash ラッパー版)
#
# 通常運用は本スクリプトを利用する。
# 本体は PowerShell 実装 (cleanup.ps1) で、多層安全装置 + ReparsePoint 検査 +
# git 操作 + JSON 設定読込 等を含む 386 行の複雑なロジックを持つ。
# Bash 純粋実装は等価性検証コストが大きいため、Bash ツールから呼べる
# 薄ラッパーとして pwsh -File 経由で起動する (動作差異ゼロ保証)。
#
# 引数は PowerShell 版にそのまま透過する。

set -euo pipefail

script_dir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ps1="$script_dir/cleanup.ps1"

if [[ ! -f "$ps1" ]]; then
  echo "[cleanup] PowerShell 本体が見つかりません: $ps1" >&2
  exit 2
fi
if ! command -v pwsh >/dev/null 2>&1; then
  echo "[cleanup] pwsh (PowerShell 7+) が PATH に見つかりません。" >&2
  exit 127
fi

exec pwsh -NoProfile -File "$ps1" "$@"
