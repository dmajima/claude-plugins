#!/usr/bin/env bash
set -euo pipefail

# PR レビュー用 git worktree の作成・更新
#
# 新規: git fetch → git worktree add (detached HEAD)
# 既存: git fetch → git checkout FETCH_HEAD (最新化)
#
# Exit: 0=成功, 1=エラー
# Stdout: worktree の絶対パス（1 行）

REPO_ROOT="${1:?Usage: setup.sh <repo_root> <branch_name> [remote]}"
BRANCH_NAME="${2:?Usage: setup.sh <repo_root> <branch_name> [remote]}"
REMOTE="${3:-origin}"

if ! printf '%s' "$BRANCH_NAME" | grep -qE '^[a-zA-Z0-9][a-zA-Z0-9._/\-]*$'; then
  echo "ERROR: branch name contains invalid characters (must start with alphanumeric)" >&2
  exit 1
fi
if ! printf '%s' "$REMOTE" | grep -qE '^[a-zA-Z0-9][a-zA-Z0-9._\-]*$'; then
  echo "ERROR: remote name contains invalid characters (must start with alphanumeric)" >&2
  exit 1
fi
if printf '%s' "$BRANCH_NAME" | grep -qF '..'; then
  echo "ERROR: branch name contains '..'" >&2
  exit 1
fi

if ! git -C "${REPO_ROOT}" rev-parse --git-dir >/dev/null 2>&1; then
  echo "ERROR: ${REPO_ROOT} is not a git repository" >&2
  exit 1
fi

BRANCH_SLUG="${BRANCH_NAME//\//__}"
WORKTREE_BASE="${REPO_ROOT}/.claude/.local/plugins/deep-code-review/_worktree"
WORKTREE_PATH="${WORKTREE_BASE}/${BRANCH_SLUG}"

mkdir -p "${WORKTREE_BASE}"

if ! git -C "${REPO_ROOT}" fetch "${REMOTE}" "${BRANCH_NAME}" 2>/dev/null; then
  echo "ERROR: failed to fetch ${REMOTE}/${BRANCH_NAME}" >&2
  exit 1
fi
FETCHED_SHA=$(git -C "${REPO_ROOT}" rev-parse FETCH_HEAD)

# Git Bash on Windows: mktemp -d は MSYS2 の /tmp/ 配下に作成。git -c core.hooksPath は MSYS パス変換経由で正常動作する
EMPTY_HOOKS=$(mktemp -d)
trap 'rm -rf "${EMPTY_HOOKS}" 2>/dev/null || true' EXIT

git -C "${REPO_ROOT}" worktree prune 2>/dev/null || true

if [ -f "${WORKTREE_PATH}/.git" ]; then
  echo "Updating worktree: ${BRANCH_NAME} -> ${FETCHED_SHA:0:7}" >&2
  if ! git -C "${WORKTREE_PATH}" -c core.hooksPath="${EMPTY_HOOKS}" \
    checkout --detach "${FETCHED_SHA}"; then
    echo "ERROR: failed to checkout ${FETCHED_SHA:0:7} in existing worktree ${WORKTREE_PATH}" >&2
    exit 1
  fi
else
  if [ -d "${WORKTREE_PATH}" ]; then
    if [ -L "${WORKTREE_PATH}" ]; then
      echo "ERROR: worktree path is a symlink" >&2
      exit 1
    fi
    rm -rf "${WORKTREE_PATH}"
  fi
  echo "Creating worktree: ${BRANCH_NAME} -> ${FETCHED_SHA:0:7}" >&2
  if ! git -C "${REPO_ROOT}" -c core.hooksPath="${EMPTY_HOOKS}" \
    worktree add --detach "${WORKTREE_PATH}" "${FETCHED_SHA}"; then
    echo "ERROR: failed to add worktree for ${BRANCH_NAME} at ${WORKTREE_PATH}" >&2
    exit 1
  fi
fi

printf 'branch=%s\nremote=%s\ntimestamp=%s\n' \
  "${BRANCH_NAME}" "${REMOTE}" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  > "${WORKTREE_PATH}/.worktree-meta"

echo "${WORKTREE_PATH}"
