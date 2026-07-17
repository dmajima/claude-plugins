# 完了前チェックリスト詳細（D〜F）: 完了報告 / 自動チェックの実装案 / 未通過時の対応

> **索引（親）**: [completion-checklist.md](completion-checklist.md)
> 本ファイルは `pr-review` 完了前チェックリストの詳細サブファイル。グループ **D / E / F** を収録する。
> グループ **A / B / C** は [completion-checklist-execution.md](completion-checklist-execution.md) を参照。

---

## D. 完了報告チェックリスト（Step 8）

> **報告の提示構造（必須）**: D-1〜D-14 の項目を平坦に列挙せず、以下の 3 層で構成する。
> 1. **異常・要対応**（最上部）: 失敗件数（D-4/D-7）・未達事項（D-14 の残スレッド）・SKIPPED（D-9）など、ユーザーの対応が必要な項目のみ。ゼロ件なら「異常なし」と 1 行
> 2. **サマリー**: 件数系（D-2/D-3/D-5/D-6/D-13）+ モード（D-1）+ auto-resolve 状態（D-8）を表 1 つに集約
> 3. **詳細**: 残りの宣言・トレース項目（D-10〜D-12 等）

```
[ ] (D-1) レビューモード（standard / quick）が報告に含まれている
[ ] (D-2) 検出した指摘件数（Critical / High / Medium / Low / スコープ外）が報告に含まれている
[ ] (D-3) PR にコメント追記した件数（インライン / サマリー）が報告に含まれている
[ ] (D-4) コメント追記の失敗件数があれば、理由・対象ファイル・対象行を含めている
[ ] (D-5) 解消確認した未解決コメント件数（resolve / fixed に更新した件数）が報告に含まれている
[ ] (D-6) スキップした未解決コメント（解消判定不能なもの）が報告に含まれている
[ ] (D-7) ステータス更新の失敗件数があれば、理由を含めている
[ ] (D-8) `auto-resolve=false` 指定時は dry-run 状態を明示している
[ ] (D-9) worktree の作成・更新 / SKIPPED 状況が報告に含まれている
[ ] (D-10) worktree の削除 / 維持状況が報告に含まれている
[ ] (D-11) PR 外のリソース（Work Item / Issue / Boards / 通知 / Wiki 等）への書き込みを行っていない旨を宣言している（または例外実行時はその対象・内容を明記している）
[ ] (D-12) Finding ID → Thread ID マッピングの保存先（finding-thread-map.json）が完了報告に含まれている
[ ] (D-13) PR の最終状態（active なインラインスレッド件数 / サマリースレッド active 件数）が完了報告に含まれている
[ ] (D-14) 「サマリーのみ active」状態を達成した場合は明示的に達成宣言、未達の場合は残スレッド一覧と推奨アクションを記載している
```

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

---

## F. チェックリスト未通過時の対応

| 未通過項目 | 対応 |
|----------|------|
| A-0-*（フロー自動進行違反） | 停止箇所と原因を完了報告の「未確認事項・制約」に記載し、残りのステップを自動で完了する |
| A-2-6 / A-2-7（worktree 処理） | レビュー判定に応じた worktree 処理（削除 or 維持）を確認 |
| B-2-* / B-3-* / B-4-*（コメント本文未サニタイズ） | サニタイズ・エスケープを再適用してから再投稿 |
| C-1-*（別 PR 推奨混入） | 該当箇所を「スコープ外」セクションに移動・文言を修正してから再投稿 |
| C-2-*（フォーマット不一致） | テンプレートに従い見出し・順序を修正してから再投稿 |
| C-3-*（auto-resolve 方針違反） | 既に status 更新済みの場合は手動でロールバックは行わず、ユーザーに状況報告 |
| D-*（完了報告の不備） | 不足項目を補ってから再報告 |

---

> **前半（A〜C）**: [completion-checklist-execution.md](completion-checklist-execution.md)
> **索引に戻る**: [completion-checklist.md](completion-checklist.md)
