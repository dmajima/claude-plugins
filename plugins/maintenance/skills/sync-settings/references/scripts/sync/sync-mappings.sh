#!/usr/bin/env bash
# sync-mappings.sh - sync 対象マッピング管理 (Bash + jq CRUD)
#
# 通常運用は本スクリプトを利用する。
# PowerShell フォールバック: sync-mappings.ps1 (機能等価、歴史的経緯で保持)
#
# 引数:
#   -Action <get|set|delete|list|show>  必須
#   -Scope <global|project>             get/set/delete で必須
#   -ProjectPath <path>                 project スコープ時の対象パス (省略時は git toplevel or cwd)
#   -Repo <url>                         set 時の Git URL
#   -Branch <name>                      set 時の Branch (既定: main)
#   -Targets <csv>                      set 時の同期対象 (省略時はデフォルト)
#   -Force                              delete 時の確認スキップ

set -uo pipefail

script_dir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# 共通ライブラリの読み込み (SSOT)
# shellcheck source=sync-common.sh
source "$script_dir/sync-common.sh"

command -v jq >/dev/null 2>&1 || { printf '[sync-mappings] jq required\n' >&2; exit 1; }

# --- 引数解析 ---
action=""
scope=""
project_path=""
repo=""
branch="main"
targets_csv=""
force=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -Action|--action)             action="${2:-}"; shift 2 ;;
    -Scope|--scope)               scope="${2:-}"; shift 2 ;;
    -ProjectPath|--project-path)  project_path="${2:-}"; shift 2 ;;
    -Repo|--repo)                 repo="${2:-}"; shift 2 ;;
    -Branch|--branch)             branch="${2:-}"; shift 2 ;;
    -Targets|--targets)           targets_csv="${2:-}"; shift 2 ;;
    -Force|--force)               force=1; shift ;;
    *) shift ;;
  esac
done

if [[ -z "$action" ]]; then
  printf -- '-Action が必須です（get|set|delete|list|show）\n' >&2
  exit 1
fi
case "$action" in
  get|set|delete|list|show) ;;
  *) printf '-Action が無効です: %s\n' "$action" >&2; exit 1 ;;
esac
if [[ -n "$scope" ]]; then
  case "$scope" in
    global|project) ;;
    *) printf '-Scope が無効です: %s (global|project)\n' "$scope" >&2; exit 1 ;;
  esac
fi

# --- 定数 ---
home_dir="${USERPROFILE:-${HOME:-}}"
if command -v cygpath >/dev/null 2>&1 && [[ "$home_dir" == *":"* ]]; then
  home_dir="$(cygpath -u -- "$home_dir")"
fi
CONFIG_DIR="$home_dir/.claude/.local/plugins/maintenance"
CONFIG_FILE="$CONFIG_DIR/sync-mappings.json"

# PowerShell 版 (sync.ps1 / sync-push.ps1) と同じ既定 targets
DEFAULT_GLOBAL_TARGETS='["settings.json","skills","rules","agents","hooks","CLAUDE.md"]'
DEFAULT_PROJECT_TARGETS='[".claude/settings.json",".claude/skills",".claude/rules",".claude/agents",".claude/hooks",".claude/CLAUDE.md"]'

# --- ヘルパー関数 ---

