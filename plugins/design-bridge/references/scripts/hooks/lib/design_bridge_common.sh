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
# 信頼モデル:
#   .claude/design-bridge.json と .claude/.local/ 配下は、リポジトリを clone
#   しただけで攻撃者の支配下に入りうる入力である。したがって:
#   - 設定から読むのは「どこを監視するか」という構成情報のみ。「ブロックするか
#     どうか・何回までか」という挙動を変える値は読まない（blockLimit は
#     ユーザースコープ設定または既定値のみ）。
#   - 設定由来の値（kind）は列挙値へ正規化してから使う。生の文字列を
#     pending へ書くと、区切り文字の注入で読み取り側の列がずれる。
#   - state ファイルへ書く前に経路上の symlink を拒否する。symlink を同梱
#     されると、追記内容が ~/.bashrc 等の任意ファイルへ流れ込む。
#
# 注意: Windows 版 jq は出力行を CRLF で返すことがある。jq の出力は必ず
#       `tr -d '\r'` を通すこと。省くと値の末尾に CR が残り、拡張子やパスの
#       比較が無言で失敗する（最終行だけ CR が付かないため、一部のケースだけ
#       通ってしまい原因特定が難しい）。

# 連続ブロックの既定上限と許容範囲。リポジトリ設定からは読まない。
DB_BLOCK_LIMIT_DEFAULT=3
DB_BLOCK_LIMIT_MIN=1
DB_BLOCK_LIMIT_MAX=10

# stderr（＝モデルのコンテキスト）へ出してよい相対パスの文字集合。
# 先頭にハイフンを許さない（他用途へ流用したときのオプション誤認を防ぐ）。
DB_DISPLAYABLE_REL_RE='^[A-Za-z0-9._][A-Za-z0-9._/-]{0,199}$'

# 追跡対象として記録してよい相対パスの最大長。
DB_TRACKABLE_REL_MAX=400

# pending に積める行数の上限。巨大なファイルを同梱されてフックが毎回
# タイムアウトするのを防ぐ。
DB_PENDING_MAX_LINES=2000

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

# root から target までの各階層に symlink が無いことを確認する。
# いずれかが symlink なら 1 を返す。
#
# リポジトリに `.claude/.local/plugins/design-bridge/pending.tsv -> ~/.bashrc`
# のような symlink を同梱されると、フックの追記がそのまま任意ファイルへの
# 書き込みになる。.gitignore は追跡済みファイルの checkout を止めないため、
# 無視設定では防げない。書き込み前に必ずこの関数を通すこと。
db_path_has_no_symlink() {
  local root="$1"
  local target="$2"
  [[ -z "$root" || -z "$target" ]] && return 1
  case "$target" in
    "${root}/"*) : ;;
    *) return 1 ;;
  esac

  [[ -L "$root" ]] && return 1
  local rel="${target#"${root}/"}"
  local cur="$root"
  local part
  local oldifs="$IFS"
  IFS='/'
  for part in $rel; do
    [[ -z "$part" ]] && continue
    cur="${cur}/${part}"
    if [[ -L "$cur" ]]; then
      IFS="$oldifs"
      return 1
    fi
  done
  IFS="$oldifs"
  return 0
}

# 書き込み先として安全か（symlink でなく、存在するなら通常ファイルである）。
db_is_safe_write_target() {
  local root="$1"
  local target="$2"
  db_path_has_no_symlink "$root" "$target" || return 1
  if [[ -e "$target" && ! -f "$target" ]]; then
    return 1
  fi
  return 0
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
# kind は db_classify 側で列挙値へ正規化するため、ここでは素通しでよい。
db_watch_entries() {
  local config="$1"
  local entries=""

  if db_has_jq && [[ -f "$config" ]]; then
    entries="$(jq -r '
      .watch[]?
      | select(.dir != null and .ext != null)
      | "\(.dir)|\(.ext)|\(.kind // "")"
    ' "$config" 2>/dev/null | tr -d '\r')"
  fi

  if [[ -z "${entries//[[:space:]]/}" ]]; then
    entries=$'specs|md|spec\nmocks|html|mock'
  fi
  printf '%s' "$entries"
}

# 相対パスの種別を判定して出力する。
# 出力は必ず "spec" または "mock" のいずれかに正規化される。設定由来の
# 文字列をそのまま返すと、タブや改行の混入で pending の列がずれ、読み取り側
# の検証をすり抜けて保護が無言で停止する。
# 監視対象でなければ 1 を返し、何も出力しない。
db_classify() {
  local rel="$1"
  local config="$2"
  local d e k

  while IFS='|' read -r d e k; do
    [[ -z "$d" || -z "$e" ]] && continue
    d="${d%/}"
    if [[ "$rel" == "${d}/"* && "$rel" == *".${e}" ]]; then
      case "$k" in
        mock*) printf 'mock' ;;
        *) printf 'spec' ;;
      esac
      return 0
    fi
  done <<< "$(db_watch_entries "$config")"
  return 1
}

# 追跡対象として pending に記録してよい相対パスか。
# 日本語などの非 ASCII を許容する。表示可否とは別の判定である点が重要で、
# ここを厳しくすると日本語ファイル名が無言で保護対象外になる。
db_is_trackable_rel() {
  local rel="$1"
  [[ -z "$rel" ]] && return 1
  [[ "${#rel}" -gt "$DB_TRACKABLE_REL_MAX" ]] && return 1
  [[ "$rel" == /* ]] && return 1
  [[ "$rel" == *".."* ]] && return 1
  [[ "$rel" =~ [[:cntrl:]] ]] && return 1
  return 0
}

# stderr（モデルのコンテキスト）へ出力してよい相対パスか。
# 追跡はできるが表示はできない値（日本語名など）があるため、呼び出し側は
# 表示できなかった件数を別途伝えること。
db_is_displayable_rel() {
  local rel="$1"
  db_is_trackable_rel "$rel" || return 1
  [[ "$rel" =~ $DB_DISPLAYABLE_REL_RE ]] || return 1
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
  if [[ "$limit" =~ ^[0-9]{1,3}$ ]]; then
    # 10# を付けないと "08" 等が 8 進数として評価され算術エラーになる。
    limit=$((10#$limit))
    if [[ "$limit" -ge "$DB_BLOCK_LIMIT_MIN" && "$limit" -le "$DB_BLOCK_LIMIT_MAX" ]]; then
      printf '%s' "$limit"
      return 0
    fi
  fi
  printf '%s' "$DB_BLOCK_LIMIT_DEFAULT"
}

# ファイル内容のハッシュを返す（却下済み判定に使う）。
# 暗号学的ハッシュが使えない環境では空を返す。弱いハッシュで代用すると、
# 衝突を作られて却下済み判定を恒久的に黙らせられるため、その場合は
# 却下機構そのものを使わない（呼び出し側が空を見て判断する）。
db_content_hash() {
  local f="$1"
  [[ -f "$f" ]] || { printf 'empty'; return 0; }
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" 2>/dev/null | cut -d' ' -f1
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$f" 2>/dev/null | cut -d' ' -f1
  else
    printf ''
  fi
}
