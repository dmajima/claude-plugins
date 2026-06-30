# github

GitHub の PR 操作を `gh` CLI および GitHub MCP ツール経由で行うコネクタスキル。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。

## 提供機能

| 機能 | 説明 |
|------|------|
| PR 情報取得 | PR メタ情報・変更ファイル一覧・差分・コミット履歴 |
| インラインコメント投稿 | ファイルパス・行範囲指定付きコメント（単一行 / 複数行） |
| Pending Review 一括投稿 | 複数のインラインコメントをまとめてレビューとして投稿 |
| PR 全体コメント投稿 | PR 全体宛のコメント（サマリースレッド等） |
| レビュースレッド取得 | GraphQL 経由でスレッド一覧・解決状態を取得 |
| スレッド resolve/unresolve | スレッドの解決・再オープン |
| 既存コメントへの返信 | PR コメント / レビューコメントへの返信 |

## 使い方

### コマンド経由

| コマンド | 操作 |
|---------|------|
| `/connector:github-read` | PR 情報取得・diff・スレッド一覧（読み取り専用） |
| `/connector:github-post` | コメント投稿・Pending Review・スレッド resolve |

### 他プラグインからの委譲呼び出し

```text
Skill(skill: "connector:github", args: "PR URL: https://github.com/owner/repo/pull/42 にインラインコメントを投稿。ファイル: src/auth.ts, 開始行: 30, 終了行: 35, commit: abc123, 本文: セキュリティ上の懸念。承認済み。")
```

## 呼び出しパターン

| パターン | 呼び出し元 | 安全ゲート |
|---------|-----------|-----------|
| A: ユーザー直接 | 自然言語 / コマンド | AskUserQuestion 承認必須 |
| B: 他プラグイン委譲 | code-review 等 | 「承認済み」明示時はスキップ可能 |

## 前提条件

- `gh` CLI がインストール済み
- `gh auth login` 済み、または `GH_TOKEN` / `GITHUB_TOKEN` 環境変数が設定済み

## ファイル構成

```
skills/github/
├── SKILL.md                          # スキル定義
├── README.md                         # 本ファイル（人間向けリファレンス）
├── references/
│   └── pr-operations.md              # PR 操作 API 詳細
└── evals/
    ├── README.md                     # ケース一覧
    ├── case-01_pr_inline_comment.md  # インラインコメント投稿（パターン A）
    ├── case-02_delegation_pending_review.md  # 委譲 Pending Review（パターン B）
    └── case-03_thread_resolve.md     # スレッド resolve（パターン A）
```
