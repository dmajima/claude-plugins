#!/usr/bin/env bash
# check_version_bump_on_commit.sh - PreToolUse Bash フック（ADR-027）
#
# 目的:
#   `git commit ...` 直前に check_version_bump.sh を呼び出し、
#   バージョン未更新のプラグインがある場合は警告する。
#
#   背景: Stop フックの stderr は Claude Code の会話 context に
#   届かないケースがあるため（環境/タイミング依存）、確実に届く
#   PreToolUse の additionalContext 経路で同じ検査を行う。
#
# 入力:
#   stdin: PreToolUse Bash JSON。{"tool_name":"Bash","tool_input":{"command":"...","description":"..."}}
#
# 出力:
#   - git commit 以外の Bash 呼び出し: exit 0、無音
#   - git commit かつ全プラグインで version 更新済み: exit 0、無音
#   - git commit かつ version 未更新あり: exit 0 + stderr に警告（fail-open）
#
# 設計:
#   - 常に exit 0（コミットをブロックしない）
#   - 検査ロジックは check_version_bump.sh に完全委譲（重複実装を避ける）

set -uo pipefail

INPUT=$(cat)

# tool_name が Bash でなければ即終了（matcher が誤発火した場合のガード）
TOOL_NAME=$(printf '%s' "$INPUT" | sed -n 's/.*"tool_name"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
if [ "$TOOL_NAME" != "Bash" ]; then
  exit 0
fi

# tool_input.command を抽出
COMMAND=$(printf '%s' "$INPUT" | sed -n 's/.*"command"[[:space:]]*:[[:space:]]*"\(.*\)".*/\1/p' | head -1)
if [ -z "$COMMAND" ]; then
  exit 0
fi

# JSON エスケープを最低限元に戻す（\\ → \、\" → "、\/ → /）
COMMAND=$(printf '%s' "$COMMAND" | sed -e 's/\\\\/\\/g' -e 's/\\"/"/g' -e 's|\\/|/|g')

# `git commit` を含むかどうか判定（先頭一致 or && / ; / | / && 等で連結された途中も含む）
# 単純化: コマンド内のどこかに「単語境界 git commit」があれば対象とする
case "$COMMAND" in
  *"git commit"*)
    : # 対象、後続処理へ
    ;;
  *)
    exit 0
    ;;
esac

# check_version_bump.sh に委譲（同ディレクトリ内）
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
DELEGATE="$SCRIPT_DIR/check_version_bump.sh"

if [ ! -x "$DELEGATE" ] && [ ! -f "$DELEGATE" ]; then
  exit 0
fi

# 委譲スクリプトに空 JSON を渡す（check_version_bump.sh は stdin を読み捨てる）
printf '{}' | bash "$DELEGATE"
exit 0
