#!/usr/bin/env bash
# sync.sh - Claude Code 設定の Git 経由同期 (pull, Bash + jq + git 純粋実装)
#
# 通常運用は本スクリプトを利用する。
# PowerShell フォールバック: sync.ps1 (機能等価、歴史的経緯で保持)
#
# 処理の流れ:
#   1. Mapping 解決 (sync-mappings.json)
#   2. Repo URL / Branch バリデーション
#   3. Git clone or fetch+reset
#   4. 同期対象の存在確認 (パストラバーサル防御)
#   5. SHA-256 比較で ADD/MOD/DEL 検出
#   6. (EmitDiffJson モードはここで終了)
#   7. DryRun ならここで終了
#   8. バックアップ取得
#   9. overwrite / merge / skip 戦略で適用
#  10. sync-mappings.json と sync-config.json (互換) を更新

set -uo pipefail

script_dir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# 共通ライブラリ (SSOT) を読み込み
# shellcheck source=sync-common.sh
source "$script_dir/sync-common.sh"

command -v jq >/dev/null 2>&1 || { printf '[sync] jq required\n' >&2; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { printf '[sync] sha256sum required\n' >&2; exit 1; }

# --- 引数解析 ---
mapping_arg=""
project_path=""
repo=""
branch=""
branch_explicit=0
declare -a targets=()
strategy="overwrite"
dry_run=0
no_backup=0
prune=0
yes=0
emit_diff_json=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -Mapping|--mapping)       mapping_arg="${2:-}"; shift 2 ;;
    -ProjectPath|--project-path) project_path="${2:-}"; shift 2 ;;
    -Repo|--repo)             repo="${2:-}"; shift 2 ;;
    -Branch|--branch)         branch="${2:-}"; branch_explicit=1; shift 2 ;;
    -Targets|--targets)       IFS=',' read -r -a targets <<< "${2:-}"; shift 2 ;;
    -Strategy|--strategy)     strategy="${2:-}"; shift 2 ;;
    -DryRun|--dry-run)        dry_run=1; shift ;;
    -NoBackup|--no-backup)    no_backup=1; shift ;;
    -Prune|--prune)           prune=1; shift ;;
    -Yes|--yes)               yes=1; shift ;;
    -EmitDiffJson|--emit-diff-json) emit_diff_json="${2:-}"; shift 2 ;;
    *) shift ;;
  esac
done

# branch が空ならデフォルト main
if [[ -z "$branch" ]]; then
  branch="main"
fi
case "$strategy" in
  overwrite|merge|skip) ;;
  *) printf '-Strategy が無効です: %s (overwrite|merge|skip)\n' "$strategy" >&2; exit 1 ;;
esac
case "$mapping_arg" in
  ''|global|project) ;;
  *) printf '-Mapping が無効です: %s (global|project)\n' "$mapping_arg" >&2; exit 1 ;;
esac

# --- 定数 ---
home_dir="${USERPROFILE:-${HOME:-}}"
if command -v cygpath >/dev/null 2>&1 && [[ "$home_dir" == *":"* ]]; then
  home_dir="$(cygpath -u -- "$home_dir")"
fi
BASE_DIR="$home_dir/.claude/.local/plugins/maintenance"
CONFIG_FILE="$BASE_DIR/sync-config.json"
MAPPINGS_FILE="$BASE_DIR/sync-mappings.json"
REPO_DIR="$BASE_DIR/repo"
BACKUP_ROOT="$BASE_DIR/backup"
CLAUDE_HOME="$home_dir/.claude"

DEFAULT_TARGETS=('settings.json' 'skills' 'rules' 'agents' 'hooks' 'CLAUDE.md')

# settings.json マージ時にローカル優先で温存する危険キー
MERGE_LOCAL_PRIORITY_KEYS=(
  'hooks' 'mcpServers' 'env' 'permissions'
  'extraKnownMarketplaces' 'apiKeyHelper' 'customApiKeyResponses'
  'awsAuthRefresh' 'awsCredentialExport'
  'enabledPlugins' 'disabledPlugins'
)

