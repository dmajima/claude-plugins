#!/usr/bin/env bash
# install_rule_template.sh (Bash 版)
#
# credentials-manager プラグインの SessionStart フック。
#
# 「認証情報が必要な処理では credentials-manager を最優先せよ」と定める
# 最重要ルールファイルのテンプレートを、プラグインのインストールスコープに応じた
# ディレクトリにコピーする (既存の場合は何もしない)。
#
# あわせて、検出フック（PreToolUse / UserPromptSubmit）が動く前提（bash 4 以上・jq・
# 共通のパターン定義）を自己診断する。検出フックは前提を欠くと何もせずに終了する
# （フェイルオープン）ため、ここで知らせないと保護が外れたことに気付けない。
#
# 設計: フェイルオープン (例外時も exit 0、Claude Code を止めない)

# フェイルオープン用に set -e は使わない。明示的にエラー処理する。
set +e

# このスクリプトは、検出フックが動かない環境（bash 4 未満・jq なし）でもルールを配置して知らせるため、
# bash 3.2（macOS の既定）でも動く書き方に限る（${var,,}・mapfile・連想配列等の bash 4 以降の構文を使わない。
# 回帰テストで確認している）

hooks_dir="${BASH_SOURCE[0]%/*}"
[[ $hooks_dir == "${BASH_SOURCE[0]}" ]] && hooks_dir=.

# 自己診断。問題ごとに、ユーザーに案内する対処を添える（同じ対処は 1 回だけ）
problems=""
remedies=""
add_problem() {  # $1=問題 $2=対処
  problems="${problems:+$problems、}$1"
  case "$remedies" in
    *"$2"*) ;;
    *) remedies="${remedies:+$remedies / }$2" ;;
  esac
}
has_jq=1
command -v jq >/dev/null 2>&1 || { has_jq=0; add_problem "jq が見つからない" "jq をインストールする"; }
if [[ -z "${BASH_VERSINFO:-}" || "${BASH_VERSINFO[0]}" -lt 4 ]]; then
  add_problem "bash ${BASH_VERSION:-?} では動かない（4 以上が必要）" "bash 4 以上を使う（macOS は Homebrew の bash 等）"
fi
for lib in credential_patterns.sh credential_files.sh; do
  [[ -f "$hooks_dir/lib/$lib" ]] || add_problem "lib/$lib が無い" "プラグインを更新するか入れ直す"
done
diag=""
if [[ -n "$problems" ]]; then
  diag="[credentials-manager] 認証情報の検出フック（PreToolUse / UserPromptSubmit）が動作しません（${problems}）。ツールの実行は止めませんが、外部通信や認証情報の扱いの念押しは出ません。ユーザーにこの状態を伝え、対処（${remedies}）を案内してください。"
fi

# 診断の結果とテンプレートの配置の結果を、まとめて 1 回で出力する。
# jq が無いときは平文で出す（SessionStart の標準出力は、終了コード 0 ならそのままコンテキストに入る）
emit() {  # $1=メッセージ（空なら何も出さない）
  [[ -z "$1" ]] && exit 0
  if [[ $has_jq -eq 1 ]]; then
    jq -nc --arg msg "$1" '{
      continue: true,
      suppressOutput: false,
      hookSpecificOutput: {
        hookEventName: "SessionStart",
        additionalContext: $msg
      }
    }'
  else
    printf '%s\n' "$1"
  fi
  exit 0
}

plugin_root="${CLAUDE_PLUGIN_ROOT:-}"
project_dir="${CLAUDE_PROJECT_DIR:-}"

if [[ -z "$plugin_root" ]]; then
  emit "$diag"
fi

template="$plugin_root/references/templates/rules/security/credentials-management.md"
if [[ ! -f "$template" ]]; then
  emit "$diag"
fi

# パス正規化 (バックスラッシュ -> スラッシュ)
plugin_root_norm="${plugin_root//\\/\/}"

home_dir="${USERPROFILE:-${HOME:-}}"

scope=""
target_dir=""

if [[ -n "$home_dir" ]]; then
  home_dir_norm="${home_dir//\\/\/}"
  home_prefix="${home_dir_norm}/.claude/"
  # 大文字小文字を区別しない前方一致（bash 3 でも動くよう、${var,,} ではなく nocasematch で比べる）
  shopt -s nocasematch
  if [[ "$plugin_root_norm" == "$home_prefix"* ]]; then
    scope="user"
    target_dir="$home_dir/.claude/rules/security"
  fi
  shopt -u nocasematch
fi

if [[ -z "$scope" ]]; then
  if [[ -z "$project_dir" ]]; then
    emit "$diag"
  fi
  scope="project"
  target_dir="$project_dir/.claude/rules/security"
fi

target="$target_dir/credentials-management.md"

# 既配置時は配置しない (ユーザー編集を尊重)
if [[ -f "$target" ]]; then
  emit "$diag"
fi

# 配置できなかったときも、ルールが無いままになることを知らせる
failed="[credentials-manager] ルール 'credentials-management.md' を ${target} に配置できませんでした（ディレクトリの作成かコピーに失敗）。権限とパスを確認するよう、ユーザーに案内してください。"
if ! mkdir -p -- "$target_dir" 2>/dev/null; then
  emit "${diag:+$diag }$failed"
fi
if ! cp -- "$template" "$target" 2>/dev/null; then
  emit "${diag:+$diag }$failed"
fi

message="[credentials-manager] ${scope} 向けにルール 'credentials-management.md' を ${target} に配置しました。本ルールは認証情報・URL アクセス・外部通信を伴うすべての処理で参照系を credentials-reader、書き込み系を credentials-manager に分離して最優先起動するよう定めています。CLAUDE.md からの参照追加が未済みの場合、ユーザーに案内してください。"

emit "${diag:+$diag }$message"
