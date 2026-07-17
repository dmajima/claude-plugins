# コマンド共通動作（code-review-standard / code-review-quick）

`/code-review-standard` と `/code-review-quick` の両コマンドで共通する動作を定義する。
各コマンドはレビュアー構成（動員する観点別スキルの種類と数）のみが異なり、
以下の動作はすべて **mode に関わらず同一** である。

---

## 共通動作

- 起動時の AskUserQuestion をスキップしてモードを直接採用する
- スコープ・PR/ブランチ/ファイルの確定はユーザー指示・`$ARGUMENTS` から判定する
- **PR レビュー時の PR コメント投稿は必須**（別途指示されない限り）。`pr-review` スキルが Step 7 でサマリースレッド + インラインコメントを投稿する
- **PR コメントのフォーマットは mode に関わらず統一**。`pr-review/references/comment-posting.md` に従い、standard / quick で同一形式で投稿される
- **PR レビューは worktree 分離環境で実施する**（ブラウザ閲覧のみで完了させない・メイン作業ディレクトリは変更しない）。詳細: `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/local-checkout-review.md`
- **別 PR 推奨は禁止**。本 PR の仕様・スコープから外れる指摘は「スコープ外指摘」セクションに分離する。詳細: `${CLAUDE_PLUGIN_ROOT}/references/scope-out-policy.md`
- **PR 外への影響禁止**: レビュー実行中、Work Item / Issue / Boards / 別 PR / Wiki / 通知システム等への書き込み操作は行わない（ユーザー明示要求時のみ例外）。詳細: `${CLAUDE_PLUGIN_ROOT}/references/scope-out-policy.md` セクション 1.5
- **完了前チェックリスト** を `pr-review` Step 7.5 で全項目通過させる。詳細: `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/completion-checklist.md`

## 共通実行手順

1. `$ARGUMENTS` を解析し、**PR 識別子**（`https://...` PR URL / `PR #N` / `#N` / `azure:N`）が含まれるか判定する。判定ロジックの詳細は `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/pr-identifier-validation.md` を参照
2. **PR 識別子が含まれる場合**: `pr-review` スキルにフォワードする
   ```
   Skill(skill: "code-review:pr-review", args: "$ARGUMENTS mode=<MODE>")
   ```
   `pr-review` が Step 1〜8 の全フロー（メタ取得 → worktree → code-review 委譲 → PR コメント投稿 → 完了報告）を実行する。
3. **PR 識別子が含まれない場合**: `code-review` スキルを直接起動する
   ```
   Skill(skill: "code-review:code-review", args: "$ARGUMENTS mode=<MODE>")
   ```
   `code-review` スキルは Step 0（モード選択）の AskUserQuestion をスキップし、指定モードで Step 1 以降を実行する。
   結果はメインに統合サマリで返却される。

`<MODE>` は各コマンドが固定する値（`standard` または `quick`）に置き換える。

---

## 変更時の注意

共通動作を変更する場合は **本ファイルのみを修正** し、各コマンドファイルは変更しない。
各コマンドファイルに記載されるのは以下のみ:

- メタデータ（description / allowed-tools）
- レビュアー構成（本コマンド固有）
- 共通動作への参照（本ファイル）
- 使い方の例
- 適用場面（任意）
- モード変更の案内
