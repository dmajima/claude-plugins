# Pattern E 修正完了確認・マッピング永続化・共通事項（scope-out-acknowledgment 詳細）

> **親索引**: [`scope-out-acknowledgment.md`](scope-out-acknowledgment.md) ｜ **対の詳細**（Pattern D スコープ外了承）: [`scope-out-pattern-d.md`](scope-out-pattern-d.md)
> 本ファイルは `scope-out-acknowledgment.md`（薄い索引）から分割した詳細（セクション 6 / 6.5 / 7 / 8 / 9 / 10）です。セクション番号は元ファイル準拠。Pattern D のステップ詳細（セクション 5.x）は `scope-out-pattern-d.md` を参照。

---

## 6. 観点別スキル・オーケストレーター連携

本処理は `pr-review` スキル単独で完結する（コードレビューを行わないため `code-review` への委譲不要）。
ただし、Finding ID → Thread ID マッピングは **初回レビュー時の Step 7** で `pr-review` が永続化する必要がある（後述 セクション7）。

---

## 6.5 再レビュー時の prev マッピング退避（必須）

`pr-review` Step 7.4 で `finding-thread-map.json` を保存する際、**直前のレビューラウンドのマッピングが既に存在する場合は `finding-thread-map.prev.json` にリネーム退避** してから新規マッピングを書き込む。これにより、completion-checklist.md E-2.5（再レビュー時の起算番号チェック）が前回最終 ID を機械的に取得できる。

### 退避手順（Step 7.4 開始時に必ず実行）

```bash
SESSION_DIR=".claude/.local/work/{yyyyMMdd_nn_summary}"
CURRENT_MAP="$SESSION_DIR/finding-thread-map.json"
PREV_MAP="$SESSION_DIR/finding-thread-map.prev.json"

# 既存マッピングがあれば prev へ退避（review_run > 1 の検出元）
if [ -f "$CURRENT_MAP" ]; then
  mv "$CURRENT_MAP" "$PREV_MAP"
  echo "前回マッピングを $PREV_MAP に退避（再レビュー第 $(jq -r '.review_run + 1' "$PREV_MAP") 回として処理）"
fi

# 新規マッピングを生成
jq -n --argjson run "$REVIEW_RUN" --arg sha "$HEAD_SHA" --arg pr "$PR_ID" \
  '{pr_id: $pr, head_sha: $sha, review_run: $run, mappings: []}' \
  > "$CURRENT_MAP"
# Step 7.4 の本処理で mappings[] に各 Finding ID を追記
```

### prev マッピングの利用箇所

| 利用先 | 用途 |
|------|------|
| completion-checklist.md E-2.5 | 再レビュー時の起算番号チェック（`PREV_MAX_ID = max(prev.mappings[].finding_id)` を取得して `+1` を期待値とする） |
| Pattern D 操作（本ファイル セクション5.1〜5.6） | 過去 Finding ID と現在の Finding ID の対応把握（解消判定セクションで「過去 ID」として参照） |

### 重要な制約

- **退避は最初の 1 回のみ**: prev.json が既に存在する場合、さらに古い prev は削除（履歴は最大 1 世代のみ保持）
- **review_run のインクリメント**: 退避後、新規 `finding-thread-map.json` の `review_run` は `prev.review_run + 1` に設定
- **退避失敗時**: `mv` が失敗した場合は新規マッピングを **書き込まず**、ユーザーに状況報告（誤って prev を上書きするリスクを防ぐ）

---

## 7. Finding ID → Thread ID マッピングの永続化（Step 7 拡張）

`pr-review` の Step 7（PR コメント投稿）完了時に、以下を **必ず** セッション作業領域に保存する:

```
{session_dir}/finding-thread-map.json
```

| フィールド | 内容 |
|-----------|------|
| `pr_id` | PR 番号 |
| `head_sha` | レビュー対象の head SHA（再レビュー時の整合確認用） |
| `review_run` | レビュー回数（第 N 回） |
| `mappings[]` | 各 Finding ID と PR スレッド情報の対応 |
| `mappings[].finding_id` | `CR-NNN` |
| `mappings[].thread_id` | PR ホスト固有のスレッド ID |
| `mappings[].comment_id` | 親コメント ID（reply 時に必要） |
| `mappings[].file_path` | 指摘ファイルパス |
| `mappings[].line_range` | `<開始>-<終了>` |
| `mappings[].severity` | Critical / High / Medium / Low |
| `mappings[].category` | スコープ判定（in/out）含むカテゴリ |
| `mappings[].title` | 指摘タイトル（PR コメント本文の冒頭からも復元可能） |

このマッピングは `ack-scope-out=` 引数受領時の Step 1 / `ack-fixed=` 引数受領時のセクション 8 で参照される。

