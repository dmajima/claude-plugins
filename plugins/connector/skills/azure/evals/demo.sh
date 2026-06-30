#!/usr/bin/env bash
# azure スキルの構造検証を自動デモする再現可能スクリプト (Bash 版)
# (B-3: improvement-backlog 由来テンプレートを azure スキル用に適用)
#
# A-1 (動作デモ + ユーザ承認フロー必須化) と整合する、セッションを跨いで
# 同じデモを再現できるスクリプト。
#
# 実装方針:
# - 本スキルの実動作は外部 API (Azure DevOps / TFS REST API・az CLI) と
#   認証情報に依存するため、demo.sh では外部 API を一切呼ばない
#   「構造検証」のみを行う
# - 検証内容: SKILL.md の存在 / frontmatter name=azure / スキル内
#   references の存在 / プラグイン共通 references の存在 /
#   書き込みゲート記述 (render-check / AskUserQuestion) / evals ケースの存在
# - すべて読み取り専用チェック (ファイル変更・外部通信をしない)
# - API を伴う実動作の確認は evals/case-01 〜 05 の手順による
#   Claude Code セッションでの目視確認に委ねる (evals/README.md 参照)
# - エラーパスは「存在しないファイルを検出できるか」の負例セルフテストで代替
#
# 使い方:
#   # 計画のみ表示 (副作用ゼロ; 既定)
#   bash demo.sh
#
#   # 検証を実行 (読み取り専用チェックのみ)
#   bash demo.sh --no-whatif
#
# 関連:
# - A-1: completion-checklist.md 節 2.4 (動作デモ + 承認取得)
# - B-2: 各 case ファイルは外部 API 依存のため runnable 付与なし (自動 skip)
# - ADR-032: 動作デモ + 承認フロー必須化

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

# --- パス解決 (このスクリプトの位置からスキル/プラグインルートを特定) ---
SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SKILL_DIR=$(dirname "$SCRIPT_DIR")                 # skills/azure
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
write_section "azure スキル構造検証デモ開始"
printf '  WhatIf モード: %s\n' "$whatif"
printf '  スキルディレクトリ:   %s\n' "$SKILL_DIR"
printf '  プラグインディレクトリ: %s\n' "$PLUGIN_DIR"
printf '\n'
printf '  実施するシナリオ:\n'
printf '    1. SKILL.md の存在と frontmatter (name: azure) の検証\n'
printf '    2. スキル内 references (host-detection / pr-operations / workitem-operations) の存在検証\n'
printf '    3. プラグイン共通 references の存在検証\n'
printf '    4. SKILL.md 内の書き込みゲート記述 (render-check / AskUserQuestion) の検証\n'
printf '    5. evals ケースファイルの存在と runnable フロントマター不在の検証\n'
printf '    6. 対話モード誘導 (実 API 動作は Claude Code セッションで確認)\n'
printf '    7. エラーパス確認 (負例セルフテスト)\n'
printf '\n'
printf '  注意: 本スクリプトは読み取り専用チェックのみを行う\n'
printf '        (ファイル変更・外部 API 呼び出しを一切しない)\n'

# Step 1: SKILL.md の存在 + frontmatter name=azure
write_section "Step 1: SKILL.md の存在と frontmatter 検証"
check_file "SKILL.md の存在" "$SKILL_DIR/SKILL.md"
if [[ "$whatif" == "true" ]]; then
  printf '  [WhatIf] frontmatter 検証: head -n 5 SKILL.md から "name: azure" 行を検出\n'
else
  if head -n 5 "$SKILL_DIR/SKILL.md" 2>/dev/null | grep -q '^name: azure$'; then
    printf '  [OK]   frontmatter name: azure\n'
  else
    printf '  [FAIL] frontmatter に "name: azure" が見つからない\n'
    fail_count=$((fail_count + 1))
  fi
fi

# Step 2: スキル内 references の存在
write_section "Step 2: スキル内 references の存在検証"
check_file "ホスト判定・URL 解析 (host-detection.md)" "$SKILL_DIR/references/host-detection.md"
check_file "PR 操作 API 詳細 (pr-operations.md)" "$SKILL_DIR/references/pr-operations.md"
check_file "作業項目操作 API 詳細 (workitem-operations.md)" "$SKILL_DIR/references/workitem-operations.md"

# Step 3: プラグイン共通 references の存在 (SKILL.md が相対参照するファイル)
write_section "Step 3: プラグイン共通 references の存在検証"
check_file "認証事前確認 (credentials-precheck.md)" "$PLUGIN_DIR/references/credentials-precheck.md"
check_file "API アクセス安全原則 (safe-api-access.md)" "$PLUGIN_DIR/references/safe-api-access.md"
check_file "Azure DevOps レンダリングルール (azure-devops-markdown.md)" "$PLUGIN_DIR/references/rendering/azure-devops-markdown.md"

