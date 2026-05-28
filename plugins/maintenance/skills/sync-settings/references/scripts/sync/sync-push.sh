#!/usr/bin/env bash
# sync-push.sh - sync 結果を Git push (Bash + git + gh CLI 純粋実装)
#
# 通常運用は本スクリプトを利用する。
# PowerShell フォールバック: sync-push.ps1 (機能等価、歴史的経緯で保持)
#
# 処理の流れ:
#   1. sync-mappings.json から該当スコープのマッピングを取得
#   2. clone 領域 (repo-push/) を最新化 (git fetch + reset)
#   3. ローカル → repo/ にコピー (除外フィルタ + reparse 安全)
#   4. git status で変更検出
#   5. 変更があれば新ブランチ作成 + commit + push (+ gh pr create)

set -uo pipefail

script_dir="$(cd "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=sync-common.sh
source "$script_dir/sync-common.sh"

# --- 引数解析 ---
mapping_arg=""
project_path=""
commit_message=""
branch_prefix="sync-from-local"
pr_title=""
pr_body=""
no_pr=0
dry_run=0
yes=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -Mapping|--mapping)             mapping_arg="${2:-}"; shift 2 ;;
    -ProjectPath|--project-path)    project_path="${2:-}"; shift 2 ;;
    -CommitMessage|--commit-message) commit_message="${2:-}"; shift 2 ;;
    -BranchPrefix|--branch-prefix)  branch_prefix="${2:-}"; shift 2 ;;
    -PrTitle|--pr-title)            pr_title="${2:-}"; shift 2 ;;
    -PrBody|--pr-body)              pr_body="${2:-}"; shift 2 ;;
    -NoPr|--no-pr)                  no_pr=1; shift ;;
    -DryRun|--dry-run)              dry_run=1; shift ;;
    -Yes|--yes)                     yes=1; shift ;;
    *) shift ;;
  esac
done

if [[ -z "$mapping_arg" ]]; then
  printf 'エラー: -Mapping が必須です (global または project)。\n' >&2
  exit 1
fi
case "$mapping_arg" in
  global|project) ;;
  *) printf 'エラー: -Mapping が無効です: %s\n' "$mapping_arg" >&2; exit 1 ;;
esac

# --- 定数 ---
home_dir="${USERPROFILE:-${HOME:-}}"
if command -v cygpath >/dev/null 2>&1 && [[ "$home_dir" == *":"* ]]; then
  home_dir="$(cygpath -u -- "$home_dir")"
fi
BASE_DIR="$home_dir/.claude/.local/plugins/maintenance"
MAPPINGS_FILE="$BASE_DIR/sync-mappings.json"
REPO_DIR="$BASE_DIR/repo-push"
CLAUDE_HOME="$home_dir/.claude"

# --- BranchPrefix / PrTitle / PrBody / CommitMessage のバリデーション ---
if ! test_branch_prefix_safe "$branch_prefix"; then
  printf 'エラー: BranchPrefix に無効な文字が含まれています (許容: 英数字 / . / _ / -、'\''-'\'' 始まり禁止): %s\n' "$branch_prefix" >&2
  exit 1
fi
# 制御文字 (CR / LF / 等) を含む PrTitle を拒否
if [[ -n "$pr_title" ]] && [[ "$pr_title" =~ [[:cntrl:]] ]]; then
  printf 'エラー: PrTitle に制御文字が含まれています\n' >&2
  exit 1
fi
# PrBody は改行を許容するが NUL バイトと CR は禁止
if [[ -n "$pr_body" ]]; then
  if [[ "${pr_body//$'\0'/}" != "$pr_body" ]] || [[ "$pr_body" == *$'\r'* ]]; then
    printf 'エラー: PrBody に NUL バイトまたは CR が含まれています\n' >&2
    exit 1
  fi
fi
# CommitMessage: NUL バイト禁止
if [[ -n "$commit_message" ]] && [[ "${commit_message//$'\0'/}" != "$commit_message" ]]; then
  printf 'エラー: CommitMessage に NUL バイトが含まれています\n' >&2
  exit 1
