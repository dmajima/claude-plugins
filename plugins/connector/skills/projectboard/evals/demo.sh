#!/usr/bin/env bash
# projectboard スキルの構造検証を自動デモする再現可能スクリプト (Bash 版)
#
# 実装方針:
# - 本スキルの実動作は外部 API (HUE ProjectBoard) と認証情報に依存するため、
#   demo.sh では外部 API を一切呼ばない「構造検証」のみを行う
# - 検証内容: SKILL.md の存在 / frontmatter name=projectboard / スキル内 references の存在 /
#   プラグイン共通 references の存在 / scripts の存在と bash 構文 / urlkey.py の round-trip /
#   evals ケースの存在
# - urlkey.py の round-trip は外部通信なしで実行できるため実テストする
#   (検証済みペア abcDEFghiJKLmnoPQRst ⇔ 0bc4978b-41e7-11f1-9633-85b8872b7139)
# - API を伴う実動作の確認は evals/case-01 〜 06 の手順による Claude Code セッションでの
#   目視確認に委ねる (evals/README.md 参照)
#
# 使い方:
#   # 計画のみ表示 (副作用ゼロ; 既定)
#   bash demo.sh
#
#   # 検証を実行 (読み取り専用チェック + urlkey.py 実行)
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
SKILL_DIR=$(dirname "$SCRIPT_DIR")                 # skills/projectboard
PLUGIN_DIR=$(cd "$SKILL_DIR/../.." && pwd)         # plugins/connector

# --- ヘルパ ---
fail_count=0

write_section() {
  printf '\n================================================================\n'
  printf '  %s\n' "$1"
  printf '================================================================\n'
}

