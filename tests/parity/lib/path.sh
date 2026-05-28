#!/usr/bin/env bash
# tests/parity/lib/path.sh
# Git Bash 上で Windows パス (C:\...) と Unix 風パス (/c/...) を相互変換する。
# Bash 実装と PowerShell 実装が同じファイルを指せるようにする補助。

# parity_to_unix_path <path>
#   Windows パス -> /c/... 形式
parity_to_unix_path() {
  local p="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u -- "$p"
  else
    # cygpath 不在時のフォールバック: C:\ -> /c/、バックスラッシュを正規化
    p="${p//\\/\/}"
    if [[ "$p" =~ ^([A-Za-z]):/ ]]; then
      local drive="${BASH_REMATCH[1]}"
      p="/${drive,,}${p#?:}"
    fi
    printf '%s\n' "$p"
  fi
}

# parity_to_windows_path <path>
#   /c/... -> C:\ 形式
parity_to_windows_path() {
  local p="$1"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w -- "$p"
  else
    # フォールバック: /c/foo -> C:\foo
    if [[ "$p" =~ ^/([a-zA-Z])/(.*)$ ]]; then
      local drive="${BASH_REMATCH[1]^^}"
      local rest="${BASH_REMATCH[2]//\//\\}"
      printf '%s\n' "${drive}:\\${rest}"
    else
      printf '%s\n' "${p//\//\\}"
    fi
  fi
}

# parity_repo_root
#   リポジトリのルート絶対パス（Unix 形式）を返す。
parity_repo_root() {
  git rev-parse --show-toplevel 2>/dev/null \
    || (cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)
}
