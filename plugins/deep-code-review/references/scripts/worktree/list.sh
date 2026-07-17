#!/usr/bin/env bash
set -euo pipefail

# PR レビュー用 worktree の一覧出力
#
# Stdout: タブ区切り（branch_name \t timestamp \t path）
#         作成日時の昇順（古い順）

REPO_ROOT="${1:?Usage: list.sh <repo_root>}"
WORKTREE_BASE="${REPO_ROOT}/.claude/.local/plugins/deep-code-review/_worktree"

if [ ! -d "${WORKTREE_BASE}" ]; then
  exit 0
fi

for d in "${WORKTREE_BASE}"/*/; do
  [ -d "$d" ] || continue
  d="${d%/}"

  meta="${d}/.worktree-meta"
  if [ -f "$meta" ]; then
    branch=$(grep '^branch=' "$meta" | cut -d= -f2-)
    ts=$(grep '^timestamp=' "$meta" | cut -d= -f2-)
  else
    branch=$(basename "$d" | sed 's/__/\//g')
    ts="0000-00-00T00:00:00Z"
  fi

  printf '%s\t%s\t%s\n' "$branch" "$ts" "$d"
done | sort -t$'\t' -k2,2