fi
# 長さ上限
if [[ -n "$pr_title" && ${#pr_title} -gt 256 ]]; then
  printf 'エラー: PrTitle が長すぎます (256 文字上限)\n' >&2; exit 1
fi
if [[ -n "$pr_body" && ${#pr_body} -gt 65535 ]]; then
  printf 'エラー: PrBody が長すぎます (65535 文字上限)\n' >&2; exit 1
fi
if [[ -n "$commit_message" && ${#commit_message} -gt 8192 ]]; then
  printf 'エラー: CommitMessage が長すぎます (8192 文字上限)\n' >&2; exit 1
fi

# --- マッピング解決 ---
if [[ ! -f "$MAPPINGS_FILE" ]]; then
  printf 'エラー: sync-mappings.json が見つかりません。/sync-map-set でマッピングを設定してください。\n' >&2
  exit 1
fi
if ! mappings_store="$(jq -e . "$MAPPINGS_FILE" 2>/dev/null)"; then
  printf 'エラー: sync-mappings.json のパース失敗\n' >&2
  exit 1
fi

mapping_entry=""
local_base=""
if [[ "$mapping_arg" == "global" ]]; then
  mapping_entry="$(printf '%s' "$mappings_store" | jq -c '.global // empty')"
  local_base="$CLAUDE_HOME"
else
  resolved_project="$project_path"
  if [[ -z "$resolved_project" ]]; then
    if tmp="$(git rev-parse --show-toplevel 2>/dev/null)" && [[ -n "$tmp" ]]; then
      resolved_project="$tmp"
    else
      resolved_project="$(pwd)"
    fi
  fi
  if [[ -e "$resolved_project" ]] && command -v cygpath >/dev/null 2>&1; then
    wpath="$(cygpath -w -- "$resolved_project" 2>/dev/null)" || wpath=""
    [[ -n "$wpath" ]] && resolved_project="$wpath"
  fi
  mapping_entry="$(printf '%s' "$mappings_store" | jq -c --arg k "$resolved_project" '.projects[$k] // empty')"
  # POSIX 形式に戻して local_base に使う (Git Bash のファイル I/O 互換性のため)
  if command -v cygpath >/dev/null 2>&1; then
    local_base="$(cygpath -u -- "$resolved_project" 2>/dev/null || printf '%s' "$resolved_project")"
  else
    local_base="$resolved_project"
  fi
fi

if [[ -z "$mapping_entry" ]]; then
  printf 'エラー: Mapping '\''%s'\'' に対応するマッピングが sync-mappings.json に存在しません。/sync-map-set で設定してください。\n' "$mapping_arg" >&2
  exit 1
fi

repo="$(printf '%s' "$mapping_entry" | jq -r '.remote_repo // empty')"
branch="$(printf '%s' "$mapping_entry" | jq -r '.remote_branch // empty')"
declare -a targets=()
while IFS= read -r t; do
  [[ -z "$t" ]] && continue
  targets+=("$t")
done < <(printf '%s' "$mapping_entry" | jq -r '.targets[]?')

# マッピング由来値の再検証
if ! test_repo_url_safe "$repo"; then
  printf 'エラー: マッピング由来の remote_repo が無効です (外部書き換え疑い): %s\n' "$(hide_secrets "$repo")" >&2
  exit 1
fi
if ! test_branch_name_safe "$branch"; then
  printf 'エラー: マッピング由来の remote_branch が無効です (外部書き換え疑い): %s\n' "$branch" >&2
  exit 1
fi
for t in "${targets[@]}"; do
  if test_target_excluded "$t"; then
    printf 'エラー: マッピング由来の target に除外対象が含まれています (外部書き換え疑い): %s\n' "$t" >&2
    exit 1
  fi
done

printf '[mapping] %s repo=%s, branch=%s, targets=%s 件\n' "$mapping_arg" "$repo" "$branch" "${#targets[@]}"
printf '[local-base] %s\n' "$local_base"

# --- Git CLI 確認 ---
if ! command -v git >/dev/null 2>&1; then
  printf 'エラー: Git CLI が見つかりません。インストールしてください。\n' >&2
  exit 1
fi

# --- clone 領域準備 ---
printf '\n'
printf '===== リポジトリ準備 =====\n'

invoke_fresh_push_clone() {
  while IFS= read -r line; do
    write_masked_output "$line"
  done < <(git "${GIT_SAFE_OPTS[@]}" clone --depth 1 --branch "$branch" -- "$repo" "$REPO_DIR" 2>&1)
  if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
    printf 'エラー: Git clone 失敗: exit %s\n' "${PIPESTATUS[0]}" >&2
    exit 1
  fi
}

if [[ ! -d "$REPO_DIR" ]]; then
  invoke_fresh_push_clone
else
  current_origin="$(cd "$REPO_DIR" && git remote get-url origin 2>/dev/null || true)"
  if [[ -n "$current_origin" && "$current_origin" != "$repo" ]]; then
    printf '警告: 既存 repo-push/ の origin が期待値と異なります (期待: %s / 実際: %s)。再 clone を実施します。\n' \
      "$(hide_secrets "$repo")" "$(hide_secrets "$current_origin")" >&2
    rm -rf -- "$REPO_DIR" || { printf 'エラー: 既存 repo-push/ の削除失敗\n' >&2; exit 1; }
    invoke_fresh_push_clone
  else
    pushd "$REPO_DIR" >/dev/null
    while IFS= read -r line; do write_masked_output "$line"; done \
      < <(git "${GIT_SAFE_OPTS[@]}" fetch --depth 1 origin "$branch" 2>&1)
    if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
      printf 'エラー: Git fetch 失敗: exit %s\n' "${PIPESTATUS[0]}" >&2
      popd >/dev/null; exit 1
    fi
    while IFS= read -r line; do write_masked_output "$line"; done \
      < <(git "${GIT_SAFE_OPTS[@]}" checkout "$branch" 2>&1)
    if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
      printf 'エラー: Git checkout 失敗: exit %s\n' "${PIPESTATUS[0]}" >&2
      popd >/dev/null; exit 1
    fi
    while IFS= read -r line; do write_masked_output "$line"; done \
      < <(git "${GIT_SAFE_OPTS[@]}" reset --hard "origin/$branch" 2>&1)
    if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
      printf 'エラー: Git reset 失敗: exit %s\n' "${PIPESTATUS[0]}" >&2
      popd >/dev/null; exit 1
    fi
    git "${GIT_SAFE_OPTS[@]}" clean -fdx >/dev/null 2>&1 || true
    popd >/dev/null
  fi
fi

# --- ローカル → repo/ コピー ---
printf '\n'
printf '===== ローカル → repo/ コピー =====\n'
copied_count=0
skipped_excluded_count=0

for t in "${targets[@]}"; do
  if test_target_excluded "$t"; then
    printf '警告: 除外対象のためスキップ (target): %s\n' "$t" >&2
    skipped_excluded_count=$(( skipped_excluded_count + 1 ))
    continue
  fi
  local_target="$local_base/$t"
  if [[ ! -e "$local_target" ]]; then
    printf '警告: ローカル側に存在しないためスキップ: %s\n' "$local_target" >&2
    continue
  fi
  if test_reparse_item "$local_target"; then
    printf '警告: 再解析ポイントのためスキップ (target): %s\n' "$t" >&2
    skipped_excluded_count=$(( skipped_excluded_count + 1 ))
    continue
  fi

  if [[ -f "$local_target" ]]; then
    dest_file="$REPO_DIR/$t"
    dest_dir="$(dirname -- "$dest_file")"
    [[ ! -d "$dest_dir" ]] && mkdir -p -- "$dest_dir"
    cp -f -- "$local_target" "$dest_file"
    copied_count=$(( copied_count + 1 ))
  else
    while IFS= read -r -d '' f; do
      rel="${f#"$local_target"}"
      rel="${rel#/}"
      rel="${rel#\\}"
      combined_rel="$t/$rel"
      if test_file_excluded "$combined_rel"; then
        skipped_excluded_count=$(( skipped_excluded_count + 1 ))
        continue
      fi
      dest_file="$REPO_DIR/$combined_rel"
      dest_dir="$(dirname -- "$dest_file")"
      [[ ! -d "$dest_dir" ]] && mkdir -p -- "$dest_dir"
      cp -f -- "$f" "$dest_file"
      copied_count=$(( copied_count + 1 ))
    done < <(get_non_reparse_file_items "$local_target")
  fi
done

printf 'コピー: %s 件、除外スキップ: %s 件\n' "$copied_count" "$skipped_excluded_count"

# --- git status で変更検出 ---
printf '\n'
printf '===== Git 変更検出 =====\n'
pushd "$REPO_DIR" >/dev/null

status_output="$(git status --short 2>&1)"
status_rc=$?
if [[ "$status_rc" -ne 0 ]]; then
  printf 'エラー: git status 失敗: exit %s\n' "$status_rc" >&2
  popd >/dev/null; exit 1
fi
if [[ -z "$status_output" ]]; then
  printf '(変更なし。push をスキップして終了)\n'
  popd >/dev/null; exit 0
fi
printf '%s\n' "$status_output"

# --- DryRun ---
if [[ "$dry_run" -eq 1 ]]; then
  printf '\n'
  printf '(dry-run) git add / commit / push は行いません。\n'
  popd >/dev/null; exit 0
fi

# --- Yes フラグなしでは push しない ---
if [[ "$yes" -ne 1 ]]; then
  printf '\n'
  printf '実 push するには -Yes フラグを付けて再実行してください (AskUserQuestion 経由推奨)。\n'
  popd >/dev/null; exit 0
fi

# --- 新ブランチ作成 + commit + push ---
ts_branch="$(date -u +%Y%m%d-%H%M%S)"
new_branch="${branch_prefix}-${mapping_arg}-${ts_branch}"

printf '\n'
printf '===== 新ブランチ作成 + commit + push =====\n'
printf '新ブランチ: %s\n' "$new_branch"

while IFS= read -r line; do write_masked_output "$line"; done \
  < <(git "${GIT_SAFE_OPTS[@]}" checkout -b "$new_branch" 2>&1)
if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
  printf 'エラー: 新ブランチ作成失敗: exit %s\n' "${PIPESTATUS[0]}" >&2
  popd >/dev/null; exit 1
fi

msg="$commit_message"
if [[ -z "$msg" ]]; then
  ts_commit="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  msg="sync from local ${ts_commit}"
fi

while IFS= read -r line; do write_masked_output "$line"; done \
  < <(git "${GIT_SAFE_OPTS[@]}" add -A 2>&1)
if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
  printf 'エラー: git add 失敗: exit %s\n' "${PIPESTATUS[0]}" >&2
  git "${GIT_SAFE_OPTS[@]}" checkout "$branch" >/dev/null 2>&1 || true
  git "${GIT_SAFE_OPTS[@]}" branch -D "$new_branch" >/dev/null 2>&1 || true
  popd >/dev/null; exit 1
fi

while IFS= read -r line; do write_masked_output "$line"; done \
  < <(git "${GIT_SAFE_OPTS[@]}" commit -m "$msg" 2>&1)
if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
  printf 'エラー: git commit 失敗: exit %s\n' "${PIPESTATUS[0]}" >&2
  git "${GIT_SAFE_OPTS[@]}" checkout "$branch" >/dev/null 2>&1 || true
  git "${GIT_SAFE_OPTS[@]}" branch -D "$new_branch" >/dev/null 2>&1 || true
  popd >/dev/null; exit 1
fi

while IFS= read -r line; do write_masked_output "$line"; done \
  < <(git "${GIT_SAFE_OPTS[@]}" push -u origin "$new_branch" 2>&1)
if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
  printf 'エラー: git push 失敗: exit %s\n' "${PIPESTATUS[0]}" >&2
  git "${GIT_SAFE_OPTS[@]}" checkout "$branch" >/dev/null 2>&1 || true
  popd >/dev/null; exit 1
fi

# --- 規定ブランチに復帰 ---
printf '\n'
printf '===== 規定ブランチに復帰 =====\n'
while IFS= read -r line; do write_masked_output "$line"; done \
  < <(git "${GIT_SAFE_OPTS[@]}" checkout "$branch" 2>&1)
if [[ "${PIPESTATUS[0]}" -ne 0 ]]; then
  printf '警告: 規定ブランチへの復帰失敗。手動で '\''git checkout %s'\'' を実行してください。\n' "$branch" >&2
fi

# --- PR 作成 (gh CLI 経由) ---
pr_created=0
pr_url=""
if [[ "$no_pr" -eq 1 ]]; then
  printf '\n'
  printf '[--no-pr] PR 作成はスキップされました。\n'
else
  printf '\n'
  printf '===== PR 作成 =====\n'
  if ! command -v gh >/dev/null 2>&1; then
    printf '警告: gh CLI が見つかりません。PR は作成されません。\n' >&2
    printf '手動で以下の PR を作成してください:\n'
    printf '  base:  %s\n' "$branch"
    printf '  head:  %s\n' "$new_branch"
    printf '  repo:  %s\n' "$repo"
  else
    resolved_pr_title="$pr_title"
    if [[ -z "$resolved_pr_title" ]]; then
      resolved_pr_title="[sync-settings] $mapping_arg マッピングからの自動同期 ($ts_branch)"
    fi
    resolved_pr_body="$pr_body"
    if [[ -z "$resolved_pr_body" ]]; then
      if [[ "$mapping_arg" == "global" ]]; then
        anonymized_base='~/.claude'
      else
        anonymized_base="$(basename -- "$local_base")"
      fi
      targets_joined="$(IFS=', '; printf '%s' "${targets[*]}")"
      resolved_pr_body="maintenance プラグインの sync-settings スキル (/sync-push) による自動同期です。

- スコープ: $mapping_arg
- ローカル基点: $anonymized_base
- targets: $targets_joined
- commit: $msg
- 新ブランチ: $new_branch
- ベースブランチ: $branch

このブランチは sync-push.ps1 が作成しました。マージ後に削除してください。"
    fi

    gh_out_file="$(mktemp)"
    if gh pr create --repo "$repo" --base "$branch" --head "$new_branch" --title "$resolved_pr_title" --body "$resolved_pr_body" > "$gh_out_file" 2>&1; then
      pr_created=1
      pr_url="$(tail -n 1 "$gh_out_file" | tr -d '\r\n')"
      printf 'PR 作成成功: %s\n' "$pr_url"
    else
      printf '警告: PR 作成失敗 (gh CLI authentication / repo 権限を確認してください)。\n' >&2
      printf '手動で以下の PR を作成してください:\n'
      printf '  base:  %s\n' "$branch"
      printf '  head:  %s\n' "$new_branch"
      printf '  repo:  %s\n' "$repo"
      printf '\n'
      printf 'gh 出力:\n'
      while IFS= read -r line; do write_masked_output "$line"; done < "$gh_out_file"
    fi
    rm -f -- "$gh_out_file" 2>/dev/null
  fi
fi

printf '\n'
printf '===== push 完了 =====\n'
printf 'Repo:        %s\n' "$repo"
printf 'Base:        %s\n' "$branch"
printf 'Head branch: %s\n' "$new_branch"
printf 'Commit:      %s\n' "$msg"
if [[ "$pr_created" -eq 1 ]]; then
  printf 'PR:          %s\n' "$pr_url"
elif [[ "$no_pr" -ne 1 ]]; then
  printf 'PR:          (未作成・手動対応が必要)\n'
fi
popd >/dev/null

# --- SSOT 更新 ---
now_iso="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
update_mapping_last_sync_at "$mapping_arg" "$project_path" "$MAPPINGS_FILE" "$now_iso"

exit 0
