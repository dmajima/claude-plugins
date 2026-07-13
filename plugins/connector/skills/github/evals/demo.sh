#!/usr/bin/env bash
# github スキルの構造検証を自動デモする再現可能スクリプト (Bash 版)
#
# 実装方針:
# - 本スキルの実動作は GitHub CLI (gh) に依存するため、
#   demo.sh では外部 API を一切呼ばない「構造検証」のみを行う
# - 検証内容: SKILL.md の存在 / frontmatter name=github / スキル内
#   references の存在 / プラグイン共通 references の存在 / evals ケースの存在
# - すべて読み取り専用チェック (ファイル変更・外部通信をしない)
# - gh CLI を伴う実動作の確認は evals/case-01 〜 06 の手順による
#   Claude Code セッションでの目視確認に委ねる (evals/README.md 参照)
#
# 使い方:
#   # 計画のみ表示 (副作用ゼロ; 既定)
#   bash demo.sh
#
#   # 検証を実行 (読み取り専用チェックのみ)
#   bash demo.sh --no-whatif

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

# --- パス解決 ---
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SKILL_DIR=$(dirname "$SCRIPT_DIR")                 # skills/github
PLUGIN_DIR=$(cd "$SKILL_DIR/../.." && pwd)         # plugins/connector

# --- ヘルパ ---
fail_count=0

write_section() {
  local title="$1"
  printf '\n================================================================\n'
  printf '  %s\n' "$title"
  printf '================================================================\n'
}

check_file() {
  local label="$1"
  local path="$2"

  if [[ "$whatif" == "true" ]]; then
    printf '  [WhatIf] %s : %s\n' "$label" "$path"
    return 0
  fi

  if [[ -f "$path" ]]; then
    printf '  [OK]   %s\n' "$label"
  else
    printf '  [FAIL] %s (not found: %s)\n' "$label" "$path"
    fail_count=$((fail_count + 1))
  fi
}

# --- デモシナリオ ---
write_section "github スキル構造検証デモ開始"
printf '  WhatIf モード: %s\n' "$whatif"
printf '  スキルディレクトリ:   %s\n' "$SKILL_DIR"
printf '  プラグインディレクトリ: %s\n' "$PLUGIN_DIR"
printf '\n'
printf '  実施するシナリオ:\n'
printf '    1. SKILL.md の存在と frontmatter (name: github) の検証\n'
printf '    2. スキル内 references (pr-operations) の存在検証\n'
printf '    3. プラグイン共通 references の存在検証\n'
printf '    4. evals ケースファイルの存在検証\n'
printf '    5. 対話モード誘導 (実 gh CLI 動作は Claude Code セッションで確認)\n'
printf '    6. エラーパス確認 (負例セルフテスト)\n'
printf '\n'
printf '  注意: 本スクリプトは読み取り専用チェックのみを行う\n'
printf '        (ファイル変更・外部 API 呼び出しを一切しない)\n'

# Step 1: SKILL.md の存在 + frontmatter name=github
write_section "Step 1: SKILL.md の存在と frontmatter 検証"
check_file "SKILL.md の存在" "$SKILL_DIR/SKILL.md"
if [[ "$whatif" == "true" ]]; then
  printf '  [WhatIf] frontmatter 検証: head -n 5 SKILL.md から "name: github" 行を検出\n'
else
  if head -n 5 "$SKILL_DIR/SKILL.md" 2>/dev/null | grep -q '^name: github$'; then
    printf '  [OK]   frontmatter name: github\n'
  else
    printf '  [FAIL] frontmatter に "name: github" が見つからない\n'
    fail_count=$((fail_count + 1))
  fi
fi

# Step 2: スキル内 references の存在
write_section "Step 2: スキル内 references の存在検証"
check_file "PR 操作仕様 (pr-operations.md)" "$SKILL_DIR/references/pr-operations.md"

