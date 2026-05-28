#!/usr/bin/env bash
# cleanup.sh - .claude/.local/work/ 配下のセッションフォルダクリーンアップ (Bash + jq 純粋実装)
#
# 通常運用は本スクリプトを利用する。
# PowerShell フォールバック: cleanup.ps1 (機能等価、歴史的経緯で保持)
#
# 多層安全装置:
#   1. 名前パターン検証 (yyyyMMdd_nn_<summary>)
#   2. 親 3 階層検証 (work/.local/.claude)
#   3. 絶対パス前方一致検証 (グローバル or リポジトリ配下のみ)
#   4. 再解析ポイント (symlink/junction/reparse tag) 全種別拒否
#   5. 進行中セッション保護 (progress.md mtime 直近 N 分)
#
# 引数:
#   -Days <N>             閾値日数 (default: config.default_days / 30)
#   -Scope <global|project|both>  対象スコープ (default: both)
#   -DryRun               候補表示のみ (実削除なし)
#   -KeepRecent <N>       最新 N 件は保持
#   -IncludeTmp           workspace/tmp/ 配下も追加削除
#   -Yes                  AskUserQuestion 確認スキップで実削除

set -uo pipefail
# 注: cleanup-config.json パース失敗時の jq の警告など、複数箇所で
# 関数の戻り値を許容する設計のため `set -e` は使わない (PowerShell 版と等価)。

# --- 引数解析 ---
days=""
scope=""
dry_run=0
keep_recent=""
include_tmp=0
yes=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -Days|--days)               days="${2:-}"; shift 2 ;;
    -Scope|--scope)             scope="${2:-}"; shift 2 ;;
    -DryRun|--dry-run)          dry_run=1; shift ;;
    -KeepRecent|--keep-recent)  keep_recent="${2:-}"; shift 2 ;;
    -IncludeTmp|--include-tmp)  include_tmp=1; shift ;;
    -Yes|--yes)                 yes=1; shift ;;
    *) shift ;;
  esac
done

# --- 定数 ---
SESSION_REGEX='^[0-9]{8}_[0-9]{2}_[A-Za-z0-9._-]+$'
home_dir="${USERPROFILE:-${HOME:-}}"
# Windows パスを Git Bash 形式に変換
if command -v cygpath >/dev/null 2>&1 && [[ "$home_dir" == *":"* ]]; then
  home_dir="$(cygpath -u -- "$home_dir")"
fi
CONFIG_FILE="$home_dir/.claude/.local/plugins/maintenance/cleanup-config.json"

# --- 設定読込 (PowerShell 版と等価) ---
default_days=30
default_keep_recent=0
default_scope='both'
active_session_minutes=5

if [[ -f "$CONFIG_FILE" ]]; then
  if command -v jq >/dev/null 2>&1; then
    loaded="$(jq -e . "$CONFIG_FILE" 2>/dev/null)" || loaded=""
    if [[ -z "$loaded" ]]; then
      printf '警告: cleanup-config.json のパース失敗。デフォルト値を使用します。\n' >&2
    else
      loaded_version="$(printf '%s' "$loaded" | jq -r '.version // empty')"
      if [[ -n "$loaded_version" && "$loaded_version" != "1" ]]; then
        printf '警告: [schema] cleanup-config.json の version=%s は本スキーマ (version=1) と一致しません。出荷時デフォルトを採用します。\n' "$loaded_version" >&2
      else
        v="$(printf '%s' "$loaded" | jq -r '.default_days // empty')"
        [[ -n "$v" && "$v" != "null" ]] && default_days="$v"
        v="$(printf '%s' "$loaded" | jq -r '.default_keep_recent // empty')"
        [[ -n "$v" && "$v" != "null" ]] && default_keep_recent="$v"
        v="$(printf '%s' "$loaded" | jq -r '.default_scope // empty')"
        [[ -n "$v" && "$v" != "null" ]] && default_scope="$v"
        v="$(printf '%s' "$loaded" | jq -r '.active_session_minutes // empty')"
        [[ -n "$v" && "$v" != "null" ]] && active_session_minutes="$v"
      fi
    fi
  fi
fi

# --- 引数未指定時は config の既定値を採用 ---
[[ -z "$days" ]]        && days="$default_days"
[[ -z "$scope" ]]       && scope="$default_scope"
[[ -z "$keep_recent" ]] && keep_recent="$default_keep_recent"

# --- 引数組み合わせ安全装置 ---
if [[ "$dry_run" -eq 1 && "$yes" -eq 1 ]]; then
  printf '警告: --DryRun と --Yes を同時指定: --DryRun を優先 (実削除は行いません)\n' >&2
  yes=0
fi