# --- Mapping 解決 ---
if [[ -n "$mapping_arg" ]]; then
  if [[ ! -f "$MAPPINGS_FILE" ]]; then
    printf 'Mapping '\''%s'\'' を解決するには sync-mappings.json が必要です。/sync-map-set で設定してください。\n' "$mapping_arg" >&2
    exit 1
  fi
  if ! mappings_store="$(jq -e . "$MAPPINGS_FILE" 2>/dev/null)"; then
    printf 'sync-mappings.json のパース失敗\n' >&2
    exit 1
  fi

  mapping_entry=""
  if [[ "$mapping_arg" == "global" ]]; then
    mapping_entry="$(printf '%s' "$mappings_store" | jq -c '.global // empty')"
  else
    # project: ProjectPath 指定 or git toplevel / cwd
    resolved_project="$project_path"
    if [[ -z "$resolved_project" ]]; then
      if tmp="$(git rev-parse --show-toplevel 2>/dev/null)" && [[ -n "$tmp" ]]; then
        resolved_project="$tmp"
      else
        resolved_project="$(pwd)"
      fi
    fi
    # Windows 形式 (バックスラッシュ) に変換 (sync-mappings.json のキーと整合)
    if [[ -e "$resolved_project" ]] && command -v cygpath >/dev/null 2>&1; then
      wpath="$(cygpath -w -- "$resolved_project" 2>/dev/null)" || wpath=""
      [[ -n "$wpath" ]] && resolved_project="$wpath"
    fi
    mapping_entry="$(printf '%s' "$mappings_store" | jq -c --arg k "$resolved_project" '.projects[$k] // empty')"
  fi

  if [[ -z "$mapping_entry" ]]; then
    printf 'Mapping '\''%s'\'' に対応するマッピングが sync-mappings.json に存在しません。/sync-map-set で設定してください。\n' "$mapping_arg" >&2
    exit 1
  fi

  # 引数未指定のフィールドのみ補完
  if [[ -z "$repo" ]]; then
    repo="$(printf '%s' "$mapping_entry" | jq -r '.remote_repo // empty')"
  fi
  if [[ "$branch_explicit" -eq 0 ]]; then
    mb="$(printf '%s' "$mapping_entry" | jq -r '.remote_branch // empty')"
    [[ -n "$mb" ]] && branch="$mb"
  fi
  if [[ ${#targets[@]} -eq 0 ]]; then
    while IFS= read -r t; do
      [[ -z "$t" ]] && continue
      targets+=("$t")
    done < <(printf '%s' "$mapping_entry" | jq -r '.targets[]?')
  fi

  printf '[mapping] '\''%s'\'' から取得: repo=%s, branch=%s, targets=%s 件\n' \
    "$mapping_arg" "$repo" "$branch" "${#targets[@]}"

  # マッピング由来値の再検証
  if ! test_repo_url_safe "$repo"; then
    printf 'マッピング由来の remote_repo が無効です（外部書き換え疑い）: %s\n' "$(hide_secrets "$repo")" >&2
    exit 1
  fi
  if ! test_branch_name_safe "$branch"; then
    printf 'マッピング由来の remote_branch が無効です（外部書き換え疑い）: %s\n' "$branch" >&2
    exit 1
  fi
fi

# --- 引数組み合わせ安全装置 ---
if [[ "$dry_run" -eq 1 && "$yes" -eq 1 ]]; then
  printf -- '--DryRun と --Yes を同時指定: --DryRun を優先（実適用は行いません）\n' >&2
  yes=0
fi

# --- ディレクトリ準備 ---
for d in "$BASE_DIR" "$BACKUP_ROOT"; do
  [[ ! -d "$d" ]] && mkdir -p -- "$d"
done

# --- 設定ファイル読み込み ---
config_store=""
if [[ -f "$CONFIG_FILE" ]]; then
  config_store="$(jq -e . "$CONFIG_FILE" 2>/dev/null)" || {
    printf 'sync-config.json のパース失敗\n' >&2
    config_store=""
  }
fi

if [[ -z "$repo" ]]; then
  if [[ -n "$config_store" ]]; then
    last_repo="$(printf '%s' "$config_store" | jq -r '.last_repo // empty')"
    if [[ -n "$last_repo" ]]; then
      repo="$last_repo"
      printf 'Repo を設定ファイルから取得: %s\n' "$repo"
      printf '[deprecated] sync-config.json 由来の last_repo を使用しました。v0.3.0 で sync-config.json は削除されます。/sync-map-set でマッピングを設定し、/sync-pull --scope <global|project> を利用してください。\n' >&2
    fi
  fi
  if [[ -z "$repo" ]]; then
    printf 'Repo 引数が必要です（--Repo または sync-config.json または --Mapping <scope> + /sync-map-set 経由のマッピング）\n' >&2
    exit 1
  fi
fi

if [[ ${#targets[@]} -eq 0 ]]; then
  if [[ -n "$config_store" ]]; then
    while IFS= read -r t; do
      [[ -z "$t" ]] && continue
      targets+=("$t")
    done < <(printf '%s' "$config_store" | jq -r '.last_targets[]? // empty')
  fi
  if [[ ${#targets[@]} -eq 0 ]]; then
    targets=("${DEFAULT_TARGETS[@]}")
  fi
fi

# 同期対象の除外検証
for t in "${targets[@]}"; do
  if test_target_excluded "$t"; then
    printf '同期対象に除外パスが含まれています: %s\n' "$t" >&2
    exit 1
  fi
done

# Repo URL バリデーション
if ! test_repo_url_safe "$repo"; then
  printf 'Repo URL の形式が無効です（https / http / git / ssh / git@host: のみ許可、'\''-'\'' 始まり / NUL バイト禁止）: %s\n' "$(hide_secrets "$repo")" >&2
  exit 1
fi
if ! test_branch_name_safe "$branch"; then
  printf 'Branch 名に無効な文字が含まれています（'\''..'\'' 含む / '\''/'\'' 始まり・終わり / '\''-'\'' 始まりは禁止）: %s\n' "$branch" >&2
  exit 1
fi

# Git CLI 確認
if ! command -v git >/dev/null 2>&1; then
  printf 'Git CLI が見つかりません。インストールしてください。\n' >&2
  exit 1
fi

# --- Git clone / reset ---
printf '\n'
printf '===== リポジトリ取得 =====\n'
printf 'Repo:   %s\n' "$repo"
printf 'Branch: %s\n' "$branch"

invoke_fresh_clone() {
  while IFS= read -r line; do
    write_masked_output "$line"
  done < <(git "${GIT_SAFE_OPTS[@]}" clone --depth 1 --branch "$branch" -- "$repo" "$REPO_DIR" 2>&1)
  if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
    printf 'Git clone 失敗: exit %s\n' "${PIPESTATUS[0]}" >&2
    exit 1
  fi
}

if [[ ! -d "$REPO_DIR" ]]; then
  invoke_fresh_clone
else
  # origin URL 確認
  current_origin="$(cd "$REPO_DIR" && git remote get-url origin 2>/dev/null || true)"
  if [[ -n "$current_origin" && "$current_origin" != "$repo" ]]; then
    printf '既存 repo/ の origin が期待値と異なります（期待: %s / 実際: %s）。再 clone を実施します。\n' \
      "$(hide_secrets "$repo")" "$(hide_secrets "$current_origin")" >&2
    rm -rf -- "$REPO_DIR" || { printf '既存 repo/ の削除失敗\n' >&2; exit 1; }
    invoke_fresh_clone
  else
    pushd "$REPO_DIR" >/dev/null
    while IFS= read -r line; do
      write_masked_output "$line"
    done < <(git "${GIT_SAFE_OPTS[@]}" fetch --depth 1 origin "$branch" 2>&1)
    if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
      printf 'Git fetch 失敗\n' >&2
      popd >/dev/null
      exit 1
    fi
    while IFS= read -r line; do
      write_masked_output "$line"
    done < <(git "${GIT_SAFE_OPTS[@]}" reset --hard "origin/$branch" 2>&1)
    if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
      printf 'Git reset 失敗\n' >&2
      popd >/dev/null
      exit 1
    fi
    git "${GIT_SAFE_OPTS[@]}" clean -fdx >/dev/null 2>&1 || true
    popd >/dev/null
  fi
fi

# 取得した commit SHA
commit_sha="$(cd "$REPO_DIR" && git rev-parse --short HEAD 2>/dev/null | tr -d '\n')"

# --- 同期対象の存在確認 (パストラバーサル防御) ---
repo_resolved="$(cd "$REPO_DIR" && pwd)"

find_remote_target() {
  local target="$1"
  local candidate cand resolved
  for candidate in "$target" "claude/$target"; do
    cand="$REPO_DIR/$candidate"
    [[ ! -e "$cand" ]] && continue
    resolved="$(cd "$(dirname -- "$cand")" 2>/dev/null && pwd)" || continue
    resolved="$resolved/$(basename -- "$cand")"
    # repo/ 配下から逸脱していないか前方一致検証
    if [[ "$resolved" != "$repo_resolved"/* && "$resolved" != "$repo_resolved" ]]; then
      continue
    fi
    printf '%s' "$resolved"
    return 0
  done
  return 1
}

declare -a resolved_target_names=()
declare -a resolved_target_remotes=()
declare -a resolved_target_locals=()
for t in "${targets[@]}"; do
  if remote="$(find_remote_target "$t")"; then
    resolved_target_names+=("$t")
    resolved_target_remotes+=("$remote")
    resolved_target_locals+=("$CLAUDE_HOME/$t")
  else
    printf '同期対象 %s がリポジトリに見つかりません。スキップします。\n' "$t" >&2
  fi
done

# --- 差分検出 ---
get_file_hash() {
  local p="$1"
  [[ ! -f "$p" ]] && return 1
  sha256sum -- "$p" 2>/dev/null | awk '{print $1}' | tr 'a-z' 'A-Z'
}

# diff_entries: 1 件 = JSON object {Op, Local, Remote, RelPath} を JSON Lines 形式で蓄積
diff_jsonl_file="$(mktemp)"
trap 'rm -f -- "$diff_jsonl_file"' EXIT

add_diff() {
  local op="$1" local_p="$2" remote_p="$3" rel="$4"
  jq -nc --arg op "$op" --arg l "$local_p" --arg r "$remote_p" --arg rp "$rel" \
    '{Op: $op, Local: $l, Remote: ($r | if . == "" then null else . end), RelPath: $rp}' \
    >> "$diff_jsonl_file"
}

for i in "${!resolved_target_names[@]}"; do
  name="${resolved_target_names[$i]}"
  remote="${resolved_target_remotes[$i]}"
  local_p="${resolved_target_locals[$i]}"

  if [[ -f "$remote" ]]; then
    # 単一ファイル
    if test_file_excluded "$name"; then
      printf '除外対象のためスキップ: %s\n' "$name" >&2
      continue
    fi
    if test_reparse_item "$remote"; then
      printf '再解析ポイントのためスキップ: %s\n' "$name" >&2
      continue
    fi
    remote_h="$(get_file_hash "$remote" || true)"
    local_h="$(get_file_hash "$local_p" 2>/dev/null || true)"
    if [[ ! -e "$local_p" ]]; then
      add_diff "ADD" "$local_p" "$remote" "$name"
    elif [[ "$remote_h" != "$local_h" ]]; then
      add_diff "MOD" "$local_p" "$remote" "$name"
    fi
  elif [[ -d "$remote" ]]; then
    # ディレクトリ: reparse 追従抑制の自前再帰
    while IFS= read -r -d '' f; do
      rel="${f#"$remote"}"
      rel="${rel#/}"
      rel="${rel#\\}"
      combined_rel="$name/$rel"
      if test_file_excluded "$combined_rel"; then continue; fi

      local_file="$local_p/$rel"
      remote_h="$(get_file_hash "$f" || true)"
      local_h="$(get_file_hash "$local_file" 2>/dev/null || true)"

      if [[ ! -e "$local_file" ]]; then
        add_diff "ADD" "$local_file" "$f" "$combined_rel"
      elif [[ "$remote_h" != "$local_h" ]]; then
        add_diff "MOD" "$local_file" "$f" "$combined_rel"
      fi
    done < <(get_non_reparse_file_items "$remote")

    if [[ "$prune" -eq 1 && "$strategy" == "overwrite" && -d "$local_p" ]]; then
      while IFS= read -r -d '' f; do
        rel="${f#"$local_p"}"
        rel="${rel#/}"
        rel="${rel#\\}"
        combined_rel="$name/$rel"
        if test_file_excluded "$combined_rel"; then continue; fi
        remote_file="$remote/$rel"
        if [[ ! -e "$remote_file" ]]; then
          add_diff "DEL" "$f" "" "$combined_rel"
        fi
      done < <(get_non_reparse_file_items "$local_p")
    fi
  fi
done

# 集計
add_count="$(grep -c '"Op":"ADD"' "$diff_jsonl_file" 2>/dev/null || true)"
mod_count="$(grep -c '"Op":"MOD"' "$diff_jsonl_file" 2>/dev/null || true)"
del_count="$(grep -c '"Op":"DEL"' "$diff_jsonl_file" 2>/dev/null || true)"
add_count="${add_count:-0}"
mod_count="${mod_count:-0}"
del_count="${del_count:-0}"
total_count=$(( add_count + mod_count + del_count ))

# --- 差分表示 ---
printf '\n'
printf '===== 差分検出 =====\n'
printf 'Strategy: %s\n' "$strategy"
printf '件数:     %s 件\n' "$total_count"
printf '  [ADD] %s 件\n' "$add_count"
printf '  [MOD] %s 件\n' "$mod_count"
if [[ "$prune" -eq 1 && "$strategy" == "overwrite" ]]; then
  printf '  [DEL] %s 件（--prune）\n' "$del_count"
fi

if (( total_count > 0 )); then
  printf '\n'
  while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    op="$(printf '%s' "$line" | jq -r '.Op')"
    rp="$(printf '%s' "$line" | jq -r '.RelPath')"
    printf '  [%s] %s\n' "$op" "$rp"
  done < "$diff_jsonl_file"
fi

# --- EmitDiffJson モード ---
if [[ -n "$emit_diff_json" ]]; then
  emit_dir="$(dirname -- "$emit_diff_json")"
  [[ -n "$emit_dir" && ! -d "$emit_dir" ]] && mkdir -p -- "$emit_dir"
  if [[ "$total_count" -eq 0 ]]; then
    printf '[]\n' > "$emit_diff_json"
  else
    # JSON Lines を JSON 配列に変換
    jq -s . "$diff_jsonl_file" > "$emit_diff_json"
  fi
  printf '\n'
  printf '[emit-diff-json] 差分一覧を JSON 出力しました: %s（%s 件）\n' "$emit_diff_json" "$total_count"
  exit 0
fi

# --- DryRun ---
if [[ "$dry_run" -eq 1 ]]; then
  printf '\n'
  printf '（dry-run）実適用は行いません。\n'
  exit 0
fi

if [[ "$yes" -ne 1 ]]; then
  printf '\n'
  printf '実適用するには -Yes フラグを付けて再実行してください（AskUserQuestion 経由推奨）。\n'
  exit 0
fi

# 差分ゼロ時の早期終了
if [[ "$total_count" -eq 0 ]]; then
  printf '\n'
  printf '差分がありません。同期処理をスキップします。\n'

  now_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

  # sync-mappings.json の last_sync_at 更新
  update_mapping_last_sync_at "$mapping_arg" "$project_path" "$MAPPINGS_FILE" "$now_iso"

  # sync-config.json (互換) 更新
  history_array="$(printf '%s' "${config_store:-{\}}" | jq '(.history // []) | .[:9]')"
  targets_json="$(printf '%s\n' "${targets[@]}" | jq -R . | jq -s .)"
  new_config="$(jq -n \
    --arg lr "$repo" --arg lb "$branch" --argjson lt "$targets_json" --arg ls "$strategy" \
    --arg lsa "$now_iso" --argjson h "$history_array" \
    '{version: 1, last_repo: $lr, last_branch: $lb, last_targets: $lt, last_strategy: $ls, last_sync_at: $lsa, history: $h}')"
  printf '%s\n' "$new_config" > "$CONFIG_FILE"
  exit 0
fi

# --- バックアップ取得 ---
backup_dir=""
if [[ "$no_backup" -ne 1 ]]; then
  ts="$(date -u +%Y%m%d_%H%M%S)"
  backup_dir="$BACKUP_ROOT/$ts"
  suffix=2
  while [[ -d "$backup_dir" ]]; do
    backup_dir="$BACKUP_ROOT/${ts}_${suffix}"
    suffix=$(( suffix + 1 ))
    if (( suffix > 100 )); then
      printf 'バックアップディレクトリの連番が 100 を超えました。古いバックアップを削除してください。\n' >&2
      exit 1
    fi
  done
  mkdir -p -- "$backup_dir"

  printf '\n'
  printf '===== バックアップ =====\n'
  printf 'Backup dir: %s\n' "$backup_dir"

  for t in "${targets[@]}"; do
    src="$CLAUDE_HOME/$t"
    [[ ! -e "$src" ]] && continue
    if [[ -f "$src" ]]; then
      if test_file_excluded "$t"; then
        printf 'バックアップ除外（target）: %s\n' "$t" >&2
        continue
      fi
      if test_reparse_item "$src"; then
        printf 'バックアップ除外（reparse point）: %s\n' "$t" >&2
        continue
      fi
      dst="$backup_dir/$t"
      dst_parent="$(dirname -- "$dst")"
      [[ ! -d "$dst_parent" ]] && mkdir -p -- "$dst_parent"
      cp -f -- "$src" "$dst"
    else
      # ディレクトリ
      while IFS= read -r -d '' f; do
        rel="${f#"$src"}"
        rel="${rel#/}"
        rel="${rel#\\}"
        combined_rel="$t/$rel"
        if test_file_excluded "$combined_rel"; then continue; fi
        dst="$backup_dir/$combined_rel"
        dst_parent="$(dirname -- "$dst")"
        [[ ! -d "$dst_parent" ]] && mkdir -p -- "$dst_parent"
        cp -f -- "$f" "$dst"
      done < <(get_non_reparse_file_items "$src")
    fi
  done
else
  printf -- '--NoBackup 指定: バックアップを取得しません。\n' >&2
fi

# --- settings.json 安全マージ ---
# PowerShell 版 Merge-JsonValue の挙動を Python で再現する。
# - サブオブジェクト同士は再帰深マージ
# - 配列はリモート値で完全置換 (トップレベル配列は警告)
# - トップレベルの危険キー (MERGE_LOCAL_PRIORITY_KEYS) はローカル優先で温存
# - Unicode 同形異字を含むキーはローカル不在なら採用せず無視、存在すれば温存
merge_keys_csv="$(printf '%s\n' "${MERGE_LOCAL_PRIORITY_KEYS[@]}" | paste -sd ',' -)"

merge_settings_json() {
  local local_path="$1" remote_path="$2"
  PROTECTED_KEYS_CSV="$merge_keys_csv" python3 - "$local_path" "$remote_path" <<'PY'
import json, os, re, sys

local_path, remote_path = sys.argv[1], sys.argv[2]
protected = set(os.environ.get("PROTECTED_KEYS_CSV", "").split(","))
ascii_only = re.compile(r"[^\x20-\x7e]")

def merge(local, remote, is_root):
    if local is None:
        return remote
    if remote is None:
        return local
    if isinstance(remote, list):
        if is_root:
            sys.stderr.write("警告: [merge:warning] settings.json のトップレベルが配列型です (標準では想定外)。リモート値で完全置換します。\n")
        return remote
    if not isinstance(remote, dict):
        return remote

    result = {}
    if isinstance(local, dict):
        for k, v in local.items():
            result[k] = v

    for k, v in remote.items():
        ascii_name = ascii_only.sub("", k)
        has_non_ascii = (k != ascii_name)
        if has_non_ascii and is_root:
            sys.stderr.write(f"警告: [merge:safety] settings.json のキー '{k}' に非 ASCII 文字が含まれています。Unicode 同形異字攻撃の可能性があるためローカル値を優先します。\n")
            # ローカルに同名キー不在: 採用しない / 存在: そのまま温存
            continue

        if is_root and ascii_name in protected:
            if k in result:
                sys.stderr.write(f"警告: [merge:safety] settings.json の '{k}' キーはローカルを保持します (リモート上書き禁止: 任意コード実行・認証情報差し替えリスク)\n")
            else:
                result[k] = v
                sys.stderr.write(f"警告: [merge:notice] settings.json の '{k}' キーはローカル不在のためリモート値を採用しました (次回以降は明示確認の上で更新してください)\n")
            continue

        if k in result and isinstance(result[k], dict) and isinstance(v, dict):
            result[k] = merge(result[k], v, False)
        else:
            result[k] = v
    return result

with open(local_path, "r", encoding="utf-8") as f:
    local = json.load(f)
with open(remote_path, "r", encoding="utf-8") as f:
    remote = json.load(f)

merged = merge(local, remote, True)
sys.stdout.write(json.dumps(merged, ensure_ascii=False, indent=2))
PY
}

# --- 同期適用 ---
printf '\n'
printf '===== 同期適用 =====\n'
applied=0
declare -a failed=()

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  op="$(printf '%s' "$line" | jq -r '.Op')"
  local_p="$(printf '%s' "$line" | jq -r '.Local')"
  remote_p="$(printf '%s' "$line" | jq -r '.Remote')"
  rel_p="$(printf '%s' "$line" | jq -r '.RelPath')"

  err=""
  skip_entry=0
  case "$op" in
    ADD)
      if [[ "$strategy" == "skip" && -e "$local_p" ]]; then skip_entry=1; fi
      if [[ "$skip_entry" -eq 0 ]]; then
        dst_parent="$(dirname -- "$local_p")"
        [[ ! -d "$dst_parent" ]] && mkdir -p -- "$dst_parent"
        if ! cp -f -- "$remote_p" "$local_p" 2>/tmp/sync_err.$$; then
          err="$(cat /tmp/sync_err.$$ 2>/dev/null || echo 'copy failed')"
        else
          applied=$(( applied + 1 ))
        fi
        rm -f /tmp/sync_err.$$ 2>/dev/null
      fi
      ;;
    MOD)
      if [[ "$strategy" == "skip" ]]; then skip_entry=1; fi
      if [[ "$skip_entry" -eq 0 ]]; then
        leaf="${rel_p##*/}"
        if [[ "$strategy" == "merge" && "$leaf" == "settings.json" ]]; then
          merged="$(merge_settings_json "$local_p" "$remote_p" 2>/tmp/sync_merge_err.$$)" || true
          merge_err="$(cat /tmp/sync_merge_err.$$ 2>/dev/null || true)"
          rm -f /tmp/sync_merge_err.$$ 2>/dev/null
          if [[ -n "$merge_err" ]]; then
            # python 経由の警告は stderr に転送済み
            printf '%s\n' "$merge_err" >&2
          fi
          if [[ -z "$merged" ]]; then
            err="settings.json マージ失敗"
          else
            printf '%s' "$merged" > "$local_p"
            applied=$(( applied + 1 ))
          fi
        else
          if ! cp -f -- "$remote_p" "$local_p" 2>/tmp/sync_err.$$; then
            err="$(cat /tmp/sync_err.$$ 2>/dev/null || echo 'copy failed')"
          else
            applied=$(( applied + 1 ))
          fi
          rm -f /tmp/sync_err.$$ 2>/dev/null
        fi
      fi
      ;;
    DEL)
      if [[ "$strategy" != "overwrite" || "$prune" -ne 1 ]]; then
        skip_entry=1
      fi
      if [[ "$skip_entry" -eq 0 ]]; then
        if ! rm -f -- "$local_p" 2>/tmp/sync_err.$$; then
          err="$(cat /tmp/sync_err.$$ 2>/dev/null || echo 'delete failed')"
        else
          applied=$(( applied + 1 ))
        fi
        rm -f /tmp/sync_err.$$ 2>/dev/null
      fi
      ;;
  esac

  if [[ -n "$err" ]]; then
    failed+=("$rel_p"$'\t'"$op"$'\t'"$err")
  fi
done < "$diff_jsonl_file"

# --- 設定保存 ---
sync_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
history_entry="$(jq -n --arg s "$sync_at" --arg r "$repo" --arg b "$branch" --arg st "$strategy" \
  --arg c "$commit_sha" --argjson a "$applied" --argjson f "${#failed[@]}" \
  '{sync_at: $s, repo: $r, branch: $b, strategy: $st, commit: $c, applied: $a, failed: $f}')"

update_mapping_last_sync_at "$mapping_arg" "$project_path" "$MAPPINGS_FILE" "$sync_at"

prev_history="$(printf '%s' "${config_store:-{\}}" | jq '(.history // []) | .[:9]')"
targets_json="$(printf '%s\n' "${targets[@]}" | jq -R . | jq -s .)"
new_config="$(jq -n \
  --arg lr "$repo" --arg lb "$branch" --argjson lt "$targets_json" --arg ls "$strategy" \
  --arg lsa "$sync_at" --argjson hist "$prev_history" --argjson he "$history_entry" \
  '{version: 1, last_repo: $lr, last_branch: $lb, last_targets: $lt, last_strategy: $ls, last_sync_at: $lsa, history: ([$he] + $hist)}')"
printf '%s\n' "$new_config" > "$CONFIG_FILE"

# --- サマリ ---
printf '\n'
printf '===== 同期結果 =====\n'
printf 'Repo:        %s\n' "$repo"
printf 'Branch:      %s\n' "$branch"
printf 'Commit:      %s\n' "$commit_sha"
printf '戦略:        %s\n' "$strategy"
if [[ -n "$backup_dir" ]]; then
  printf 'バックアップ: %s\n' "$backup_dir"
else
  printf 'バックアップ: なし（--NoBackup）\n'
fi
printf '適用件数:    %s 件\n' "$applied"
printf '失敗:        %s 件\n' "${#failed[@]}"

if [[ ${#failed[@]} -gt 0 ]]; then
  printf '\n'
  printf '失敗一覧:\n'
  for f_line in "${failed[@]}"; do
    rp="$(printf '%s' "$f_line" | awk -F'\t' '{print $1}')"
    op="$(printf '%s' "$f_line" | awk -F'\t' '{print $2}')"
    er="$(printf '%s' "$f_line" | awk -F'\t' '{print $3}')"
    printf '  FAILED [%s] %s\n' "$op" "$rp"
    printf '          %s\n' "$er"
  done
  exit 2
fi

exit 0