# Step 3: プラグイン共通 references の存在
write_section "Step 3: プラグイン共通 references の存在検証"
check_file "認証事前確認 (credentials-precheck.md)" "$PLUGIN_DIR/references/credentials-precheck.md"
check_file "API アクセス安全原則 (safe-api-access.md)" "$PLUGIN_DIR/references/safe-api-access.md"
check_file "委譲インターフェース (delegation-interface.md)" "$PLUGIN_DIR/references/delegation-interface.md"

# Step 4: evals ケースファイルの存在
write_section "Step 4: evals ケースファイルの存在検証"
check_file "evals/README.md" "$SCRIPT_DIR/README.md"
check_file "case-01 (PR インラインコメント)" "$SCRIPT_DIR/case-01_pr_inline_comment.md"
check_file "case-02 (委譲 Pending Review)" "$SCRIPT_DIR/case-02_delegation_pending_review.md"
check_file "case-03 (スレッド resolve)" "$SCRIPT_DIR/case-03_thread_resolve.md"
check_file "case-04 (認証失敗)" "$SCRIPT_DIR/case-04_auth_failure.md"
check_file "case-05 (PR 全体コメント)" "$SCRIPT_DIR/case-05_pr_comment_pattern_a.md"
check_file "case-06 (委譲 resolve)" "$SCRIPT_DIR/case-06_delegation_resolve.md"
check_file "case-07 (パターンA 読み取り)" "$SCRIPT_DIR/case-07_pattern_a_read_pr.md"
check_file "case-08 (サブエージェント読み取り)" "$SCRIPT_DIR/case-08_subagent_read_pr.md"
check_file "case-09 (サブエージェント gh 未認証)" "$SCRIPT_DIR/case-09_subagent_credentials_missing.md"
check_file "case-10 (API 401/403)" "$SCRIPT_DIR/case-10_api_auth_failed.md"

# Step 5: 対話モード誘導
write_section "Step 5: 対話モード誘導"
printf '  実 gh CLI を伴う動作は本スクリプトでは検証しない。\n'
printf '  Claude Code セッションで以下のフレーズを入力して確認する:\n'
printf '\n'
printf '    "GitHub PR #123 にインラインコメントを投稿して"   # case-01\n'
printf '    "PR のスレッドを resolve して"                     # case-03\n'
printf '\n'
printf '  書き込み系は AskUserQuestion 承認が必ず挟まる\n'
printf '  (期待動作の詳細は evals/case-01_pr_inline_comment.md を参照)。\n'

# Step 6: エラーパス確認 (負例セルフテスト)
write_section "Step 6: エラーパス確認 (負例セルフテスト)"
if [[ "$whatif" == "true" ]]; then
  printf '  [WhatIf] 存在しないパスを check_file に与え、FAIL 検出されることを確認\n'
else
  before_fail=$fail_count
  check_file "負例 (存在しないファイル)" "$SKILL_DIR/references/__nonexistent__.md"
  if [[ $fail_count -gt $before_fail ]]; then
    printf '  [OK]   負例が FAIL として検出された (チェッカ自体は正常動作)\n'
    fail_count=$before_fail
  else
    printf '  [FAIL] 負例が検出されなかった (チェッカの動作異常)\n'
    fail_count=$((fail_count + 1))
  fi
fi

# --- 完了サマリ ---
write_section "デモ実行完了"
printf '\n'
if [[ "$whatif" == "false" ]]; then
  printf '  構造検証 FAIL 件数: %d\n' "$fail_count"
  printf '\n'
fi
printf '  承認確認時の論点 (ユーザに AskUserQuestion で問うべき項目):\n'
printf '    - 全 Step の出力に FAIL がないか\n'
printf '    - SKILL.md の参照ファイルが全て実在するか (リンク切れがないか)\n'
printf '    - 実 gh CLI 動作 (case-01 / 03 等) を検証用リポジトリで目視確認したか\n'
printf '\n'
printf '  再現コマンド (この demo.sh 自体):\n'
if [[ "$whatif" == "true" ]]; then
  printf '    bash evals/demo.sh\n'
else
  printf '    bash evals/demo.sh --no-whatif\n'
fi
printf '\n'

if [[ "$whatif" == "false" && $fail_count -gt 0 ]]; then
  exit 1
fi