# --- 再解析ポイント検査 ---
# Windows reparse point (junction / mountpoint / その他 reparse tag) も含めて拒否
test_reparse() {
  local path="$1"
  [[ -z "$path" ]] && return 1
  [[ ! -e "$path" && ! -L "$path" ]] && return 1
  [[ -L "$path" ]] && return 0
  if command -v cygpath >/dev/null 2>&1 && command -v fsutil >/dev/null 2>&1; then
    local wpath
    wpath="$(cygpath -w -- "$path" 2>/dev/null)" || return 1
    [[ -n "$wpath" ]] && fsutil reparsepoint query "$wpath" >/dev/null 2>&1
  fi
}

# --- パスバリデーション ---
# 多層検証で、誤って想定外のディレクトリを削除しないように厳密に確認する
# 親 3 階層が work/.local/.claude であること、絶対パス前方一致で
# グローバル or リポジトリ配下のみ受理する
test_valid_session_path() {
  local path="$1"
  [[ -d "$path" ]] || return 1

  # 絶対パスに正規化 (相対パス・"." を含む経路をブロック)
  local resolved
  resolved="$(cd "$path" 2>/dev/null && pwd)" || return 1
  [[ -z "$resolved" ]] && return 1

  # 再解析ポイント拒否
  test_reparse "$resolved" && return 1

  local name="${resolved##*/}"
  [[ ! "$name" =~ $SESSION_REGEX ]] && return 1

  # 親 3 階層検証
  local parent grand great
  parent="$(dirname -- "$resolved")"
  [[ "${parent##*/}" != "work" ]] && return 1
  test_reparse "$parent" && return 1

  grand="$(dirname -- "$parent")"
  [[ "${grand##*/}" != ".local" ]] && return 1
  test_reparse "$grand" && return 1

  great="$(dirname -- "$grand")"
  [[ "${great##*/}" != ".claude" ]] && return 1
  test_reparse "$great" && return 1

  # 絶対パス前方一致検証 (case-insensitive)
  local global_root global_resolved
  global_root="$home_dir/.claude/.local/work"
  global_resolved="$(cd "$global_root" 2>/dev/null && pwd)" || global_resolved="$global_root"

  local lower_resolved="${resolved,,}"
  local lower_global="${global_resolved,,}"
  local is_global=0
  if [[ "$lower_resolved" == "$lower_global"/* ]]; then
    is_global=1
  fi

  local is_project=0
  local repo_root expected_project expected_resolved
  if repo_root="$(git rev-parse --show-toplevel 2>/dev/null)" && [[ -n "$repo_root" ]]; then
    expected_project="$repo_root/.claude/.local/work"
    expected_resolved="$(cd "$expected_project" 2>/dev/null && pwd)" || expected_resolved="$expected_project"
    local lower_expected="${expected_resolved,,}"
    if [[ "$lower_resolved" == "$lower_expected"/* ]]; then
      is_project=1
    fi
  fi

  if [[ "$is_global" -eq 0 && "$is_project" -eq 0 ]]; then
    return 1
  fi
  return 0
}

# --- 対象ルート列挙 ---
declare -a root_scopes=()
declare -a root_paths=()

if [[ "$scope" == "global" || "$scope" == "both" ]]; then
  global_root="$home_dir/.claude/.local/work"
  if [[ -d "$global_root" ]]; then
    resolved_global="$(cd "$global_root" 2>/dev/null && pwd)"
    if [[ -n "$resolved_global" ]]; then
      root_scopes+=("global")
      root_paths+=("$resolved_global")
    fi
  fi
fi

if [[ "$scope" == "project" || "$scope" == "both" ]]; then
  repo_root=""
  if r="$(git rev-parse --show-toplevel 2>/dev/null)" && [[ -n "$r" ]]; then
    repo_root="$r"
  else
    repo_root="$(pwd)"
  fi

  project_root="$repo_root/.claude/.local/work"
  if [[ -d "$project_root" ]]; then
    resolved_project="$(cd "$project_root" 2>/dev/null && pwd)"
    if [[ -n "$resolved_project" ]]; then
      # 重複チェック
      duplicate=0
      for existing in "${root_paths[@]:-}"; do
        if [[ "$existing" == "$resolved_project" ]]; then duplicate=1; break; fi
      done
      if [[ "$duplicate" -eq 0 ]]; then
        root_scopes+=("project")
        root_paths+=("$resolved_project")
      fi
    fi
  fi
fi

if [[ ${#root_paths[@]} -eq 0 ]]; then
  printf '対象ルートが見つかりませんでした (スコープ: %s)。\n' "$scope"
  exit 0
fi

# --- セッション列挙 + 古さ判定 + 進行中保護 ---
# 時刻は UTC エポック秒で計算 (Linux/Git Bash の date は %s で UTC エポック秒を返す)
now_epoch="$(date -u +%s)"
threshold_epoch=$(( now_epoch - days * 86400 ))
active_threshold_epoch=$(( now_epoch - active_session_minutes * 60 ))

# 候補配列 (TAB 区切り: scope<TAB>path<TAB>name<TAB>lastwrite_epoch<TAB>size_bytes)
declare -a candidates=()
protected_active=0

# stat -c %Y は Linux GNU 形式、stat -f %m は BSD/macOS 形式
get_mtime_epoch() {
  local target="$1"
  if [[ ! -e "$target" ]]; then echo "0"; return; fi
  if stat -c %Y "$target" >/dev/null 2>&1; then
    stat -c %Y "$target"
  elif stat -f %m "$target" >/dev/null 2>&1; then
    stat -f %m "$target"
  else
    echo "0"
  fi
}

for idx in "${!root_paths[@]}"; do
  root_scope="${root_scopes[$idx]}"
  root_path="${root_paths[$idx]}"

  # 直下のディレクトリを列挙
  while IFS= read -r -d '' session_path; do
    if ! test_valid_session_path "$session_path"; then continue; fi
    test_reparse "$session_path" && continue

    name="${session_path##*/}"

    # 配下のファイル列挙 (隠しファイル含む、reparse 除外)
    size=0
    max_mtime=0
    while IFS= read -r -d '' f; do
      if test_reparse "$f"; then continue; fi
      # size 加算
      if [[ -f "$f" ]]; then
        s="$(stat -c %s "$f" 2>/dev/null || stat -f %z "$f" 2>/dev/null || echo 0)"
        size=$(( size + s ))
        m="$(get_mtime_epoch "$f")"
        if (( m > max_mtime )); then max_mtime="$m"; fi
      fi
    done < <(find "$session_path" -mindepth 1 -type f -print0 2>/dev/null)

    # atime 戦略 (progress.md > フォールバック)
    progress_path="$session_path/progress.md"
    if [[ -f "$progress_path" ]]; then
      last_access="$(get_mtime_epoch "$progress_path")"
      if (( last_access > active_threshold_epoch )); then
        protected_active=$(( protected_active + 1 ))
        continue
      fi
    else
      session_mtime="$(get_mtime_epoch "$session_path")"
      last_access="$session_mtime"
      if (( max_mtime > last_access )); then last_access="$max_mtime"; fi
    fi

    # 古さ判定
    if (( last_access >= threshold_epoch )); then continue; fi

    candidates+=("$root_scope"$'\t'"$session_path"$'\t'"$name"$'\t'"$last_access"$'\t'"$size")
  done < <(find "$root_path" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
done

# --- keep-recent 適用 (scope 別) ---
protected_keep_recent=0
if (( keep_recent > 0 )); then
  declare -a filtered=()
  for keep_scope in global project; do
    # scope 別に集めて last_access 降順ソート、先頭 keep_recent 件を保護
    declare -a scope_lines=()
    for line in "${candidates[@]:-}"; do
      [[ -z "$line" ]] && continue
      sc="${line%%$'\t'*}"
      if [[ "$sc" == "$keep_scope" ]]; then
        scope_lines+=("$line")
      fi
    done
    # last_access 降順ソート
    if [[ ${#scope_lines[@]} -gt 0 ]]; then
      sorted=$(printf '%s\n' "${scope_lines[@]}" | awk -F'\t' '{print $4"\t"$0}' | sort -t $'\t' -k1 -n -r | cut -f2-)
      counter=0
      while IFS= read -r srt_line; do
        [[ -z "$srt_line" ]] && continue
        if (( counter < keep_recent )); then
          protected_keep_recent=$(( protected_keep_recent + 1 ))
        else
          filtered+=("$srt_line")
        fi
        counter=$(( counter + 1 ))
      done <<< "$sorted"
    fi
  done
  candidates=("${filtered[@]:-}")
fi

# --- 候補表示 ---
total_bytes=0
for line in "${candidates[@]:-}"; do
  [[ -z "$line" ]] && continue
  s="$(printf '%s' "$line" | awk -F'\t' '{print $5}')"
  total_bytes=$(( total_bytes + s ))
done
total_mb="$(awk -v b="$total_bytes" 'BEGIN { v = b / 1048576; r = sprintf("%.2f", v); sub(/0+$/, "", r); sub(/\.$/, "", r); if (r == "" || r == "-") r = "0"; print r }')"

# candidates 件数の実数 (空エントリ除外)
candidate_count=0
for line in "${candidates[@]:-}"; do
  [[ -z "$line" ]] && continue
  candidate_count=$(( candidate_count + 1 ))
done

printf '\n'
printf '===== クリーンアップ候補 =====\n'
printf 'スコープ:           %s\n' "$scope"
printf '閾値日数:           %s 日\n' "$days"
printf 'keep-recent:        %s 件\n' "$keep_recent"
printf '候補件数:           %s 件\n' "$candidate_count"
printf '合計容量:           %s MB\n' "$total_mb"
printf '保護されたセッション:\n'
printf '  - 進行中:        %s 件\n' "$protected_active"
printf '  - keep-recent:   %s 件\n' "$protected_keep_recent"

if (( candidate_count > 0 )); then
  printf '\n'
  printf '削除対象一覧:\n'
  for line in "${candidates[@]:-}"; do
    [[ -z "$line" ]] && continue
    sc="$(printf '%s' "$line" | awk -F'\t' '{print $1}')"
    pth="$(printf '%s' "$line" | awk -F'\t' '{print $2}')"
    la="$(printf '%s' "$line" | awk -F'\t' '{print $4}')"
    sz="$(printf '%s' "$line" | awk -F'\t' '{print $5}')"
    mb="$(awk -v b="$sz" 'BEGIN { v = b / 1048576; r = sprintf("%.2f", v); sub(/0+$/, "", r); sub(/\.$/, "", r); if (r == "" || r == "-") r = "0"; print r }')"
    # 表示用にローカルタイムへ変換 (PowerShell 版: ToLocalTime + yyyy-MM-dd HH:mm)
    if mtime_local="$(date -d "@$la" '+%Y-%m-%d %H:%M' 2>/dev/null)"; then
      :
    elif mtime_local="$(date -r "$la" '+%Y-%m-%d %H:%M' 2>/dev/null)"; then
      :
    else
      mtime_local="$la"
    fi
    printf '  [%s] %s\n' "$sc" "$pth"
    printf '        size=%s MB, mtime=%s\n' "$mb" "$mtime_local"
  done
fi

# --- DryRun ---
if [[ "$dry_run" -eq 1 ]]; then
  printf '\n'
  printf '(dry-run) 実削除は行いません。\n'
  exit 0
fi

# --- 確認後フラグ (-Yes) でない場合 ---
if [[ "$yes" -ne 1 ]]; then
  printf '\n'
  printf '実削除を行うには -Yes フラグを付けて再実行してください (AskUserQuestion 経由推奨)。\n'
  exit 0
fi

# --- 削除実行 ---
if (( candidate_count == 0 )); then
  printf '\n'
  printf '削除対象がありません。\n'
  exit 0
fi

deleted=0
declare -a failed=()
freed_bytes=0

for line in "${candidates[@]:-}"; do
  [[ -z "$line" ]] && continue
  pth="$(printf '%s' "$line" | awk -F'\t' '{print $2}')"
  sz="$(printf '%s' "$line" | awk -F'\t' '{print $5}')"

  # 二重バリデーション (直前に再確認)
  if ! test_valid_session_path "$pth"; then
    failed+=("$pth"$'\t'"バリデーション失敗 (再確認時)")
    continue
  fi

  if rm -rf -- "$pth" 2>/dev/null; then
    deleted=$(( deleted + 1 ))
    freed_bytes=$(( freed_bytes + sz ))
  else
    failed+=("$pth"$'\t'"削除失敗")
  fi
done

# --- IncludeTmp の追加処理 ---
tmp_cleared=0
if [[ "$include_tmp" -eq 1 ]]; then
  for idx in "${!root_paths[@]}"; do
    root_path="${root_paths[$idx]}"
    while IFS= read -r -d '' sess; do
      if ! test_valid_session_path "$sess"; then continue; fi
      tmp_path="$sess/workspace/tmp"
      if [[ -d "$tmp_path" ]]; then
        # tmp 配下のエントリを 1 つずつ削除
        if find "$tmp_path" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + 2>/dev/null; then
          tmp_cleared=$(( tmp_cleared + 1 ))
        fi
      fi
    done < <(find "$root_path" -mindepth 1 -maxdepth 1 -type d -print0 2>/dev/null)
  done
fi

# --- サマリ ---
freed_mb="$(awk -v b="$freed_bytes" 'BEGIN { v = b / 1048576; r = sprintf("%.2f", v); sub(/0+$/, "", r); sub(/\.$/, "", r); if (r == "" || r == "-") r = "0"; print r }')"

printf '\n'
printf '===== 削除結果 =====\n'
printf '削除完了:           %s 件\n' "$deleted"
printf '削除失敗:           %s 件\n' "${#failed[@]}"
printf '解放容量:           %s MB\n' "$freed_mb"
if [[ "$include_tmp" -eq 1 ]]; then
  printf 'tmp/ 掃除済み:      %s セッション\n' "$tmp_cleared"
fi

if [[ ${#failed[@]} -gt 0 ]]; then
  printf '\n'
  printf '失敗一覧:\n'
  for f_line in "${failed[@]}"; do
    pth="${f_line%%$'\t'*}"
    err="${f_line##*$'\t'}"
    printf '  FAILED: %s\n' "$pth"
    printf '          %s\n' "$err"
  done
  exit 2
fi

exit 0
