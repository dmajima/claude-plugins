#!/usr/bin/env bash
set -euo pipefail

# PR レビュー用 git worktree の削除
#
# Usage:
#   teardown.sh <repo_root> <branch_name>   # 指定ブランチの worktree を削除
#   teardown.sh <repo_root> --all           # 全 worktree を削除
#
# Exit: 0=成功, 1=エラー

REPO_ROOT="${1:?Usage: teardown.sh <repo_root> <branch_name|--all>}"
TARGET="${2:?Usage: teardown.sh <repo_root> <branch_name|--all>}"

WORKTREE_BASE="${REPO_ROOT}/.claude/.local/plugins/deep-code-review/_worktree"

if ! git -C "${REPO_ROOT}" rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: ${REPO_ROOT} is not a git repository" >&2
  exit 1
fi

remove_one() {
  local wt_path="$1"
  if [ ! -d "$wt_path" ]; then
    return 0
  fi
  if [ -L "$wt_path" ]; then
    echo "ERROR: worktree path is a symlink, refusing to remove: ${wt_path}" >&2
    return 1
  fi

  local display_name
  local meta="${wt_path}/.worktree-meta"
  if [ -f "$meta" ]; then
    display_name=$(grep '^branch=' "$meta" | cut -d= -f2-)
  else
    display_name=$(basename "$wt_path" | sed 's/__/\//g')
  fi

  if git -C "${REPO_ROOT}" worktree remove --force "${wt_path}" 2>/dev/null; then
    echo "Removed: ${display_name}" >&2
  else
    if [ -L "$wt_path" ]; then
      echo "ERROR: worktree path became a symlink during removal: ${wt_path}" >&2
      return 1
    fi
    if rm -rf "${wt_path}" 2>/dev/null && git -C "${REPO_ROOT}" worktree prune 2>/dev/null; then
      echo "Removed (fallback): ${display_name}" >&2
    else
      echo "ERROR: failed to remove: ${display_name}" >&2
      return 1
    fi
  fi
}

if [ "$TARGET" = "--all" ]; then
  if [ ! -d "${WORKTREE_BASE}" ]; then
    echo "No worktrees found" >&2
    exit 0
  fi
  success_count=0
  fail_count=0
  for d in "${WORKTREE_BASE}"/*/; do
    [ -d "$d" ] || continue
    if remove_one "${d%/}"; then
      success_count=$((success_count + 1))
    else
      fail_count=$((fail_count + 1))
    fi
  done
  echo "Removed ${success_count} worktree(s), failed ${fail_count} (total $((success_count + fail_count)))" >&2
  [ "${fail_count}" -eq 0 ] || exit 1
else
  if ! printf '%s' "$TARGET" | grep -qE '^[a-zA-Z0-9][a-zA-Z0-9._/\-]*$'; then
    echo "ERROR: branch name contains invalid characters (must start with alphanumeric)" >&2
    exit 1
  fi
  if printf '%s' "$TARGET" | grep -qF '..'; then
    echo "ERROR: branch name contains '..'" >&2
    exit 1
  fi

  BRANCH_SLUG="${TARGET//\//__}"
  WORKTREE_PATH="${WORKTREE_BASE}/${BRANCH_SLUG}"
  if [ ! -d "${WORKTREE_PATH}" ]; then
    echo "ERROR: worktree not found: ${TARGET}" >&2
    exit 1
  fi
  remove_one "${WORKTREE_PATH}"
fi
