#!/usr/bin/env bash
# render-check スキルの構造検証デモ (読み取り専用 / Bash 版)
# (B-3: improvement-backlog 由来テンプレートをベースに作成)
#
# render-check は AskUserQuestion を多用する対話スキルであり、チェック本体は
# Claude Code セッションでのみ動作する。そのため本スクリプトは外部 API を
# 一切呼ばず、スキル定義と参照ファイルの構造検証のみを行う:
#   - SKILL.md の存在と frontmatter (name: render-check)
#   - references/check-procedures.md の存在
#   - プラグイン共通レンダリングルール 3 ファイルの存在
#   - SKILL.md 内の 5 カテゴリ定義 (NOTATION / AUTOLINK / STRUCTURE / SECRET / SIZE)
#   - evals ケースファイル 7 件 + README.md の存在
#   - ケースファイルが仕様書専用であること (runnable フロントマター無し)
#
# 制約:
#   - 読み取り専用 (test / grep / find のみ。ファイル作成・変更・削除をしない)
#   - ネットワーク通信をしない
#
# 使い方:
#   # 計画のみ表示 (副作用ゼロ; 既定)
#   bash demo.sh
#
#   # 読み取り専用チェックを実行
#   bash demo.sh --no-whatif
#
# 関連:
# - A-1: completion-checklist.md 節 2.4 (動作デモ + 承認取得)
# - B-2: 本スキルのケースファイルは仕様書専用のため runnable 登録はしない
#   (チェック本体が対話依存であり、機械検証の射程外のため)

set -euo pipefail

# --- 引数パース ---
whatif=true

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-whatif)
      whatif=false; shift ;;
    -*)
      echo "Unknown option: $1" >&2; exit 2 ;;
    *)
      echo "Unexpected argument: $1" >&2; exit 2 ;;
  esac
done

# --- パス解決 (evals/ -> skills/render-check/ -> connector/) ---
EVALS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_DIR="$(cd "$EVALS_DIR/.." && pwd)"
PLUGIN_DIR="$(cd "$SKILL_DIR/../.." && pwd)"
RENDERING_DIR="$PLUGIN_DIR/references/rendering"

# --- ヘルパ ---
write_section() {
  local title="$1"
  printf '\n================================================================\n'
  printf '  %s\n' "$title"
  printf '================================================================\n'
}

invoke_demo_step() {
  local name="$1"
  local command="$2"
  local expect_exit_code="${3:-0}"
  local continue_on_error="${4:-false}"

  write_section "Step: $name"
  printf '  Command: %s\n' "$command"
  printf '  Expect exit code: %s\n' "$expect_exit_code"

  if [[ "$whatif" == "true" ]]; then
    printf '  [WhatIf] スキップ (副作用ゼロモード)\n'
    return 0
  fi

  set +e
  output=$(bash -c "$command" 2>&1)
  local rc=$?
  set -e

  if [[ -n "$output" ]]; then
    printf '%s\n' "$output"
  fi
  printf '  exit code: %d\n' "$rc"

  if [[ "$continue_on_error" != "true" && "$rc" -ne "$expect_exit_code" ]]; then
    printf '  [ERROR] Unexpected exit code: %d (expected %s)\n' "$rc" "$expect_exit_code"
    exit 1
  fi
}

# --- デモシナリオ ---
write_section "render-check 構造検証デモ開始"
printf '  WhatIf モード: %s\n' "$whatif"
printf '  Skill dir:     %s\n' "$SKILL_DIR"
printf '  Plugin dir:    %s\n' "$PLUGIN_DIR"
printf '\n'
printf '  実施するシナリオ (すべて読み取り専用):\n'
printf '    1. SKILL.md の存在 + frontmatter name 確認\n'
printf '    2. チェック手順リファレンスの存在確認\n'
printf '    3. 共通レンダリングルール 3 ファイルの存在確認\n'
printf '    4. SKILL.md の 5 カテゴリ定義確認\n'
printf '    5. evals ケースファイル (7 件 + README.md) の存在確認\n'
printf '    6. ケースファイルが仕様書専用であることの確認\n'
printf '    7. 対話モード誘導 (チェック本体の確認方法)\n'
printf '    8. エラーパス確認 (不正引数で exit 2)\n'
printf '\n'

