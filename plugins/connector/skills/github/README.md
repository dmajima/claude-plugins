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

## 導入手順

### 前提

- Claude Code + connector プラグインがインストール済み
- `gh` CLI がインストール済み
- `gh auth login` 済み、または `GH_TOKEN` / `GITHUB_TOKEN` 環境変数が設定済み（未認証でも起動可能。その場合はスキルが API を呼ぶ前に `gh auth login` を案内し、認証確立後に続行する）

### 起動方法

「使い方」のトリガーフレーズ / コマンドで自動起動します。追加のセットアップは不要です。

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
    ├── case-03_thread_resolve.md     # スレッド resolve（パターン A）
    ├── case-04_auth_failure.md       # gh CLI 未認証（案内 → 再確認 → 続行）
    ├── case-05_pr_comment_pattern_a.md       # PR 全体コメント（パターン A）
    ├── case-06_delegation_resolve.md # 委譲 resolve（パターン B）
    ├── case-07_pattern_a_read_pr.md  # PR 情報取得（パターン A）
    ├── case-08_subagent_read_pr.md   # サブエージェント読み取り（正常系）
    ├── case-09_subagent_credentials_missing.md # サブエージェント時の credentials_missing 返却
    └── case-10_api_auth_failed.md    # API 応答での 401/403（再認証 → 1 回再実行）
```
