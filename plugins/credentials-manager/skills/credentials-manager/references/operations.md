# 管理操作仕様（save / update / delete / repair）

`credentials-manager` スキルの **書き込み系** 操作の詳細仕様。SKILL.md 実行フロー step 3 / 4 / 5 / 6 から参照される。参照系（retrieve / list / auto-match / proactive-detect）は `../../credentials-reader/references/` を参照のこと。

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
| 3 | 親ディレクトリ作成 + `.gitignore` 登録確認（リポジトリ内の場合） |
| 4 | 識別名が文脈から特定できなければ `AskUserQuestion` でユーザに確認 |
| 5 | 種別を推定（`sk-` → `api_key`、`ghp_` → `token`、`Bearer ` → `token`、人間入力 → `password` 等） |
| 6 | URL 提供あり → `urls` / `domains` / `auth_method` を自動抽出 |
| 7 | 同名既存エントリがあれば対話で確認（非対話モードはそのまま上書き） |
| 8 | エントリを追加（`created_at` / `updated_at` を現在時刻で設定） |
| 9 | ファイルに書き戻し（インデント 2、UTF-8、改行は既存ファイルに合わせる） |
| 10 | マスク済み値 + 保存パス + 関連ドメイン + スコープを表示して確認 |

### ユーザ表示例

```
Saved credential 'openai-api-key' (api_key)
  Value: sk-p****f456
  Path:  <repo_root>/.claude/.local/plugins/credentials-manager/credentials.json (project-scoped)
  Domains: api.openai.com
```

## 3. 編集（update）

| ステップ | 動作 |
|---------|------|
| 1 | パス解決 + 読み込み |
| 2 | 対象認証情報名を特定（曖昧なら `AskUserQuestion` で部分一致候補を提示） |
| 3 | 変更フィールドを `AskUserQuestion` で確認（`value` / `urls` / `domains` / `auth_method` / `description` / `type`） |
| 4 | 変更前 / 変更後の差分をマスク済み値で提示し、確認後に書き戻し |
| 5 | `updated_at` を現在時刻で更新（`created_at` は維持） |
| 6 | ファイルに書き戻し |
| 7 | 完了通知（変更フィールドのみ表示、未変更フィールドは省略） |

### 変更前/変更後の表示例

```
Updated credential 'openai-api-key':
  value:   sk-p****f456 → sk-q****g789
  domains: api.openai.com → api.openai.com, api.openai.azure.com
```

`value` 変更時は両方マスク表示。`urls` / `domains` 等は配列差分を表示。

## 4. 削除（delete）

| ステップ | 動作 |
|---------|------|
| 1 | パス解決 + 読み込み |
| 2 | 対象名を特定（曖昧なら `AskUserQuestion`） |
| 3 | 対話モード時は削除前確認（マスク済み値・関連ドメイン・更新日を提示） |
| 4 | エントリ削除 → ファイル書き戻し |
| 5 | 削除完了通知（フル値非表示） |

### 削除確認例

```
[credentials-manager] Confirm deletion:
  name:    openai-api-key
  type:    api_key
  value:   sk-p****f456
  domains: api.openai.com
  updated: 2026-04-10T12:34:00Z
```

## 5. 修復（repair、JSON 破損時）

| ステップ | 動作 |
|---------|------|
| 1 | パス解決 + 読み込み試行（JSON パースエラーが発生していること） |
| 2 | バックアップ作成: `credentials.json.bak.{ISO8601-timestamp}`（パース失敗ファイルを退避） |
| 3 | 対話モード時は確認、非対話モードはそのまま再初期化 |
| 4 | 空ストア `{"credentials": {}}` でファイルを再作成 |
| 5 | バックアップパスと再初期化結果を通知 |

### 通知例

```
[credentials-manager] credentials.json was invalid. Created backup and reinitialized:
  backup: <path>/credentials.json.bak.20260508T103045Z
  store:  <path>/credentials.json (empty)
```

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
| `.gitignore` 未登録（リポジトリ内） | 警告 + 登録提案後に書き込み |
| 同名認証情報の上書き | 対話モードでは確認、非対話モードではそのまま上書き（`updated_at` 更新） |
| ディスク容量不足 | エラー通知 + 一時ファイルクリーンアップ |

## 9. 引き継ぎ元（credentials-reader）からの呼び出し

`credentials-reader` の以下フローから本スキルが起動される（[`../../credentials-reader/references/handoff.md`](../../credentials-reader/references/handoff.md)）:

| 引き継ぎ契機 | 起動時の操作 |
|------------|-----------|
| 0 件マッチ後の保存承諾 | save（マスク済み候補名・推定ドメインを受け取り、不足は AskUserQuestion） |
| プロアクティブ検出後の保存承諾 | save（同上） |
| JSON パース失敗時の修復 | repair |

引き継ぎ時にフル値を受け取らない場合（reader 側がマスク化のみを渡す）は、`AskUserQuestion` でユーザに値を再入力してもらう。
