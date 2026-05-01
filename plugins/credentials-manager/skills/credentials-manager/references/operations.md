# 操作仕様（save / retrieve / list / delete）

`credentials-manager` スキルの各操作の詳細仕様。SKILL.md 実行フロー step 3 / 4 / 6 / 7 から参照される。

## 1. ストアファイル形式

`credentials.json`（JSON / UTF-8 / BOM なし）:

```json
{
  "credentials": {
    "<credential-name>": {
      "type": "api_key | token | password | custom",
      "value": "<the secret value>",
      "description": "What this credential is for",
      "urls": ["https://api.example.com/v1/*"],
      "domains": ["api.example.com"],
      "auth_method": "header:Authorization:Bearer",
      "created_at": "ISO 8601 timestamp",
      "updated_at": "ISO 8601 timestamp"
    }
  }
}
```

### フィールド

| フィールド | 必須 | 内容 |
|----------|-----|------|
| `type` | 必須 | `api_key` / `token` / `password` / `custom` |
| `value` | 必須 | 秘密値（フル文字列） |
| `description` | 必須 | 用途の説明（人間可読） |
| `urls` | 任意 | 適用対象 URL パターンの配列。`*` ワイルドカード対応（例: `https://api.example.com/v1/*`） |
| `domains` | 任意 | 適用対象ドメインの配列（例: `api.example.com`）。URL 保存時に自動抽出 |
| `auth_method` | 任意 | 送信方法。書式: `header:<header-name>:<prefix>` または `query:<param-name>`。未指定時は `header:Authorization:Bearer` |
| `created_at` / `updated_at` | 必須 | ISO 8601 タイムスタンプ |

### `auth_method` の例

| 値 | HTTP 表現 |
|---|---------|
| `header:Authorization:Bearer` | `Authorization: Bearer <value>` |
| `header:X-API-Key:` | `X-API-Key: <value>` |
| `query:api_key` | `?api_key=<value>` |

## 2. 保存（save）

| ステップ | 動作 |
|---------|------|
| 1 | SKILL.md の手順で credentials.json パスを解決 |
| 2 | 既存ファイルを読み込み（不在なら空ストアで初期化） |
| 3 | 識別名が文脈から特定できなければ `AskUserQuestion` でユーザに確認 |
| 4 | 種別を推定（`sk-` → `api_key`、`ghp_` → `token`、`Bearer ` → `token`、人間入力 → `password` 等） |
| 5 | URL 提供あり → `urls` / `domains` / `auth_method` を自動抽出 |
| 6 | エントリを追加 or 更新（`updated_at` を現在時刻で更新） |
| 7 | ファイルに書き戻し（インデント 2、UTF-8、改行は既存ファイルに合わせる） |
| 8 | マスク済み値 + 保存パス + 関連ドメイン + スコープを表示して確認 |

### ユーザ表示例

```
Saved credential 'openai-api-key' (api_key)
  Value: sk-p****f456
  Path:  <repo_root>/.claude/.local/plugins/credentials-manager/credentials.json (project-scoped)
  Domains: api.openai.com
```

## 3. 取得（retrieve）

| ステップ | 動作 |
|---------|------|
| 1 | パス解決 + 読み込み |
| 2 | 名前で検索（大文字小文字無視・部分一致可） |
| 3 | 見つかった場合 → フル値を取得して呼び出し元タスクで利用 |
| 4 | ユーザへの応答にフル値を含めない（マスク済み値のみ） |
| 5 | 見つからない場合 → 候補名を提示してユーザに確認、または保存提案へ |

## 4. 一覧（list）

| ステップ | 動作 |
|---------|------|
| 1 | パス解決 + 読み込み |
| 2 | 表形式で表示: 名前 / 種別 / 説明 / 関連ドメイン / マスク値 / 更新日時 |
| 3 | 表の下にスコープ（project-scoped or user-scoped）と保存パスを併記 |

## 5. 削除（delete）

| ステップ | 動作 |
|---------|------|
| 1 | パス解決 + 読み込み |
| 2 | 対象名を特定（曖昧なら `AskUserQuestion`） |
| 3 | 対話モード時は削除前確認 |
| 4 | エントリ削除 → ファイル書き戻し |
| 5 | 削除完了通知（フル値非表示） |

## 6. マスキング規則

| 値の長さ | マスク表現 |
|--------|----------|
| 9 文字以上 | `<先頭4文字>****<末尾4文字>` |
| 8 文字以下 | 全マスク `****`（部分露出は禁止） |

## 7. install スコープと解決パスの対応

| インストール形態 | 解決パス | スコープ表示 |
|---------------|--------|----------|
| user-scope（リポジトリ外で利用） | `~/.claude/.local/plugins/credentials-manager/credentials.json` | user-scoped |
| project-scope（リポジトリ内で利用） | `<repo_root>/.claude/.local/plugins/credentials-manager/credentials.json` | project-scoped |
| local-scope | project-scope と同じ | project-scoped |

## 8. 例外処理

| 状況 | 動作 |
|-----|------|
| 親ディレクトリ作成失敗 | エラーメッセージ + ユーザへ権限確認依頼 |
| JSON パース失敗 | バックアップ（`credentials.json.bak.{timestamp}`）作成後、空ストアで再初期化 |
| 同名認証情報の上書き | 対話モードでは確認、非対話モードではそのまま上書き（`updated_at` 更新） |
