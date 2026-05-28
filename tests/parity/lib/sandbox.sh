#!/usr/bin/env bash
# tests/parity/lib/sandbox.sh
# サンドボックスディレクトリの生成・破棄を提供する。
# parity test 実行時、各ケースは独立した一時ディレクトリ配下で動く。

# parity_sandbox_create
#   引数: なし
#   出力: 作成した絶対パス（stdout）
parity_sandbox_create() {
  local d
  d="$(mktemp -d -t parity-XXXXXXXX)"
  printf '%s\n' "$d"
}

# parity_sandbox_destroy <path>
#   path 以下を再帰削除する。
#   セーフガード: 引数が空・"/"・"$HOME" の場合は何もしない。
parity_sandbox_destroy() {
  local d="${1:-}"
  if [[ -z "$d" || "$d" == "/" || "$d" == "$HOME" ]]; then
    echo "[sandbox] refuse to destroy: '$d'" >&2
    return 1
  fi
  if [[ ! -d "$d" ]]; then
    return 0
  fi
  rm -rf -- "$d"
}

# parity_sandbox_substitute <sandbox> <string>
#   string 中の "__SANDBOX__" を sandbox の絶対パスに置換する。
parity_sandbox_substitute() {
  local sandbox="$1"
  local s="$2"
  printf '%s' "${s//__SANDBOX__/$sandbox}"
}