# get_mappings_store: 既存ストア (JSON 文字列) を stdout に出力。
# 不在時は空のスケルトンを返す。
get_mappings_store() {
  if [[ ! -f "$CONFIG_FILE" ]]; then
    printf '{"version":2,"global":null,"projects":{}}'
    return
  fi
  local loaded
  if ! loaded="$(jq -e . "$CONFIG_FILE" 2>/dev/null)"; then
    printf 'sync-mappings.json のパース失敗\n' >&2
    printf '空のストアを返します。修正後に再保存してください。\n' >&2
    printf '{"version":2,"global":null,"projects":{}}'
    return
  fi
  # 不足フィールドの補完 (version=2 / global=null / projects={})
  printf '%s' "$loaded" | jq '
    (.version // 2) as $v
    | (.global // null) as $g
    | (.projects // {}) as $p
    | {version: $v, global: $g, projects: $p}
  '
}

# save_mappings_store: $1 (JSON 文字列) を CONFIG_FILE に書き出す
save_mappings_store() {
  local store="$1"
  if ! mkdir -p -- "$CONFIG_DIR" 2>/dev/null; then
    printf 'sync-mappings.json の保存に失敗しました: ディレクトリ作成失敗\n' >&2
    exit 1
  fi
  if ! printf '%s' "$store" | jq . > "$CONFIG_FILE" 2>/dev/null; then
    printf 'sync-mappings.json の保存に失敗しました\n' >&2
    exit 1
  fi
}

# resolve_project_path: ProjectPath を絶対パス (Windows 形式) に解決
resolve_project_path() {
  local path="$1"
  if [[ -n "$path" ]]; then
    local abs
    abs="$(cd "$path" 2>/dev/null && pwd)" || {
      printf 'ProjectPath が無効です（解決失敗）: %s\n' "$path" >&2
      exit 1
    }
    # Windows 形式 (バックスラッシュ) に変換 (PowerShell 版と等価)
    if command -v cygpath >/dev/null 2>&1; then
      cygpath -w -- "$abs" 2>/dev/null || printf '%s' "$abs"
    else
      printf '%s' "$abs"
    fi
    return
  fi
  # カレントの git toplevel を取得
  local tmp
  if tmp="$(git rev-parse --show-toplevel 2>/dev/null)" && [[ -n "$tmp" ]]; then
    if command -v cygpath >/dev/null 2>&1; then
      cygpath -w -- "$tmp" 2>/dev/null || printf '%s' "$tmp"
    else
      printf '%s' "$tmp"
    fi
    return
  fi
  local cwd
  cwd="$(pwd)"
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -w -- "$cwd" 2>/dev/null || printf '%s' "$cwd"
  else
    printf '%s' "$cwd"
  fi
}

# test_non_auth_directory_path: 認証ディレクトリの登録を拒否
# 引数: <resolved_path>  戻り値: 0=safe, 1=blocked
test_non_auth_directory_path() {
  local resolved="$1"
  [[ -z "$resolved" ]] && return 1
  local home_resolved="$home_dir"
  if command -v cygpath >/dev/null 2>&1; then
    home_resolved="$(cygpath -w -- "$home_dir" 2>/dev/null || printf '%s' "$home_dir")"
  fi
  # 認証ディレクトリ名
  local lower_resolved="${resolved,,}"
  local blocked_name lower_blocked
  for blocked_name in '.ssh' '.gnupg' '.aws' '.docker' '.kube'; do
    lower_blocked="$(printf '%s\\%s' "$home_resolved" "$blocked_name" | tr '[:upper:]' '[:lower:]')"
    if [[ "$lower_resolved" == "$lower_blocked" || "$lower_resolved" == "$lower_blocked"\\* ]]; then
      return 1
    fi
  done
  # ~/.config/gh
  lower_blocked="$(printf '%s\\.config\\gh' "$home_resolved" | tr '[:upper:]' '[:lower:]')"
  if [[ "$lower_resolved" == "$lower_blocked" || "$lower_resolved" == "$lower_blocked"\\* ]]; then
    return 1
  fi
  return 0
}

# format_mapping: Mapping を整形して表示
# 引数: <title> <mapping_json>
format_mapping() {
  local title="$1" mapping="$2"
  if [[ -z "$mapping" || "$mapping" == "null" ]]; then
    printf '  %s: (未設定)\n' "$title"
    return
  fi
  printf '  %s:\n' "$title"
  local rr rb tg lsa
  rr="$(printf '%s' "$mapping" | jq -r '.remote_repo // ""')"
  rb="$(printf '%s' "$mapping" | jq -r '.remote_branch // ""')"
  printf '    remote_repo:   %s\n' "$(hide_secrets "$rr")"
  printf '    remote_branch: %s\n' "$rb"
  if [[ "$(printf '%s' "$mapping" | jq -r '.targets // empty | length')" != "" ]]; then
    tg="$(printf '%s' "$mapping" | jq -r '.targets | join(", ")')"
    if [[ -z "$tg" ]]; then tg='(空)'; fi
    printf '    targets:       %s\n' "$tg"
  else
    printf '    targets:       (空)\n'
  fi
  lsa="$(printf '%s' "$mapping" | jq -r '.last_sync_at // empty')"
  if [[ -n "$lsa" && "$lsa" != "null" ]]; then
    printf '    last_sync_at:  %s\n' "$lsa"
  fi
}

# convert_targets_csv: "a,b,c" を JSON 配列に変換
convert_targets_csv() {
  local csv="$1"
  if [[ -z "$csv" ]]; then
    printf '[]'
    return
  fi
  printf '%s' "$csv" | jq -R 'split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(. != ""))'
}

# --- アクション実装 ---
store="$(get_mappings_store)"

case "$action" in
  show)
    printf '===== sync-settings マッピング =====\n'
    printf 'Config file: %s\n' "$CONFIG_FILE"
    if [[ -f "$CONFIG_FILE" ]]; then
      printf 'Exists:      True\n'
    else
      printf 'Exists:      False\n'
    fi
    printf 'version:     %s\n' "$(printf '%s' "$store" | jq -r '.version')"
    printf '\n'
    g="$(printf '%s' "$store" | jq -c '.global')"
    format_mapping 'global' "$g"
    printf '\n'
    project_count="$(printf '%s' "$store" | jq -r '.projects | length')"
    if [[ "$project_count" == "0" ]]; then
      printf '  projects: (未設定)\n'
    else
      printf '  projects:\n'
      while IFS= read -r project_key; do
        [[ -z "$project_key" ]] && continue
        printf '    [%s]\n' "$project_key"
        pm="$(printf '%s' "$store" | jq -c --arg k "$project_key" '.projects[$k]')"
        format_mapping '       ' "$pm"
      done < <(printf '%s' "$store" | jq -r '.projects | keys[]')
    fi
    exit 0
    ;;

  list)
    printf '===== マッピング一覧 =====\n'
    count=0
    g="$(printf '%s' "$store" | jq -c '.global')"
    if [[ -n "$g" && "$g" != "null" ]]; then
      rr="$(printf '%s' "$g" | jq -r '.remote_repo // ""')"
      rb="$(printf '%s' "$g" | jq -r '.remote_branch // ""')"
      printf '  [global] %s (branch=%s)\n' "$(hide_secrets "$rr")" "$rb"
      count=$(( count + 1 ))
    fi
    while IFS= read -r project_key; do
      [[ -z "$project_key" ]] && continue
      pm="$(printf '%s' "$store" | jq -c --arg k "$project_key" '.projects[$k]')"
      rr="$(printf '%s' "$pm" | jq -r '.remote_repo // ""')"
      rb="$(printf '%s' "$pm" | jq -r '.remote_branch // ""')"
      printf '  [project: %s] %s (branch=%s)\n' "$project_key" "$(hide_secrets "$rr")" "$rb"
      count=$(( count + 1 ))
    done < <(printf '%s' "$store" | jq -r '.projects | keys[]')
    if [[ "$count" -eq 0 ]]; then
      printf '  (マッピングなし)\n'
    fi
    printf '\n'
    printf '件数: %s 件\n' "$count"
    exit 0
    ;;

  get)
    if [[ -z "$scope" ]]; then
      printf -- '-Scope が必須です（global または project）。\n' >&2
      exit 1
    fi
    if [[ "$scope" == "global" ]]; then
      g="$(printf '%s' "$store" | jq -c '.global')"
      if [[ -z "$g" || "$g" == "null" ]]; then
        printf '(global マッピング未設定)\n'
        exit 0
      fi
      format_mapping 'global' "$g"
      exit 0
    fi
    # project
    proj_path="$(resolve_project_path "$project_path")"
    has_proj="$(printf '%s' "$store" | jq -r --arg k "$proj_path" '.projects | has($k)')"
    if [[ "$has_proj" != "true" ]]; then
      printf '(project マッピング未設定: %s)\n' "$proj_path"
      exit 0
    fi
    pm="$(printf '%s' "$store" | jq -c --arg k "$proj_path" '.projects[$k]')"
    format_mapping "project: $proj_path" "$pm"
    exit 0
    ;;

  set)
    if [[ -z "$scope" ]]; then
      printf -- '-Scope が必須です（global または project）。\n' >&2
      exit 1
    fi
    if [[ -z "$repo" ]]; then
      printf -- '-Repo が必須です（Git リモートリポジトリ URL）。\n' >&2
      exit 1
    fi
    if ! test_repo_url_safe "$repo"; then
      # repo に認証情報が埋まっている場合に備えてマスク
      printf 'Repo URL の形式が無効です（https/http/git/ssh/git@host: のみ許可、'\''-'\'' 始まり / NUL バイト禁止）: %s\n' "$(hide_secrets "$repo")" >&2
      exit 1
    fi
    if ! test_branch_name_safe "$branch"; then
      printf 'Branch 名に無効な文字が含まれています（'\''..'\'' / '\''/'\'' 始まり・終わり / '\''-'\'' 始まり禁止）: %s\n' "$branch" >&2
      exit 1
    fi

    targets_json="$(convert_targets_csv "$targets_csv")"
    if [[ "$(printf '%s' "$targets_json" | jq 'length')" == "0" ]]; then
      if [[ "$scope" == "global" ]]; then
        targets_json="$DEFAULT_GLOBAL_TARGETS"
      else
        targets_json="$DEFAULT_PROJECT_TARGETS"
      fi
    fi
    # targets の各要素を Test-TargetExcluded で検証
    while IFS= read -r t; do
      [[ -z "$t" ]] && continue
      if test_target_excluded "$t"; then
        printf 'targets に除外対象が含まれています（パストラバーサル / 認証情報 / NUL バイト等）: %s\n' "$t" >&2
        exit 1
      fi
    done < <(printf '%s' "$targets_json" | jq -r '.[]')

    mapping_json="$(jq -n --arg r "$repo" --arg b "$branch" --argjson t "$targets_json" \
      '{remote_repo: $r, remote_branch: $b, targets: $t, last_sync_at: null}')"

    if [[ "$scope" == "global" ]]; then
      updated_store="$(printf '%s' "$store" | jq --argjson m "$mapping_json" '.global = $m')"
      printf '[updated] global マッピングを保存しました\n'
    else
      proj_path="$(resolve_project_path "$project_path")"
      if ! test_non_auth_directory_path "$proj_path"; then
        printf 'ProjectPath には認証ディレクトリ（~/.ssh / ~/.gnupg / ~/.aws / ~/.docker / ~/.kube / ~/.config/gh 等）配下を指定できません: %s\n' "$proj_path" >&2
        exit 1
      fi
      updated_store="$(printf '%s' "$store" | jq --arg k "$proj_path" --argjson m "$mapping_json" '.projects[$k] = $m')"
      printf '[updated] project マッピングを保存しました: %s\n' "$proj_path"
    fi

    save_mappings_store "$updated_store"
    printf '\n'
    format_mapping "$scope" "$mapping_json"
    exit 0
    ;;

  delete)
    if [[ -z "$scope" ]]; then
      printf -- '-Scope が必須です（global または project）。\n' >&2
      exit 1
    fi
    if [[ "$force" -ne 1 ]]; then
      printf '削除は破壊的です。-Force フラグを併用してください（呼び出し側で AskUserQuestion 確認後に実行）。\n' >&2
      exit 1
    fi
    if [[ "$scope" == "global" ]]; then
      g="$(printf '%s' "$store" | jq -c '.global')"
      if [[ -z "$g" || "$g" == "null" ]]; then
        printf '(global マッピングは元々未設定でした)\n'
        exit 0
      fi
      updated_store="$(printf '%s' "$store" | jq '.global = null')"
      save_mappings_store "$updated_store"
      printf '[deleted] global マッピングを削除しました\n'
      exit 0
    fi
    # project
    proj_path="$(resolve_project_path "$project_path")"
    has_proj="$(printf '%s' "$store" | jq -r --arg k "$proj_path" '.projects | has($k)')"
    if [[ "$has_proj" != "true" ]]; then
      printf '(project マッピングは元々未設定でした: %s)\n' "$proj_path"
      exit 0
    fi
    updated_store="$(printf '%s' "$store" | jq --arg k "$proj_path" 'del(.projects[$k])')"
    save_mappings_store "$updated_store"
    printf '[deleted] project マッピングを削除しました: %s\n' "$proj_path"
    exit 0
    ;;
esac