check_file() {
  local label="$1" path="$2"
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
write_section "projectboard スキル構造検証デモ開始"
printf '  WhatIf モード: %s\n' "$whatif"
printf '  スキルディレクトリ:   %s\n' "$SKILL_DIR"
printf '  プラグインディレクトリ: %s\n' "$PLUGIN_DIR"
printf '\n'
printf '  実施するシナリオ:\n'
printf '    1. SKILL.md の存在と frontmatter (name: projectboard) の検証\n'
printf '    2. スキル内 references の存在検証\n'
printf '    3. プラグイン共通 references の存在検証\n'
printf '    4. scripts の存在と bash 構文検証\n'
printf '    5. urlkey.py round-trip 検証 (外部通信なし)\n'
printf '    6. evals ケースファイルの存在検証\n'
printf '    7. 対話モード誘導 (実 API 動作は Claude Code セッションで確認)\n'
printf '    8. エラーパス確認 (負例セルフテスト)\n'
printf '\n'
printf '  注意: 本スクリプトは外部 API 呼び出し・認証を一切行わない\n'

# Step 1: SKILL.md の存在 + frontmatter
write_section "Step 1: SKILL.md の存在と frontmatter 検証"
check_file "SKILL.md の存在" "$SKILL_DIR/SKILL.md"
if [[ "$whatif" == "true" ]]; then
  printf '  [WhatIf] frontmatter 検証: head -n 5 SKILL.md から "name: projectboard" 行を検出\n'
else
  if head -n 5 "$SKILL_DIR/SKILL.md" 2>/dev/null | grep -q '^name: projectboard$'; then
    printf '  [OK]   frontmatter name: projectboard\n'
  else
    printf '  [FAIL] frontmatter に "name: projectboard" が見つからない\n'
    fail_count=$((fail_count + 1))
  fi
fi

# Step 2: スキル内 references
write_section "Step 2: スキル内 references の存在検証"
check_file "環境構築 (setup.md)" "$SKILL_DIR/references/setup.md"
check_file "読み取り API 仕様 (api-spec.md)" "$SKILL_DIR/references/api-spec.md"
check_file "書き込み API 仕様 (api-write.md)" "$SKILL_DIR/references/api-write.md"
check_file "落とし穴集 (pitfalls.md)" "$SKILL_DIR/references/pitfalls.md"
check_file "実行手順 (procedures.md)" "$SKILL_DIR/references/procedures.md"

# Step 3: プラグイン共通 references
write_section "Step 3: プラグイン共通 references の存在検証"
check_file "認証事前確認 (credentials-precheck.md)" "$PLUGIN_DIR/references/credentials-precheck.md"
check_file "API アクセス安全原則 (safe-api-access.md)" "$PLUGIN_DIR/references/safe-api-access.md"

# Step 4: scripts の存在と bash 構文
write_section "Step 4: scripts の存在と bash 構文検証"
scripts=(
  "setup/requirements.txt" "setup/setup_venv.sh" "setup/teardown_venv.sh" "setup/cleanup_sensitive.sh"
  "auth/login.sh" "auth/with_session.sh"
  "resolve/urlkey.py"
  "fetch/list_sheets.sh" "fetch/sheet_detail.sh" "fetch/get_tasks.sh"
  "write/post_node_api.sh" "write/stomp_session.py"
  "format/tasks_to_csv.py" "format/analyze_schedule.py"
)
for rel in "${scripts[@]}"; do
  check_file "scripts/$rel" "$SKILL_DIR/scripts/$rel"
done
if [[ "$whatif" == "true" ]]; then
  printf '  [WhatIf] 全 *.sh に bash -n を実行\n'
else
  for sh in "$SKILL_DIR"/scripts/*/*.sh; do
    if bash -n "$sh" 2>/dev/null; then
      printf '  [OK]   bash -n %s\n' "$(basename "$sh")"
    else
      printf '  [FAIL] bash -n %s (構文エラー)\n' "$sh"
      fail_count=$((fail_count + 1))
    fi
  done
fi

# Step 5: urlkey.py round-trip (外部通信なし)
write_section "Step 5: urlkey.py round-trip 検証"
if [[ "$whatif" == "true" ]]; then
  printf '  [WhatIf] abcDEFghiJKLmnoPQRst → UUID → 再エンコードの一致を検証\n'
  printf '  [WhatIf] 不正 urlKey ("INVALID!!") が exit 1 で拒否されることを検証\n'
else
  if command -v python > /dev/null 2>&1; then
    expected_uuid="0bc4978b-41e7-11f1-9633-85b8872b7139"
    actual_uuid=$(python "$SKILL_DIR/scripts/resolve/urlkey.py" "abcDEFghiJKLmnoPQRst" 2>/dev/null || echo "ERROR")
    if [[ "$actual_uuid" == "$expected_uuid" ]]; then
      printf '  [OK]   urlkey.py decode (round-trip ガード込み)\n'
    else
      printf '  [FAIL] urlkey.py decode: expected=%s actual=%s\n' "$expected_uuid" "$actual_uuid"
      fail_count=$((fail_count + 1))
    fi
    # 負例: 不正文字を含む urlKey は exit 1 で拒否される (落とし穴 #2 の異常入力パス)
    if python "$SKILL_DIR/scripts/resolve/urlkey.py" "INVALID!!" > /dev/null 2>&1; then
      printf '  [FAIL] urlkey.py が不正 urlKey を受理した (拒否されるべき)\n'
      fail_count=$((fail_count + 1))
    else
      printf '  [OK]   urlkey.py が不正 urlKey を exit 1 で拒否\n'
    fi
  else
    printf '  [SKIP] python が見つからないため urlkey.py 検証を省略\n'
  fi
fi

# Step 6: evals ケースファイル
write_section "Step 6: evals ケースファイルの存在検証"
check_file "evals/README.md" "$SCRIPT_DIR/README.md"
check_file "case-01 (タスク読み取り)" "$SCRIPT_DIR/case-01_task_read.md"
check_file "case-02 (シート構造解析)" "$SCRIPT_DIR/case-02_sheet_structure.md"
check_file "case-03 (タスク追加)" "$SCRIPT_DIR/case-03_task_add.md"
check_file "case-04 (タスク更新)" "$SCRIPT_DIR/case-04_task_update.md"
check_file "case-05 (認証情報なし)" "$SCRIPT_DIR/case-05_credentials_missing.md"
check_file "case-06 (セッション切れ)" "$SCRIPT_DIR/case-06_session_expired.md"
check_file "case-07 (書き込み中止)" "$SCRIPT_DIR/case-07_write_cancel.md"

# Step 7: 対話モード誘導
write_section "Step 7: 対話モード誘導"
printf '  実 API を伴う動作 (ログイン/取得/書き込み/承認 UI) は本スクリプトでは検証しない。\n'
printf '  Claude Code セッションで以下のフレーズを入力して確認する:\n'
printf '\n'
printf '    "ProjectBoard のこのシートのタスクを CSV にして <シートURL>"   # case-01 (読み取り)\n'
printf '    "このシートのクリティカルパスを分析して <シートURL>"           # case-02 (構造解析)\n'
printf '    "<シート> に <タスク名> を追加して"                            # case-03 (書き込み + 承認 UI)\n'
printf '\n'
printf '  書き込み系は AskUserQuestion 承認と実行後の反映検証が必ず挟まる\n'
printf '  (期待動作の詳細は evals/case-03_task_add.md を参照)。\n'

# Step 8: エラーパス確認 (負例セルフテスト)
write_section "Step 8: エラーパス確認 (負例セルフテスト)"
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
printf '    - 実 API 動作 (case-01 / 03 等) を検証用シートで目視確認したか\n'
printf '\n'
printf '  再現コマンド (この demo.sh 自体):\n'
if [[ "$whatif" == "true" ]]; then
  printf '    bash evals/demo.sh\n'
else
  printf '    bash evals/demo.sh --no-whatif\n'
fi

if [[ "$whatif" == "false" && $fail_count -gt 0 ]]; then
  exit 1
fi
