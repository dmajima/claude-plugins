# credentials-manager skill

Claude Code セッションをまたいで認証情報を管理するスキル。URL/ドメイン関連付けによる自動適用、プロアクティブ検出、保存先スコープ自動解決を提供する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキル動作の本体は `SKILL.md` および `references/` 配下を参照してください。

## 導入手順

### 前提

- Claude Code がインストール済み
- `credentials-manager` プラグイン（このスキルを含む）がインストール済み
- 依存プラグインなし

### 起動方法

以下のフレーズで自動起動します。

明示要求:

- 「OpenAI の API キー `sk-...` を保存して」
- 「保存してある認証情報を一覧表示して」
- 「`openai-api-key` を削除して」
- 「先ほど保存したキーで API を叩いて」

暗黙トリガー（**グローバルルール `~/.claude/rules/security/credentials-management.md` 不在環境でも自動起動**）:

- 「`https://api.example.com/v1/users` から取得して」
- 「`curl https://api.github.com/user` を実行して」
- 「`gh api users/me` を叩いて」
- WebFetch / Python requests / Node fetch 等で外部 URL にアクセスする任意の指示

会話中に `sk-...` `ghp_...` `xoxb-...` `Bearer eyJhbG...` 等の認証情報パターンを検出した場合も保存提案として起動します。

## 利用方法

### 最小例

ユーザ:
> OpenAI の API キー `sk-proj-abcdefghij1234567890` を保存して

Claude（要約）:
> `openai-api-key` として保存しました（api_key）。値: `sk-p****7890` 保存先: `<repo>/.claude/.local/plugins/credentials-manager/credentials.json`（project-scoped）

### 応用例

| 目的 | フレーズ | 動作 |
|-----|---------|------|
| URL アクセス時の自動適用 | 「`https://api.openai.com/v1/models` から取得して」 | 保存済み認証情報を URL/ドメインで自動マッチして適用 |
| 複数件ヒット時の選択 | 「`https://api.example.com/v1/users` にアクセス」（同ドメイン認証情報が 2 件） | `AskUserQuestion` でどれを使うか確認 |
| 0 件時の確認 | 「`https://api.unknown-service.com/...`」 | 「認証情報を提供しますか?」と確認 |
| プロアクティブ検出 | 「キーは `ghp_xxxxxxxx`」 | 認証情報パターン検出 → 保存提案 |
| 一覧 | 「保存してある認証情報を一覧表示」 | 表形式でマスク済み値を表示 |
| 削除 | 「`openai-api-key` を削除」 | 対象エントリを削除（対話モードでは要確認） |

## 動作要件

| 要件 | 内容 |
|-----|------|
| Claude Code | 任意の最新版 |
| 外部 CLI | 不要 |
| 外部プラグイン依存 | なし |

## カスタマイズ・拡張

| 観点 | 拡張ポイント |
|-----|------------|
| 保存先のスコープ | リポジトリ内の場合は project-scoped（`<repo>/.claude/.local/plugins/credentials-manager/credentials.json`）、外なら user-scoped（`~/.claude/.local/plugins/credentials-manager/credentials.json`）を自動選択 |
| `auth_method` の既定 | `header:Authorization:Bearer`。サービス固有の方式が必要なら `header:X-API-Key:` 等を保存時に指定 |
| URL ワイルドカード | `urls[]` で末尾 `*` および中間 `*` を利用可能（`references/auto-match.md` 参照） |

## ファイル構成

```text
skills/credentials-manager/
├── SKILL.md                # スキル定義（Claude が読む）
├── README.md               # このファイル
├── references/
│   ├── operations.md       # 保存・取得・一覧・削除の詳細仕様
│   ├── auto-match.md       # URL 自動マッチ仕様
│   └── security.md         # セキュリティ注意・制約
└── evals/
    ├── README.md
    ├── case-01_save_with_url.md
    ├── case-02_list_credentials.md
    ├── case-03_proactive_detect.md
    ├── case-04_auto_match_single.md
    ├── case-05_auto_match_multiple.md
    ├── case-06_auto_match_none.md
    ├── case-07_delete_with_confirm.md
    ├── case-08_non_interactive.md
    ├── case-09_retrieve_found.md
    ├── case-10_retrieve_not_found.md
    ├── case-11_json_parse_error.md
    ├── case-12_user_scoped_save.md
    └── case-13_gitignore_warning.md
```

## 関連ドキュメント

| 用途 | 参照先 |
|-----|------|
| プラグイン全体の概要 | `../../README.md` |
| 操作詳細 | `references/operations.md` |
| 自動マッチ仕様 | `references/auto-match.md` |
| セキュリティ注意 | `references/security.md` |

## 設計上の特徴

- **グローバルルール非依存**: SKILL.md description で URL/API アクセス時の自動起動条件を定義しているため、利用者環境にグローバルルールが無くても自動的に認証情報問い合わせ先として機能する
- **install スコープ自動解決**: ワーキングディレクトリに `.git` があればプロジェクト単位、無ければユーザー単位を自動選択
- **平文保存（ローカル開発用途）**: 本番秘匿情報運用は対象外。`references/security.md` 参照
