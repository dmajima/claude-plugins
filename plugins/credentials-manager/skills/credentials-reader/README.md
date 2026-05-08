# credentials-reader

保存済み認証情報の **参照（取得・一覧・自動マッチ・プロアクティブ検出）** に特化した軽量スキル。`credentials-manager` プラグインに同梱され、PreToolUse / UserPromptSubmit フックから最優先で起動される。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキル動作本体は `SKILL.md` および `references/` 配下を参照してください。

## 役割

| 機能 | 説明 |
|-----|------|
| URL/ドメイン自動マッチ | リクエスト URL から保存済み認証情報を検索し、ヒット時は `auth_method` に従って自動適用 |
| 取得（retrieve） | 識別名（部分一致）から保存済み値を取り出し、API 呼び出しに利用 |
| 一覧（list） | 表形式で保存済み認証情報を表示（マスク済み値） |
| プロアクティブ検出 | 会話中の認証情報パターン（`sk-` `ghp_` `xoxb-` `Bearer` 等）を検出し、保存提案 |
| 引き継ぎ判断 | 書き込みが必要になった場合 `credentials-manager` へ引き継ぎ |

## 責務外

| 業務 | 担当 |
|-----|-----|
| 認証情報の追加・編集・削除（書き込み） | [`credentials-manager`](../credentials-manager/SKILL.md) |
| メニューUIによる対話的な管理 | [`/credentials-manager:manage`](../../commands/manage.md) |

## 起動契機

- ユーザが URL / API エンドポイントへのアクセスを依頼した場合（暗黙トリガー）
- `Bash` で `curl` / `wget` / `gh api` 等を呼び出す場合（PreToolUse フック経由）
- 会話中に認証情報パターンが検出された場合（UserPromptSubmit フック経由）
- 認証情報系ファイル（`.env` / `id_rsa` / `*.pem` 等）を読み書きする場合（PreToolUse フック経由）
- ユーザが「保存済みを一覧」「前のキーで API を叩いて」等と要求した場合（明示要求）

## 利用例

ユーザ:
> https://api.openai.com/v1/models から取得して

Claude（要約）:
> 保存済み認証情報 `openai-api-key` (`sk-p****f456`) を `api.openai.com` に自動適用しました。

## ファイル構成

```text
skills/credentials-reader/
├── SKILL.md
├── README.md
├── references/
│   ├── retrieve.md         # 取得・一覧の操作仕様
│   ├── auto-match.md       # URL 自動マッチ仕様
│   ├── handoff.md          # credentials-manager への引き継ぎ仕様
│   └── security.md         # セキュリティ注意（参照系）
└── evals/
    ├── README.md
    ├── case-01_auto_match_single.md
    ├── case-02_auto_match_multiple.md
    ├── case-03_auto_match_none.md
    ├── case-04_retrieve_found.md
    ├── case-05_retrieve_not_found.md
    ├── case-06_list_credentials.md
    ├── case-07_proactive_detect.md
    ├── case-08_non_interactive_multi.md
    ├── case-09_localhost_skip.md
    └── case-10_json_parse_error.md
```

## 関連スキル

| スキル | 関係 |
|--------|------|
| [`credentials-manager`](../credentials-manager/SKILL.md) | 書き込み（追加・編集・削除）の引き継ぎ先 |
| [`/credentials-manager:manage`](../../commands/manage.md) | メニューUI で参照・追加・編集・削除を一括対話実行 |

## ライセンス

[MIT License](../../LICENSE) の下で配布されています。
