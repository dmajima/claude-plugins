# 完了前チェックリスト: 自動チェックの実装案（グループ E・任意サンプル集）

> **索引（親）**: [completion-checklist.md](completion-checklist.md) / [completion-checklist-reporting.md](completion-checklist-reporting.md)
> 本ファイルは `pr-review` 完了前チェックリスト グループ **E**（自動チェックの実装案）の参照用サンプル集。
> **自動化を検討する場合にのみ Read する**（ランタイムでスキルから自動実行されない・将来対応）。

---

## E. 自動チェックの実装案（任意・参照用サンプル集）

> **位置付け**: 本セクションは **任意の実装案・参照用サンプル集** であり、ランタイムでスキルから自動実行されてはいない。Step 7.5 の手動チェックを補強したい場合、`scripts/check/run_completion_checks.sh` 等の独立スクリプトとして切り出して呼び出す（将来対応）。

`pr-review` スキル Step 7.5 として、以下のような検証を組み込むと安全性が高まる:

```bash
# E-1: 投稿前にサマリー本文の必須セクションが揃っているか確認
# H2 セクションは <details><summary> 折り畳み形式のため <summary> 行を検出する
# セクション 1〜3 は状態記号付き summary の完全形（>0 件は「N 件 ⚠」/ 0 件は「0 件 ✓ + 状態語」）で検証する
# （code-review/references/quality/checklist.md C-Auto-1 と同一方式）
required_sections=(
  "# 🤖 \[deep-code-review-plugin\] PR レビューサマリー"
  "<summary>1\. 対応が必要な指摘 （(0 件 ✓ 指摘なし|[1-9][0-9]* 件 ⚠)）</summary>"
  "<summary>2\. 改善提案 （(0 件 ✓ 該当なし|[1-9][0-9]* 件 ⚠)）</summary>"
  "<summary>3\. スコープ外指摘 （(0 件 ✓ 該当なし|[1-9][0-9]* 件 ⚠)）</summary>"
  "<summary>4\. 観点別の指摘なし"
  "<summary>5\. 観点間の見解の差異"
  "<summary>6\. 既存指摘の解消判定"
  "<summary>7\. 未確認事項・制約"
  "<summary>8\. 集計"
  "<summary>9\. レビュー実施環境"
)
for sec in "${required_sections[@]}"; do
  echo "$SUMMARY_BODY" | grep -qE "$sec" || echo "WARN: missing section: $sec"
done

# E-2: 別 PR 推奨文言が混入していないか確認
banned_patterns=(
  "別.*PR.*対応"
  "別途.*PR.*起票"
  "別チケット"
  "Issue を作成"
  "Work Item を作成"
  "ボードに追加"
)
for pat in "${banned_patterns[@]}"; do
  echo "$SUMMARY_BODY" | grep -qE "$pat" && echo "ERROR: banned phrase: $pat"
done

# E-2.5: Finding ID の重複・起算番号チェック
ids=$(echo "$SUMMARY_BODY" | grep -oE 'CR-[0-9]{3}' | sort)
duplicates=$(echo "$ids" | uniq -d)
[ -n "$duplicates" ] && echo "ERROR: 重複した Finding ID: $duplicates"

# 詳細補足見出しは HTML 記法（<h4>CR-NNN: ...</h4>）のため <h4> 行を数える
total_findings=$(echo "$SUMMARY_BODY" | grep -cE '<h4>CR-[0-9]{3}:')
unique_count=$(echo "$ids" | sort -u | wc -l)
first_id=$(echo "$ids" | sort -u | head -n 1 | sed 's/CR-//')
last_id=$(echo "$ids" | sort -u | tail -n 1 | sed 's/CR-//')

# 起算番号の判定（再レビュー時は前回最終 ID + 1 から開始）
PREV_MAX_ID=0
if [ -f "$SESSION_DIR/finding-thread-map.json" ]; then
  REVIEW_RUN=$(jq -r '.review_run // 1' "$SESSION_DIR/finding-thread-map.json")
  if [ "$REVIEW_RUN" -gt 1 ]; then
    # 前回の finding-thread-map.json から最大 ID を取得
    PREV_MAP="$SESSION_DIR/finding-thread-map.prev.json"
    if [ -f "$PREV_MAP" ]; then
      PREV_MAX_ID=$(jq '[.mappings[].finding_id | ltrimstr("CR-") | tonumber] | max // 0' "$PREV_MAP")
    fi
  fi
fi

# 起算番号の検証
if [ -n "$first_id" ]; then
  expected_first=$(printf "%03d" "$((PREV_MAX_ID + 1))")
  if [ "$first_id" != "$expected_first" ]; then
    if [ "$PREV_MAX_ID" -eq 0 ]; then
      echo "ERROR: 初回レビューだが起算番号が CR-001 ではない（実際: CR-$first_id）"
    else
      echo "ERROR: 再レビュー（review_run > 1）だが起算番号が CR-$expected_first ではない（実際: CR-$first_id / 前回最終: CR-$(printf '%03d' $PREV_MAX_ID)）"
    fi
  fi
fi

# 連続性チェック（first_id 〜 last_id まで欠番なく連続しているか）
if [ -n "$first_id" ] && [ -n "$last_id" ]; then
  expected_count=$((10#$last_id - 10#$first_id + 1))
  if [ "$unique_count" -ne "$expected_count" ]; then
    echo "WARN: ID が CR-$first_id〜CR-$last_id の範囲で連続していない（実際 $unique_count 件 / 期待 $expected_count 件・欠番の可能性）"
  fi
fi

# E-4.5: 同一 Finding ID の重複スレッド検出（connector 経由）
# 429 リトライ等で同じ CR-NNN ラベルを持つスレッドが PR 上に複数残っていないか
# Azure DevOps: connector:azure にスレッド一覧を取得させ、pr-review 側で重複チェック
# GitHub: connector:github にスレッド一覧を取得させ、pr-review 側で重複チェック
#
# 呼び出し例:
#   Skill(skill: "connector:azure", args: "読み取りのみ。PR URL: <PR_URL> のスレッド一覧を取得して")
#   Skill(skill: "connector:github", args: "読み取りのみ。PR URL: <PR_URL> のレビュースレッド一覧を取得して")
#
# 取得結果から Finding ID（CR-NNN）を抽出し、同一 ID が複数スレッドに存在する場合は警告。
# 重複検出時: 旧スレッドを closed/resolve にするか、http-error-handling.md セクション4.5 の幂等ガードを確認

# E-5: PR の最終状態（サマリーのみ active）の検証（connector 経由）
# Azure DevOps: connector:azure にスレッド一覧を取得させ、active inline / active summary を集計
# GitHub: connector:github にスレッド一覧を取得させ、isResolved == false のインラインスレッドを集計
#
# 呼び出し例（E-4.5 と同じスレッド一覧を再利用可能）:
#   Skill(skill: "connector:azure", args: "読み取りのみ。PR URL: <PR_URL> のスレッド一覧を取得して")
#   Skill(skill: "connector:github", args: "読み取りのみ。PR URL: <PR_URL> のレビュースレッド一覧を取得して")
#
# 判定:
#   - active インライン == 0 && active サマリー == 1 → OK
#   - active インライン > 0 → 警告（未 closed のインラインスレッド残存）
#   - active サマリー > 1 → 警告（旧サマリーが closed されていない可能性）
  if [ "$ACTIVE_INLINE" -eq 0 ]; then
    echo "✅ active なインラインスレッドなし（サマリースレッドのみ）"
  else
    echo "⚠️ active インラインスレッド残: $ACTIVE_INLINE 件"
  fi
fi

# E-4: PR 外リソースへの書き込みコマンドが allowed-tools に含まれていないか確認
banned_tools=(
  "gh issue create"
  "az boards work-item create"
  "az repos create"
  "gh repo create"
)
for tool in "${banned_tools[@]}"; do
  grep -rE "$tool" "${CLAUDE_PLUGIN_ROOT}/skills/" "${CLAUDE_PLUGIN_ROOT}/agents/" 2>/dev/null \
    | grep -i "allowed-tools" && echo "ERROR: banned tool in allowed-tools: $tool"
done

# E-3: メインリポジトリの状態確認（worktree 不変条件）
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
echo "メインリポジトリ: ${CURRENT_BRANCH} @ $(git rev-parse --short HEAD)"
WORKTREE_BASE=".claude/.local/plugins/deep-code-review/_worktree"
if [ -d "${WORKTREE_BASE}" ] && [ -n "$(ls -A "${WORKTREE_BASE}" 2>/dev/null)" ]; then
  echo "残存 worktree:"
  bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/worktree/list.sh" "$(git rev-parse --show-toplevel)"
fi
```