---

## 8. Pattern E: ユーザー指示による修正完了確認（必須運用）

ユーザーが Finding ID を指定して **「修正してください」「対応してください」「全て対応して」** 等と指示し、**Claude がコードを実際に修正・コミットした場合**、対応スレッドの status を `fixed`（Azure DevOps）/ resolved（GitHub）に更新する。
**本ステップを省略して reply のみ投稿し status=active のまま放置することは禁止**（修正完了後にスレッドが解決にならない不具合の根本原因）。

### 8.1 引数仕様

```
Skill(skill: "pr-review",
      args: "<PR識別子> ack-fixed=CR-NNN[,CR-NNN...] commit=<sha>")
```

`ack-fixed=` を受領した場合、pr-review は通常レビューフロー（Step 1〜8）をスキップし、本セクションのフローのみ実行する。
`commit=<sha>` は Pattern E reply に明示リンクとして埋め込む修正コミットの SHA（必須）。

### 8.2 Pattern E の発火条件（自律判断ルール）

ユーザーが Skill 引数で明示指示しなくても、**以下のすべてを満たす場合は Claude 自身が自律的に Pattern E を発火する**:

1. ユーザーが「修正して」「対応して」「全て対応して」等の **修正指示** をチャットで明示
2. Claude が **対象 Finding ID に対応する修正コミットを作成済**（`git log` で確認可能）
3. 対象 PR にその修正が反映されている（push 済み or ローカル commit）
4. Finding ID → Thread ID マッピング（`finding-thread-map.json`）が利用可能

これらが成立した時点で、Claude は **追加のユーザー確認なしに** ack-fixed を実行する（修正完了の事実は確実なため）。

### 8.3 安全方針

| 項目 | 方針 |
|------|------|
| トリガー | ユーザー修正指示 + Claude による修正コミット作成（両方必須） |
| 修正コミットへのリンク | reply に **必ず明示リンク** で含める（実証ありを表す） |
| 自著限定 | 適用する（自著スレッドのみ。他者起票は触らない） |
| `auto-resolve=false` 指定 | 影響しない（修正コミットありで即時実行） |

### 8.4 reply テンプレート + status 更新

reply は `re-review-flow.md` セクション 3 Pattern E のテンプレを使用（修正コミット明示リンク必須）。
status 更新は Azure DevOps `{status: "fixed"}` PATCH / GitHub `resolveReviewThread` mutation。
詳細サンプルコードは Pattern A のセクション 5.1 / 5.2 と同一（status 値のみ `wontFix` → `fixed` に置換）。

### 8.5 完了報告

```
## 修正完了確認結果（Pattern E）
- CR-001 / Thread 193 → status=fixed（コミット [sha7](url) で対応）
- ...
- 最終状態: active インライン 0 件 / active サマリー 1 件 / ✅ サマリーのみ active 達成
```

### 8.6 禁止事項

- **修正コミット作成後に Pattern E を実行せず status=active のまま放置すること**（不具合の根本原因）
- 修正コミットへの明示リンクを reply に含めずに status を変更すること（実証なき変更）
- 他者起票のスレッドへ Pattern E を適用すること（自著限定違反）

---

## 9. 禁止事項（Pattern D / Pattern E 共通）

- ユーザーの明示指示なしに本処理を実行すること（Pattern D / E ともに自動判定禁止）
- 他者起票のスレッドを処理すること（自著限定）
- ステータス更新を実施したスレッドを **黙ってロールバック** すること（誤指定時は明示的にユーザー報告）
- マッピングが見つからない Finding ID を **勝手に類推** して処理すること（必ずユーザー報告して判断を仰ぐ）
- **Pattern E で修正コミットへの明示リンクを含めない reply を投稿すること**（実証なき status 変更の禁止）

---

## 10. 関連リファレンス

- `${CLAUDE_SKILL_DIR}/references/comment-status-policy.md` — 安全方針（Pattern A〜C + Pattern D セクション 0.5 + Pattern E セクション 0.5.E）
- `${CLAUDE_SKILL_DIR}/references/re-review-flow.md` — 4 パターン分岐 + 各 reply テンプレ
- `${CLAUDE_SKILL_DIR}/references/comment-posting.md` — Step 7 詳細実装（Finding ID マッピング永続化を含む）
- `${CLAUDE_SKILL_DIR}/references/completion-checklist.md` — 完了前チェックリスト（最終状態検証を含む）
- `${CLAUDE_PLUGIN_ROOT}/references/comment-resolution-judge.md` — 解消判定アルゴリズム（自動判定対象。本ファイルとは独立）
- `${CLAUDE_PLUGIN_ROOT}/references/scope-out-policy.md` — 別 PR 推奨禁止 / PR 外影響禁止
