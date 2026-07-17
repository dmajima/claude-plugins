# pr-review スキル

GitHub と Azure DevOps Git の両方に対応した PR レビュースキル。
PR の内容を読み取り、deep-code-review プラグインの観点別スキルでレビューし、
**該当範囲を選択した状態でコメントを追記**。
**未解決コメントの解消状態を確認** し、解消済みであれば該当指摘の **ステータスを更新**。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。
スキルが実行時に参照するのは `SKILL.md` と `references/` 配下です。

## 提供機能

| 機能 | 内容 |
|------|------|
| マルチホスト対応 | GitHub（`github.com`）/ Azure DevOps（`dev.azure.com` / TFS）の自動判定 |
| URL/ID 受領 | URL でも ID（`#123`）でも識別可能 |
| 範囲指定インラインコメント | `start_line`-`line` を指定して該当範囲にコメント追記 |
| 未解決コメントの解消確認 | コードの差分から解消判定し、ホスティングのネイティブステータスを更新 |
| ツール不足時の自動依頼 | `gh` / `az` / `azure-devops` 拡張不在時に env-setup スキルへ依頼 |
| code-review への委譲 | レビューロジックは code-review オーケストレーターに委譲して観点別並列実行 |

## 使い方

### トリガーフレーズ例

```
PR #123 をレビューして
https://github.com/owner/repo/pull/123 をレビュー
https://dev.azure.com/org/project/_git/repo/pullrequest/45 をレビュー
PR #45 を簡易レビューして
PR #123 の未解決コメントを確認して
```

### モード指定

```
PR #123 をレビューして  mode=standard   # 既定
PR #123 をレビューして  mode=quick      # 簡易モード
```

### 必要な認証

| ホスト | 必要なもの |
|--------|----------|
| GitHub | `gh auth login` 済み、または `GITHUB_TOKEN` / `GH_TOKEN` 環境変数 |
| クラウド Azure DevOps（dev.azure.com） | `az login` 済み（MS アカウント・推奨）、または `AZURE_DEVOPS_EXT_PAT` 環境変数（Code+PR の R/W スコープ） |
| **オンプレ TFS Server**（自社 TFS） | **NTLM 認証**（credentials-manager プラグインで `tfs-password` エントリを登録。connector が標準ストア `.claude/.local/plugins/credentials-manager/credentials.json` から解決）。**PAT 不要・既存ドメインアカウントで動作**。詳細はプラグインルート README の「オンプレ TFS Server の NTLM 認証セットアップ」、および `references/azure-devops-tfs-ntlm.md` を参照 |

## ファイル構成

```
plugins/deep-code-review/skills/pr-review/
├── SKILL.md                              # Claude が実行時に読むスキル定義
├── README.md                             # 本ファイル（人間向け）
└── references/
    ├── github.md                         # GitHub PR 操作詳細
    ├── azure-devops.md                   # Azure DevOps PR 操作詳細
    └── comment-status.md                 # コメントステータス管理（解消判定）
```

## 動作フロー

1. PR 識別子からホストを判定
2. 必要な外部ツール（gh / az / azure-devops 拡張）の存在確認
3. 不足があれば env-setup スキルへインストール依頼
4. PR メタ情報・差分・スレッドを取得
5. 未解決コメントの解消判定 → ネイティブステータス更新
6. code-review オーケストレーターへレビュー委譲（観点別スキル並列実行）
7. レビュー結果を PR に行範囲指定で追記
8. 完了報告

## カスタマイズ

### 解消判定ロジックの調整

`references/comment-status.md` に判定アルゴリズムが記載されている。
調整パラメータ（`confidence_threshold` / `auto_resolve_categories` / `dry_run`）は現状ハードコード。
必要に応じて `SKILL.md` に引数を追加すること。

### コメント追記フォーマットの変更

`references/github.md` / `references/azure-devops.md` のコマンド例を変更する。

### 新しいホスト（GitLab / Bitbucket 等）への対応

1. `SKILL.md` の対応ホスト表に追加
2. `references/<host>.md` を新規作成
3. ホスト判定ロジックに URL パターン追加
4. `env-setup` スキルの管理対象ツールに必要な CLI を追加

## スコープ外

- PR のマージ・クローズ・承認（人間が実施）
- 認証情報の自動取得・保存
- バグ修正の実装（指摘提示のみ）
- リポジトリのセットアップ・ブランチ保護設定

## 関連スキル

- `code-review` — オーケストレーター（モード選択・観点別スキル統合）
- `code-review-implementation` / `code-review-testing` / `code-review-security` / `code-review-architecture` / `code-review-frontend` — 観点別レビュー
- `env-setup` — 必要外部ツールのインストール
