#!/usr/bin/env bash
# design_bridge_common.sh
#
# design-bridge プラグインのフック共通ライブラリ。
# プロジェクトルート検出・設定読み込み・state パス解決・監視対象判定を提供する。
#
# 設計: すべての関数はフェイルセーフ（判定不能時は「対象外」を返す）。
#       呼び出し側はフェイルオープン（例外時も exit 0）で運用すること。
#
# 注意: Windows 版 jq は出力行を CRLF で返すことがある。jq の出力は必ず
#       `tr -d '\r'` を通すこと。省くと値の末尾に CR が残り、拡張子やパスの
#       比較が無言で失敗する（最終行だけ CR が付かないため、一部のケースだけ
#       通ってしまい原因特定が難しい）。

# Windows 形式のパスを Git Bash 形式に正規化する。
#   C:\foo\bar -> /c/foo/bar
#   C:/foo/bar -> /c/foo/bar
db_normalize_path() {
  local p="$1"
  p="${p//\\//}"
  if [[ "$p" =~ ^([A-Za-z]):/(.*)$ ]]; then
    local drive
    drive="$(printf '%s' "${BASH_REMATCH[1]}" | tr 'A-Z' 'a-z')"
    p="/${drive}/${BASH_REMATCH[2]}"
  fi
  # 末尾スラッシュを除去（ルート "/" は維持）
  while [[ "${#p}" -gt 1 && "$p" == */ ]]; do
    p="${p%/}"
  done
  printf '%s' "$p"
}

# 指定ディレクトリから上方向に .git を探索し、プロジェクトルートを返す。
# 見つからなければ 1 を返す。
db_find_project_root() {
  local dir
  dir="$(db_normalize_path "$1")"
  while [[ -n "$dir" && "$dir" != "/" ]]; do
    if [[ -e "$dir/.git" ]]; then
      printf '%s' "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  return 1
}

# プロジェクト設定ファイル（コミット対象）のパス。
db_config_path() {
  printf '%s/.claude/design-bridge.json' "$1"
}

# state ディレクトリ（バージョン管理対象外）のパス。
db_state_dir() {
  printf '%s/.claude/.local/plugins/design-bridge' "$1"
}

# 未反映リストのパス。
db_pending_path() {
  printf '%s/pending.txt' "$(db_state_dir "$1")"
}

# 連続ブロック回数カウンタのパス。
db_block_count_path() {
  printf '%s/block-count' "$(db_state_dir "$1")"
}

# design-bridge が導入済みのプロジェクトかどうか。
db_is_enabled() {
  [[ -f "$(db_config_path "$1")" ]]
}

# 相対パスが監視対象かどうかを判定する。
# 設定の watch[] （{"dir": "specs", "ext": "md"} の配列）を参照し、
# 未設定または解析不能ならデフォルト（specs/*.md, mocks/*.html）を使う。
db_is_watched() {
  local rel="$1"
  local config="$2"
  local entries=""

  if command -v jq >/dev/null 2>&1 && [[ -f "$config" ]]; then
    entries="$(jq -r '.watch[]? | select(.dir != null and .ext != null) | "\(.dir)|\(.ext)"' "$config" 2>/dev/null | tr -d '\r')"
  fi
  if [[ -z "${entries//[[:space:]]/}" ]]; then
    entries=$'specs|md\nmocks|html'
  fi

  local d e
  while IFS='|' read -r d e; do
    [[ -z "$d" || -z "$e" ]] && continue
    if [[ "$rel" == "${d}/"* && "$rel" == *".${e}" ]]; then
      return 0
    fi
  done <<< "$entries"
  return 1
}

# 連続ブロックの上限回数。設定の blockLimit があればそれを使う（既定 3）。
db_block_limit() {
  local config="$1"
  local limit=""
  if command -v jq >/dev/null 2>&1 && [[ -f "$config" ]]; then
    limit="$(jq -r '.blockLimit // empty' "$config" 2>/dev/null | tr -d '\r')"
  fi
  if [[ "$limit" =~ ^[0-9]+$ ]] && [[ "$limit" -ge 1 ]]; then
    printf '%s' "$limit"
  else
    printf '3'
  fi
}
