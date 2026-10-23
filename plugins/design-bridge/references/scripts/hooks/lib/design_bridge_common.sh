#!/usr/bin/env bash
# design_bridge_common.sh
#
# design-bridge プラグインのフック共通ライブラリ。
# プロジェクトルート検出・設定読み込み・state パス解決・監視対象判定を提供する。
#
# 設計:
#   - すべての関数はフェイルセーフ（判定不能時は「対象外」を返す）。
#   - 呼び出し側はフェイルオープン（例外時も exit 0）で運用する。ただし
#     「保護が外れたこと」は stderr へ 1 行通知し、無言の失効を避ける。
#   - jq は任意依存。無い場合は縮退動作（既定の監視対象・sed による抽出）に
#     切り替える。jq の有無でブロックの強度は変わらない。
#
# 信頼モデル（セキュリティレビュー H-4 対応）:
#   .claude/design-bridge.json はリポジトリ同梱＝第三者が支配しうる入力である。
#   そこから読むのは「どこを監視するか」という構成情報のみに限定し、
#   「ブロックするかどうか・何回までか」という挙動を変える値は読まない。
#   blockLimit はユーザースコープ設定（$HOME 配下）または既定値のみを使う。
#
# 注意: Windows 版 jq は出力行を CRLF で返すことがある。jq の出力は必ず
#       `tr -d '\r'` を通すこと。省くと値の末尾に CR が残り、拡張子やパスの
#       比較が無言で失敗する（最終行だけ CR が付かないため、一部のケースだけ
#       通ってしまい原因特定が難しい）。

# 連続ブロックの既定上限と許容範囲。リポジトリ設定からは読まない。
DB_BLOCK_LIMIT_DEFAULT=3
DB_BLOCK_LIMIT_MIN=1
DB_BLOCK_LIMIT_MAX=10

# pending に記録してよい相対パスの文字集合。
# ここを通った文字列だけを stderr（＝モデルのコンテキスト）へ出す。
DB_SAFE_REL_RE='^[A-Za-z0-9._/-]{1,200}$'