# Step 1: SKILL.md の存在 + frontmatter name
invoke_demo_step \
  "SKILL.md の存在 + frontmatter name=render-check" \
  "test -f \"$SKILL_DIR/SKILL.md\" && grep -q \"^name: render-check\" \"$SKILL_DIR/SKILL.md\"" \
  "0"

# Step 2: チェック手順リファレンス
invoke_demo_step \
  "references/check-procedures.md の存在" \
  "test -f \"$SKILL_DIR/references/check-procedures.md\"" \
  "0"

# Step 3: プラグイン共通レンダリングルール 3 ファイル
invoke_demo_step \
  "共通レンダリングルール 3 ファイルの存在 (backlog-notation / backlog-markdown / azure-devops-markdown)" \
  "test -f \"$RENDERING_DIR/backlog-notation.md\" && test -f \"$RENDERING_DIR/backlog-markdown.md\" && test -f \"$RENDERING_DIR/azure-devops-markdown.md\"" \
  "0"

# Step 4: SKILL.md に 5 カテゴリが定義されていること
invoke_demo_step \
  "SKILL.md の 5 カテゴリ定義 (NOTATION / AUTOLINK / STRUCTURE / SECRET / SIZE)" \
  "for c in NOTATION AUTOLINK STRUCTURE SECRET SIZE; do grep -q \"\$c\" \"$SKILL_DIR/SKILL.md\" || exit 1; done" \
  "0"

# Step 5: evals ケースファイル 7 件 + README.md
invoke_demo_step \
  "evals ケースファイル 7 件 + README.md の存在" \
  "test \"\$(find \"$EVALS_DIR\" -maxdepth 1 -name 'case-*.md' | wc -l)\" -eq 7 && test -f \"$EVALS_DIR/README.md\"" \
  "0"

# Step 6: ケースファイルが仕様書専用 (runnable フロントマター無し)
invoke_demo_step \
  "ケースファイルに runnable フロントマターが無い (仕様書専用)" \
  "! grep -q \"^runnable:\" \"$EVALS_DIR\"/case-*.md" \
  "0"

# Step 7: 対話モード誘導 (チェック本体は Claude Code セッションでのみ確認可能)
write_section "Step: 対話モード誘導"
printf '  チェック本体 (5 カテゴリ検査 + AskUserQuestion) は Claude Code セッションで確認する:\n'
printf '\n'
printf '    「このコメントが Backlog で正しく表示されるかチェックして」\n'
printf '      -> ターゲット記法が不明なら AskUserQuestion が発火 (case-05 参照)\n'
printf '    「投稿前にレンダリング確認して」\n'
printf '      -> FAIL / WARN 時は修正案の採用可否を AskUserQuestion で確認 (case-01 / case-02 参照)\n'
printf '\n'
printf '  (本スクリプトからは UI を直接発火できないため誘導のみ)\n'

# Step 8: エラーパス (不正引数 -> exit 2)
invoke_demo_step \
  "エラーパス (demo.sh への不正引数で exit 2)" \
  "bash \"$EVALS_DIR/demo.sh\" --invalid-option" \
  "2" \
  "true"

# --- 完了サマリ ---
write_section "デモ実行完了"
printf '\n'
printf '  承認確認時の論点 (ユーザに AskUserQuestion で問うべき項目):\n'
printf '    - 全 Step の標準出力に想定外のエラーがないか\n'
printf '    - 参照ファイル構成 (SKILL.md / check-procedures.md / rendering 3 ファイル) が期待どおりか\n'
printf '    - 対話フロー (case-01 ... case-07) の期待挙動が仕様と一致しているか\n'
printf '\n'
printf '  再現コマンド (この demo.sh 自体):\n'
if [[ "$whatif" == "true" ]]; then
  printf '    bash evals/demo.sh\n'
else
  printf '    bash evals/demo.sh --no-whatif\n'
fi
printf '\n'
printf '  本スクリプトは読み取り専用であり、ファイル変更・外部通信を行わない。\n'
