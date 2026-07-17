# PR レビュー完了前チェックリスト（必須）

`pr-review` スキルが PR レビューを **完了報告** する前に、各手順の実施およびルールの順守状況を確認するチェックリスト。
**全項目通過しない限り完了報告してはならない**。未通過項目があれば、その項目を解消してから再度通過確認を行う。

> **位置付け**: `pr-review` スキル Step 7（コメント投稿）と Step 8（完了報告）の間に挟む確認ステップ（Step 7.5）として運用する。
> ブランチレビュー / ファイルレビュー（`code-review` 直接呼び出し）は本リストの一部のみが該当する（PR コメント関連は対象外）。

> **本ファイルは索引です**。各チェックグループの詳細は同ディレクトリの詳細サブファイルに分割済み。
> 外部から `completion-checklist.md B-1.7` のように参照される識別子（グループ **A**〜**F**、
> 小項目 **B-1.7** / **B-1.8** 等）は下記「チェックグループマップ」に保持しており、参照は本索引で解決できる。

## 詳細サブファイル

| サブファイル | 収録グループ |
|---|---|
| [completion-checklist-execution.md](completion-checklist-execution.md) | **A** レビュー実施手順 / **B** PR コメント投稿 / **C** ルール順守 |
| [completion-checklist-reporting.md](completion-checklist-reporting.md) | **D** 完了報告 / **E** 自動チェックの実装案 / **F** 未通過時の対応 |

---

## チェックグループマップ

### A. レビュー実施手順チェックリスト → [completion-checklist-execution.md](completion-checklist-execution.md)

| 小項目 | 内容（要約） | 収録項目 |
|---|---|---|
| A-0 | フロー自動進行チェック（Step 8 完了報告前・ユーザー入力を待たない自動進行の確認） | A-0-1〜A-0-4 |
| A-1 | スコープ確定（Step 1：PR 識別子バリデーション・ホスト判定・認証事前確認 Step 1.5） | A-1-1〜A-1-3 |
| A-2 | worktree 環境（Step 5.5：作成/更新・HEAD 一致・同等性・ビルド確認・削除/維持） | A-2-1〜A-2-7 |
| A-3 | レビュー本体（Step 6：観点別レビュー委譲・規約/仕様読込・モード確定） | A-3-1〜A-3-4 |
| A-4 | 既存指摘の解消判定（再レビュー時のみ・Pattern A/C 分類・自著判定・marker 指定） | A-4-1〜A-4-6 |

### B. PR コメント投稿チェックリスト → [completion-checklist-execution.md](completion-checklist-execution.md)

| 小項目 | 内容（要約） | 収録項目 |
|---|---|---|
| B-1 | コメント投稿要件（サマリー/インライン投稿・テンプレート準拠・投稿順序） | B-1-1〜B-1-11 |
| B-1.5 | Finding ID 採番要件（CR-NNN 連続採番・重複排除・再レビュー継番） | B-1.5-1〜B-1.5-5 |
| B-1.6 | Finding ID → Thread ID マッピング永続化（Pattern D 連携・保存パス明記） | B-1.6-1〜B-1.6-4 |
| B-1.7 | 最終状態（サマリースレッドのみ active・残スレッド一覧と推奨アクション） | B-1.7-1〜B-1.7-6 |
| B-1.8 | 修正完了確認（Pattern E・修正コミット後の status=fixed/resolved 化） | B-1.8-1〜B-1.8-5 |
| B-2 | コメント本文サニタイズ・コード引用・投稿先指定（SSOT: comment-sanitization.md 5.6） | B-2 / B-3 / B-4 |

### C. ルール順守チェックリスト → [completion-checklist-execution.md](completion-checklist-execution.md)

| 小項目 | 内容（要約） | 収録項目 |
|---|---|---|
| C-1 | 別 PR 推奨禁止 / PR 外影響禁止（scope-out-policy.md セクション1・1.5） | C-1 / C-1.5 |
| C-2 | 統合サマリの統一フォーマット（review-summary.md の 9 セクション + ヘッダブロック） | C-2 |
| C-3 | auto-resolve / 自著限定（auto-resolve=false 時の status 非更新） | C-3 |

### D. 完了報告チェックリスト（Step 8）→ [completion-checklist-reporting.md](completion-checklist-reporting.md)

| 小項目 | 内容（要約） | 収録項目 |
|---|---|---|
| D | 完了報告（異常・要対応 / サマリー / 詳細 の 3 層構成で提示） | D-1〜D-14 |

### E. 自動チェックの実装案（任意・参照用サンプル集）→ [completion-checklist-reporting.md](completion-checklist-reporting.md)

| 小項目 | 内容（要約） | 収録項目 |
|---|---|---|
| E | Step 7.5 を補強する検証スクリプト例（ランタイム自動実行なし・将来対応） | E-1〜E-5（E-2.5 / E-4.5 含む） |

### F. チェックリスト未通過時の対応 → [completion-checklist-reporting.md](completion-checklist-reporting.md)

| 小項目 | 内容（要約） | 収録項目 |
|---|---|---|
| F | 未通過項目ごとの対応表（A-0-* / A-2-6 / A-2-7 / B-2-* 〜 B-4-* / C-1-* 〜 C-3-* / D-* 等） | 対応表 |

---

## 7. 関連リファレンス

- `${CLAUDE_SKILL_DIR}/SKILL.md` — Step 7.5 として本リストを組み込む
- `${CLAUDE_SKILL_DIR}/references/local-checkout-review.md` — worktree 利用手順
- `${CLAUDE_PLUGIN_ROOT}/references/comment-sanitization.md` — 投稿前サニタイズチェックリスト
- `${CLAUDE_PLUGIN_ROOT}/references/scope-out-policy.md` — 別 PR 推奨の禁止
- `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/template/output/review-summary.md` — サマリー本文の統一テンプレート
