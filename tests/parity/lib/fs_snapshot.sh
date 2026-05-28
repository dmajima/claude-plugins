#!/usr/bin/env bash
# tests/parity/lib/fs_snapshot.sh
# 指定ディレクトリ群のファイルツリーを find + sha256sum でハッシュ化し、
# Bash 版と PowerShell 版で生成された結果を機械的に比較できるようにする。
#
# 使い方:
#   parity_fs_snapshot <root> <include_path...>
#
# 出力（stdout）:
#   <sha256>  <relative_path>
#   ...
#   ソート済み（locale 非依存: LC_ALL=C）

parity_fs_snapshot() {
  local root="$1"; shift
  local -a includes=("$@")

  if [[ ! -d "$root" ]]; then
    return 0
  fi

  (
    cd "$root" || exit 1
    local -a targets=()
    if [[ ${#includes[@]} -eq 0 ]]; then
      targets+=(".")
    else
      local p
      for p in "${includes[@]}"; do
        # __SANDBOX__/foo のような前置きを剥がし、root からの相対パスに直す
        p="${p#__SANDBOX__/}"
        p="${p#./}"
        if [[ -e "$p" ]]; then
          targets+=("$p")
        fi
      done
    fi
    if [[ ${#targets[@]} -eq 0 ]]; then
      return 0
    fi

    # シンボリックリンクは追跡せず、リンク自体を sha256 対象にする（リンク先固定値を出力）
    LC_ALL=C find "${targets[@]}" -type f -print0 2>/dev/null \
      | LC_ALL=C sort -z \
      | xargs -0 -r sha256sum 2>/dev/null \
      | LC_ALL=C sort

    # シンボリックリンク自体も別ラインで出す（先 = `LINK`, 後 = ターゲット文字列のハッシュ）
    LC_ALL=C find "${targets[@]}" -type l -print0 2>/dev/null \
      | LC_ALL=C sort -z \
      | while IFS= read -r -d '' link; do
          local target
          target="$(readlink -- "$link" 2>/dev/null || true)"
          local h
          h="$(printf '%s' "$target" | sha256sum | awk '{print $1}')"
          printf 'LINK_%s  %s\n' "$h" "$link"
        done

    # ディレクトリ自体（空ディレクトリ含む）も列挙する
    LC_ALL=C find "${targets[@]}" -type d -print 2>/dev/null \
      | LC_ALL=C sort \
      | sed -E 's|^|DIR  |'
  )
}