# Step 4: SKILL.md 内の書き込みゲート記述 (render-check / AskUserQuestion)
write_section "Step 4: SKILL.md 内の書き込みゲート記述の検証"
if [[ "$whatif" == "true" ]]; then
  printf '  [WhatIf] grep で SKILL.md から "render-check" と "AskUserQuestion" の記述を検出\n'
else
  if grep -q 'render-check' "$SKILL_DIR/SKILL.md" && grep -q 'AskUserQuestion' "$SKILL_DIR/SKILL.md"; then
    printf '  [OK]   書き込みゲート (render-check / AskUserQuestion) が SKILL.md に記述されている\n'
  else
    printf '  [FAIL] SKILL.md に render-check / AskUserQuestion の記述が見つからない\n'
    fail_count=$((fail_count + 1))
  fi
fi

# Step 5: evals ケースファイルの存在 + runnable フロントマター不在
write_section "Step 5: evals ケースファイルの存在検証"
check_file "evals/README.md" "$SCRIPT_DIR/README.md"
check_file "case-01 (TFS への PR 作成)" "$SCRIPT_DIR/case-01_pr_create_tfs.md"
check_file "case-02 (クラウド PR コメント投稿)" "$SCRIPT_DIR/case-02_pr_comment_cloud.md"
check_file "case-03 (PR 承認 vote=10)" "$SCRIPT_DIR/case-03_pr_approve.md"
check_file "case-04 (TFS 作業項目コメント)" "$SCRIPT_DIR/case-04_workitem_comment_tfs.md"
check_file "case-05 (未登録ホスト拒否)" "$SCRIPT_DIR/case-05_unregistered_host.md"
if [[ "$whatif" == "true" ]]; then
  printf '  [WhatIf] case ファイルに runnable フロントマターが無いことを確認 (外部 API 依存のため自動実行対象外)\n'
else
  if grep -q '^runnable:' "$SCRIPT_DIR"/case-*.md 2>/dev/null; then
    printf '  [FAIL] runnable フロントマターを持つ case ファイルがある (外部 API 依存のため付与しない方針に反する)\n'
    fail_count=$((fail_count + 1))
  else
    printf '  [OK]   全 case ファイルに runnable フロントマターなし (自動実行対象外)\n'
  fi
fi

# Step 6: 対話モード誘導 (実 API 動作は Claude Code セッションでのみ確認可能)
write_section "Step 6: 対話モード誘導"
printf '  実 API を伴う動作 (ホスト判定/書き込みゲート/承認 UI) は本スクリプトでは検証しない。\n'
printf '  Claude Code セッションで以下のフレーズを入力して確認する:\n'
printf '\n'
printf '    "feature/login から develop への PR を作成して"   # case-01 (PR 作成 + render-check + 承認 UI)\n'
printf '    "PR !123 を承認して"                              # case-03 (vote 値明示の承認 UI)\n'
printf '    "作業項目 #456 に調査結果をコメントして"          # case-04 (HTML 変換 + 承認 UI)\n'
printf '\n'
printf '  書き込み系は render-check ゲートと AskUserQuestion 承認が必ず挟まる\n'
printf '  (期待動作の詳細は evals/case-01 〜 05 を参照)。\n'

# Step 7: エラーパス確認 (負例セルフテスト: 存在しないファイルを FAIL 検出できるか)
write_section "Step 7: エラーパス確認 (負例セルフテスト)"
if [[ "$whatif" == "true" ]]; then
  printf '  [WhatIf] 存在しないパスを check_file に与え、FAIL 検出されることを確認\n'
else
  before_fail=$fail_count
  check_file "負例 (存在しないファイル)" "$SKILL_DIR/references/__nonexistent__.md"
  if [[ $fail_count -gt $before_fail ]]; then
    printf '  [OK]   負例が FAIL として検出された (チェッカ自体は正常動作)\n'
    fail_count=$before_fail   # 負例セルフテストの FAIL は総合判定から除外
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
printf '    - 実 API 動作 (case-01 〜 05) を検証用プロジェクト・PR・作業項目で目視確認したか\n'
printf '\n'
printf '  再現コマンド (この demo.sh 自体):\n'
if [[ "$whatif" == "true" ]]; then
  printf '    bash evals/demo.sh\n'
else
  printf '    bash evals/demo.sh --no-whatif\n'
fi
printf '\n'
printf '  ADR-032 に従い、これらの結果を AskUserQuestion で承認してから引き渡しに進むこと。\n'

if [[ "$whatif" == "false" && $fail_count -gt 0 ]]; then
  exit 1
fi
