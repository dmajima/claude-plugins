#!/usr/bin/env bash
# {skill-name} スキルの代表シナリオを自動デモする再現可能スクリプト (Bash 版)
# (B-3: improvement-backlog 由来)
#
# 通常運用は本スクリプトを利用する。
# PowerShell フォールバック: demo.ps1
#
# A-1 (動作デモ + ユーザ承認フロー必須化) と整合する、セッションを跨いで
# 同じデモを再現できるテンプレート。新規スキル作成時にこのファイルを
# skills/{skill-name}/evals/demo.sh にコピーし、`{...}` プレースホルダを
# 実際のコマンド・期待値で埋める。
#
# 実装方針:
# - 代表的な正常系 (dry-run) を必ず含める
# - 主要分岐 1 件以上を実行 (引数・フラグ違いで挙動が変わる箇所)
# - AskUserQuestion 含有スキルなら「対話モードへの誘導コマンド」を 1 件記載
#   (対話 UI そのものは Claude Code セッションでないと発火しないため、
#    誘導コマンドの起動確認まで demo.sh で扱う)
# - エラーパス (引数不正・前提不足等) を 1 件含める
# - ファイル副作用がある場合は実行前に「これから何が起きるか」を提示
# - 終了時に再現コマンド一覧と「承認確認時の論点」をユーザに提示
#
# 使い方:
#   # 計画のみ表示 (副作用ゼロ; 既定)
#   bash demo.sh
#
#   # 実コマンドを実行 (dry-run は副作用なし)
#   bash demo.sh --no-whatif
#
# 関連:
# - A-1: completion-checklist.md 節 2.4 (動作デモ + 承認取得)
# - B-2: run_evals.py (このスクリプトは B-2 の runnable: true ケースとして
#         登録するか、または開発者向けデモとして別運用するか選択可能)
# - ADR-032: 動作デモ + 承認フロー必須化

set -euo pipefail

# --- 引数パース ---
whatif=true
workspace=".claude/.local/work/demo_{skill-name}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --no-whatif)
      whatif=false; shift ;;
    --workspace)
      workspace="${2:-}"; shift 2 ;;
    -*)
      echo "Unknown option: $1" >&2; exit 2 ;;
    *)
      echo "Unexpected argument: $1" >&2; exit 2 ;;
  esac
done

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

  printf '%s\n' "$output"
  printf '  exit code: %d\n' "$rc"

  if [[ "$continue_on_error" != "true" && "$rc" -ne "$expect_exit_code" ]]; then
    printf '  [ERROR] Unexpected exit code: %d (expected %s)\n' "$rc" "$expect_exit_code"
    if [[ "$continue_on_error" != "true" ]]; then
      exit 1
    fi
  fi
}

# --- デモシナリオ ---
write_section "{skill-name} デモ実行開始"
printf '  WhatIf モード: %s\n' "$whatif"
printf '  Workspace:     %s\n' "$workspace"
printf '\n'
printf '  実施するシナリオ:\n'
printf '    1. 代表的な正常系 (dry-run)\n'
printf '    2. 主要分岐の動作確認\n'
printf '    3. 対話モード誘導 (AskUserQuestion を発火する場合)\n'
printf '    4. エラーパス確認 (引数不正等)\n'
printf '\n'

if [[ "$whatif" == "false" ]]; then
  mkdir -p "$workspace"
fi

# Step 1: 代表的な正常系 (必ず dry-run / --whatif 等の副作用ゼロコマンドを使う)
invoke_demo_step \
  "代表的な正常系 (dry-run)" \
  "{ 例: bash scripts/main.sh --dry-run }" \
  "0"

# Step 2: 主要分岐 (引数違いで挙動が変わるブランチを実行)
invoke_demo_step \
  "主要分岐 A (例: --scope global)" \
  "{ 例: bash scripts/main.sh --scope global --dry-run }" \
  "0"

# Step 3: 対話モード誘導 (AskUserQuestion を含むスキルのみ)
write_section "Step: 対話モード誘導"
printf '  Claude Code セッションで以下を実行することで、AskUserQuestion 実発火を確認:\n'
printf '\n'
printf '    /your-command       # 引数なしで起動 → AskUserQuestion 発火\n'
printf '\n'
printf '  (本スクリプトからは UI を直接発火できないため誘導のみ)\n'

# Step 4: エラーパス (引数不正・前提不足等)
invoke_demo_step \
  "エラーパス (例: 不正引数)" \
  "{ 例: bash scripts/main.sh --scope INVALID }" \
  "1" \
  "true"

# --- 完了サマリ ---
write_section "デモ実行完了"
printf '\n'
printf '  承認確認時の論点 (ユーザに AskUserQuestion で問うべき項目):\n'
printf '    - 全 Step の標準出力に想定外のエラー/警告がないか\n'
printf '    - 副作用 (生成ファイル / 設定変更) が想定通りか\n'
printf '    - 対話モード誘導の UI 表示が読みやすいか\n'
printf '\n'
printf '  再現コマンド (この demo.sh 自体):\n'
if [[ "$whatif" == "true" ]]; then
  printf '    bash evals/demo.sh\n'
else
  printf '    bash evals/demo.sh --no-whatif\n'
fi
printf '\n'
printf '  ADR-032 に従い、これらの結果を AskUserQuestion で承認してから引き渡しに進むこと。\n'
