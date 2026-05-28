#!/usr/bin/env bash
# check_version_bump.sh - Stop フック (Bash 版)
#
# 通常運用は本スクリプトを利用する。
# PowerShell フォールバック: check_version_bump.ps1
#
# Claude のターン終了時、plugins/{name}/ 配下に未コミット変更があり、
# かつ plugin.json の version が未更新の場合に stderr で警告する。
# 設計: フェイルオープン (exit 0、Claude のターンを止めない)

set +e

if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

# stdin を読み捨て (ファイルディスクリプタ詰まり防止)
cat >/dev/null 2>&1

# git 利用不可ならスキップ
if ! command -v git >/dev/null 2>&1; then
  exit 0
fi

# リポジトリ外ならスキップ
in_repo="$(git rev-parse --is-inside-work-tree 2>/dev/null || true)"
if [[ "$in_repo" != "true" ]]; then
  exit 0
fi

# main ブランチを特定
base=""
if git rev-parse --verify origin/main >/dev/null 2>&1; then
  base="origin/main"
elif git rev-parse --verify main >/dev/null 2>&1; then
  base="main"
fi

# 未コミット変更 (staged + unstaged + untracked) 一覧
declare -a uncommitted=()
while IFS= read -r line; do
  [[ -z "${line//[[:space:]]/}" ]] && continue
  path="${line:3}"
  # rename "A -> B" -> B 側を採用
  if [[ "$path" == *" -> "* ]]; then
    path="${path##* -> }"
  fi
  [[ -n "${path//[[:space:]]/}" ]] && uncommitted+=("$path")
done < <(git status --porcelain 2>/dev/null)

# main から HEAD までのコミット済み差分
declare -a committed=()
if [[ -n "$base" ]]; then
  while IFS= read -r line; do
    [[ -z "${line//[[:space:]]/}" ]] && continue
    committed+=("$line")
  done < <(git diff --name-only "$base..HEAD" 2>/dev/null)
fi

# all_changed (重複除去)
declare -a all_changed=()
declare -A seen=()
for p in "${committed[@]+"${committed[@]}"}" "${uncommitted[@]+"${uncommitted[@]}"}"; do
  [[ -z "${p//[[:space:]]/}" ]] && continue
  if [[ -z "${seen[$p]:-}" ]]; then
    seen[$p]=1
    all_changed+=("$p")
  fi
done

if [[ ${#all_changed[@]} -eq 0 ]]; then
  exit 0
fi

# プラグイン名抽出
declare -a plugins=()
declare -A plugin_seen=()
for p in "${all_changed[@]}"; do
  if [[ "$p" == plugins/* ]]; then
    plugin_name="${p#plugins/}"
    plugin_name="${plugin_name%%/*}"
    if [[ -n "$plugin_name" && -z "${plugin_seen[$plugin_name]:-}" ]]; then
      plugin_seen[$plugin_name]=1
      plugins+=("$plugin_name")
    fi
  fi
done

[[ ${#plugins[@]} -eq 0 ]] && exit 0
[[ -z "$base" ]] && exit 0

declare -a warnings=()
for plugin in "${plugins[@]}"; do
  pjson="plugins/$plugin/.claude-plugin/plugin.json"
  [[ ! -f "$pjson" ]] && continue

  # main の version
  old_version=""
  if old_content="$(git show "${base}:${pjson}" 2>/dev/null)"; then
    old_version="$(printf '%s' "$old_content" | jq -er '.version // empty' 2>/dev/null || true)"
  fi
  # main 側に plugin.json 不在 (新規プラグイン追加中) -> 通過
  [[ -z "$old_version" ]] && continue

  # 現在の version
  new_version="$(jq -er '.version // empty' "$pjson" 2>/dev/null || true)"

  if [[ "$old_version" == "$new_version" ]]; then
    warnings+=("  - ${plugin}: ブランチ全体で plugin.json の version が main から変わっていません (現在 $old_version のまま)")
  fi
done

[[ ${#warnings[@]} -eq 0 ]] && exit 0

cat >&2 <<EOF
[extension-toolkit hook] バージョン更新漏れの可能性を検出:
$(printf '%s\n' "${warnings[@]}")
versioning.md の方針: すべてのコミットで plugin.json の version を更新する。
コミット前に該当プラグインの plugin.json を更新してください。
 (更新基準: メジャー = 新スキル/新コマンド/新 SSOT、マイナー = 既存拡張、パッチ = バグ修正等)
EOF

exit 0
