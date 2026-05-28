#!/usr/bin/env bash
# run_psscriptanalyzer.sh - PSScriptAnalyzer 実行用 Bash ラッパー
#
# 本機能は PowerShell 専用ツール (Invoke-ScriptAnalyzer) のため、Bash 純粋実装は
# 不可能。Bash ツールから呼べるよう pwsh を経由する薄いラッパーとして提供する。
# 本体は run_psscriptanalyzer.ps1。
#
# 動作差異ゼロ保証: Bash → pwsh → .ps1 と起動するだけで、PowerShell 実装の
# 全機能・全出力をそのまま透過する。

set -euo pipefail

script_dir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ps1="$script_dir/run_psscriptanalyzer.ps1"

if [[ ! -f "$ps1" ]]; then
  echo "[run_psscriptanalyzer] PowerShell 本体が見つかりません: $ps1" >&2
  exit 2
fi

if ! command -v pwsh >/dev/null 2>&1; then
  echo "[run_psscriptanalyzer] pwsh (PowerShell 7+) が PATH に見つかりません。" >&2
  echo "  PSScriptAnalyzer は PowerShell 専用ツールのため、pwsh が必須です。" >&2
  exit 127
fi

exec pwsh -NoProfile -File "$ps1" "$@"
