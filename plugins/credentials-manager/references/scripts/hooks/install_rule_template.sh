#!/usr/bin/env bash
# install_rule_template.sh (Bash 版)
#
# credentials-manager プラグインの SessionStart フック。
#
# 「認証情報が必要な処理では credentials-manager を最優先せよ」と定める
# 最重要ルールファイルのテンプレートを、プラグインのインストールスコープに応じた
# ディレクトリにコピーする (既存の場合は何もしない)。
#
# 設計: フェイルオープン (例外時も exit 0、Claude Code を止めない)

# フェイルオープン用に set -e は使わない。明示的にエラー処理する。
set +e

# JSON 操作には jq が必須。不在ならフェイルオープン
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

plugin_root="${CLAUDE_PLUGIN_ROOT:-}"
project_dir="${CLAUDE_PROJECT_DIR:-}"

if [[ -z "$plugin_root" ]]; then
  exit 0
fi

template="$plugin_root/references/templates/rules/security/credentials-management.md"
if [[ ! -f "$template" ]]; then
  exit 0
fi

# パス正規化 (バックスラッシュ -> スラッシュ)
plugin_root_norm="${plugin_root//\\/\/}"

home_dir="${USERPROFILE:-${HOME:-}}"

scope=""
target_dir=""

if [[ -n "$home_dir" ]]; then
  home_dir_norm="${home_dir//\\/\/}"
  home_prefix="${home_dir_norm}/.claude/"
  # case-insensitive prefix 比較（PowerShell の OrdinalIgnoreCase 相当）
  if [[ "${plugin_root_norm,,}" == "${home_prefix,,}"* ]]; then
    scope="user"
    target_dir="$home_dir/.claude/rules/security"
  fi
fi

if [[ -z "$scope" ]]; then
  if [[ -z "$project_dir" ]]; then
    exit 0
  fi
  scope="project"
  target_dir="$project_dir/.claude/rules/security"
fi

target="$target_dir/credentials-management.md"

# 既配置時は何もしない (ユーザー編集を尊重)
if [[ -f "$target" ]]; then
  exit 0
fi

if ! mkdir -p -- "$target_dir" 2>/dev/null; then
  exit 0
fi
if ! cp -- "$template" "$target" 2>/dev/null; then
  exit 0
fi

message="[credentials-manager] ${scope} 向けにルール 'credentials-management.md' を ${target} に配置しました。本ルールは認証情報・URL アクセス・外部通信を伴うすべての処理で参照系を credentials-reader、書き込み系を credentials-manager に分離して最優先起動するよう定めています。CLAUDE.md からの参照追加が未済みの場合、ユーザーに案内してください。"

# JSON 出力（jq で組み立て、Compress 相当）
jq -nc --arg msg "$message" '{
  continue: true,
  suppressOutput: false,
  hookSpecificOutput: {
    hookEventName: "SessionStart",
    additionalContext: $msg
  }
}'

exit 0
