# Case 05: PR 全体コメント投稿（パターン A）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "https://github.com/contoso/webapp/pull/42 に修正対応サマリを投稿して。本文: ## 修正対応サマリ ..." |
| 既存状態 | `gh auth status` 認証済み |

## 期待動作

1. パターン A と判別（ゲートスキップキーワードなし）
2. AskUserQuestion で承認を得る
3. `gh api repos/contoso/webapp/issues/42/comments --input -` で全体コメントを投稿
4. 署名を connector が自動付加（signatures.md のテンプレート）
5. 投稿成功を報告

## 分岐の根拠

パターン A での全体コメント投稿。Issues API 経由（GitHub では PR は Issue のサブタイプ）。