# Windows 形式のパスを Git Bash 形式に正規化する。
#   C:\foo\bar -> /c/foo/bar
#   C:/foo/bar -> /c/foo/bar
# 連続スラッシュは 1 つに圧縮する。圧縮しないと先頭が "//" の文字列が残り、
# Git Bash が UNC パスとして名前解決を試みてハングする。
db_normalize_path() {
  local p="$1"
  p="${p//\\//}"
  if [[ "$p" =~ ^([A-Za-z]):/(.*)$ ]]; then
    local drive
    drive="$(printf '%s' "${BASH_REMATCH[1]}" | tr 'A-Z' 'a-z')"
    p="/${drive}/${BASH_REMATCH[2]}"
  fi
  while [[ "$p" == *//* ]]; do
    p="${p//\/\//\/}"
  done
  while [[ "${#p}" -gt 1 && "$p" == */ ]]; do
    p="${p%/}"
  done
  printf '%s' "$p"
}

# 指定ディレクトリから上方向に .git を探索し、プロジェクトルートを返す。
# 見つからない場合と、絶対パスでない入力の場合は 1 を返す。
# dirname は "." を不動点として返すため、前回値との一致で必ず脱出する。
db_find_project_root() {
  local dir prev=""
  dir="$(db_normalize_path "$1")"
  [[ "$dir" == /* ]] || return 1
  while [[ -n "$dir" && "$dir" != "/" && "$dir" != "$prev" ]]; do
    if [[ -e "$dir/.git" ]]; then
      printf '%s' "$dir"
      return 0
    fi
    prev="$dir"
    dir="$(dirname -- "$dir")"
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

# 未反映リスト（TSV: <kind>\t<相対パス>）のパス。
db_pending_path() {
  printf '%s/pending.tsv' "$(db_state_dir "$1")"
}

# 連続ブロック回数カウンタのパス。
db_block_count_path() {
  printf '%s/block-count' "$(db_state_dir "$1")"
}

# 却下済みマーカー（上限到達時の pending 内容ハッシュ）のパス。
db_dismissed_path() {
  printf '%s/dismissed' "$(db_state_dir "$1")"
}

# design-bridge が導入済みのプロジェクトかどうか。
db_is_enabled() {
  [[ -f "$(db_config_path "$1")" ]]
}

# jq が利用可能かどうか。
db_has_jq() {
  command -v jq >/dev/null 2>&1
}

# 監視対象の定義を "<dir>|<ext>|<kind>" の行として返す。
# 設定の watch[] を読むが、解析できない場合は既定値へ縮退する。
# kind 省略時は dir 名から推定する（mocks -> mock、それ以外 -> spec）。
db_watch_entries() {
  local config="$1"
  local entries=""

  if db_has_jq && [[ -f "$config" ]]; then
    entries="$(jq -r '
      .watch[]?
      | select(.dir != null and .ext != null)
      | "\(.dir)|\(.ext)|\(.kind // (if (.dir | test("mock")) then "mock" else "spec" end))"
    ' "$config" 2>/dev/null | tr -d '\r')"
  fi

  if [[ -z "${entries//[[:space:]]/}" ]]; then
    entries=$'specs|md|spec\nmocks|html|mock'
  fi
  printf '%s' "$entries"
}

# 相対パスの種別を判定して出力する（spec / mock）。
# 監視対象でなければ 1 を返し、何も出力しない。
db_classify() {
  local rel="$1"
  local config="$2"
  local d e k

  while IFS='|' read -r d e k; do
    [[ -z "$d" || -z "$e" ]] && continue
    d="${d%/}"
    if [[ "$rel" == "${d}/"* && "$rel" == *".${e}" ]]; then
      printf '%s' "${k:-spec}"
      return 0
    fi
  done <<< "$(db_watch_entries "$config")"
  return 1
}

# 相対パスが pending へ記録してよい形かどうか。
# ここを通らない値は記録も表示もしない（stderr 経由でモデルへ届くため）。
db_is_safe_rel() {
  local rel="$1"
  [[ "$rel" =~ $DB_SAFE_REL_RE ]] || return 1
  [[ "$rel" == *".."* ]] && return 1
  [[ "$rel" == /* ]] && return 1
  return 0
}

# 連続ブロックの上限。リポジトリ設定は参照しない。
# ユーザースコープ設定 $HOME/.claude/.local/plugins/design-bridge/user-config.json
# の blockLimit があればそれを使い、範囲外は既定値へ丸める。
db_block_limit() {
  local limit=""
  local user_config="${HOME}/.claude/.local/plugins/design-bridge/user-config.json"

  if db_has_jq && [[ -f "$user_config" ]]; then
    limit="$(jq -r '.blockLimit // empty' "$user_config" 2>/dev/null | tr -d '\r')"
  fi
  if [[ "$limit" =~ ^[0-9]{1,3}$ ]] \
     && [[ "$limit" -ge "$DB_BLOCK_LIMIT_MIN" ]] \
     && [[ "$limit" -le "$DB_BLOCK_LIMIT_MAX" ]]; then
    printf '%s' "$limit"
  else
    printf '%s' "$DB_BLOCK_LIMIT_DEFAULT"
  fi
}

# ファイル内容のハッシュを返す（却下済み判定に使う）。
# sha256sum / md5sum / cksum の順に利用可能なものを使う。
db_content_hash() {
  local f="$1"
  [[ -f "$f" ]] || { printf 'empty'; return 0; }
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" 2>/dev/null | cut -d' ' -f1
  elif command -v md5sum >/dev/null 2>&1; then
    md5sum "$f" 2>/dev/null | cut -d' ' -f1
  else
    cksum "$f" 2>/dev/null | tr -d ' ' | tr -d '\n'
  fi
}
