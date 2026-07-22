# PR レビュー完了前チェックリスト（必須）

`pr-review` スキルが PR レビューを **完了報告** する前に、各手順の実施とルール順守状況を確認するチェックリスト。
**全項目通過しない限り完了報告してはならない**。未通過項目は解消してから再度通過確認する。

> **位置付け**: `pr-review` スキル Step 7（コメント投稿）と Step 8（完了報告）の間に挟む確認ステップ（Step 7.5）として運用。
> ブランチレビュー / ファイルレビュー（`code-review` 直接呼び出し）は本リストの一部のみ該当（PR コメント関連は対象外）。

> **本ファイルは索引です**。各チェックグループ詳細は同ディレクトリの詳細サブファイルに分割済み。
> 外部から `completion-checklist.md B-1.7` のように参照される識別子（グループ **A**〜**F**、
> 小項目 **B-1.7** / **B-1.8** 等）は下記「チェックグループマップ」に保持し、参照は本索引で解決できる。

## 詳細サブファイル

| サブファイル | 収録グループ |
|---|---|
| [completion-checklist-execution.md](completion-checklist-execution.md) | **A** レビュー実施手順 / **B** PR コメント投稿 / **C** ルール順守 |
| [completion-checklist-reporting.md](completion-checklist-reporting.md) | **D** 完了報告 / **E** 自動チェックの実装案 / **F** 未通過時の対応 |

---

## チェックグループマップ

### A. レビュー実施手順チェックリスト → [completion-checklist-execution.md](completion-checklist-execution.md)

| 小項目 | 収録項目 |
|---|---|
| A-0 | A-0-1〜A-0-4 |
| A-1 | A-1-1〜A-1-3 |
| A-2 | A-2-1〜A-2-7 |
| A-3 | A-3-1〜A-3-4 |
| A-4 | A-4-1〜A-4-6 |

### B. PR コメント投稿チェックリスト → [completion-checklist-execution.md](completion-checklist-execution.md)

| 小項目 | 収録項目 |
|---|---|
| B-1 | B-1-1〜B-1-11 |
| B-1.5 | B-1.5-1〜B-1.5-5 |
| B-1.6 | B-1.6-1〜B-1.6-4 |
| B-1.7 | B-1.7-1〜B-1.7-6 |
| B-1.8 | B-1.8-1〜B-1.8-5 |
| B-2 | B-2 / B-3 / B-4 |

### C. ルール順守チェックリスト → [completion-checklist-execution.md](completion-checklist-execution.md)

| 小項目 | 収録項目 |
|---|---|
| C-1 | C-1 / C-1.5 |
| C-2 | C-2 |
| C-3 | C-3 |

### D. 完了報告チェックリスト（Step 8）→ [completion-checklist-reporting.md](completion-checklist-reporting.md)

| 小項目 | 収録項目 |
|---|---|
| D | D-1〜D-14 |

### E. 自動チェックの実装案（任意・参照用サンプル集）→ [completion-checklist-reporting.md](completion-checklist-reporting.md)

| 小項目 | 収録項目 |
|---|---|
| E | E-1〜E-5（E-2.5 / E-4.5 含む） |

### F. チェックリスト未通過時の対応 → [completion-checklist-reporting.md](completion-checklist-reporting.md)

| 小項目 | 収録項目 |
|---|---|
| F | 対応表 |

---

## 7. 関連リファレンス

- `${CLAUDE_SKILL_DIR}/SKILL.md` — Step 7.5 として本リストを組み込む
- `${CLAUDE_SKILL_DIR}/references/local-checkout-review.md` — worktree 利用手順
- `${CLAUDE_PLUGIN_ROOT}/references/comment-sanitization.md` — 投稿前サニタイズチェックリスト
- `${CLAUDE_PLUGIN_ROOT}/references/scope-out-policy.md` — 別 PR 推奨の禁止
- `${CLAUDE_PLUGIN_ROOT}/skills/code-review/references/template/output/review-summary.md` — サマリー本文の統一テンプレート
