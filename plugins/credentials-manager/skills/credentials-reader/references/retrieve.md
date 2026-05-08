# 取得・一覧の操作仕様（retrieve / list）

`credentials-reader` スキルの参照系操作の詳細仕様。SKILL.md 実行フロー step 3 / 5 から参照される。

## 1. ストアファイル形式（参照）

`credentials.json`（JSON / UTF-8 / BOM なし）。スキーマは `credentials-manager` 側 `references/operations.md` を参照する。本スキルはこのファイルを **読み取り専用** で扱う。

主要フィールド:

| フィールド | 用途 |
|----------|-----|
| `type` | `api_key` / `token` / `password` / `custom` |
| `value` | 秘密値（フル文字列）。会話出力時はマスクして提示する |
| `description` | 用途説明（人間可読） |
| `urls` / `domains` | 自動マッチ対象 |
| `auth_method` | 適用方法（既定 `header:Authorization:Bearer`） |
| `created_at` / `updated_at` | ISO 8601 タイムスタンプ |

## 2. 取得（retrieve）

| ステップ | 動作 |
|---------|------|
| 1 | パス解決 + 読み込み（ファイル不在時は空ストアとして処理） |
| 2 | 名前で検索（大文字小文字無視・部分一致可） |
| 3 | 単一ヒット → フル値を取得し呼び出し元タスクで利用 |
| 4 | 複数ヒット → `AskUserQuestion` で対象を確認（マスク済み値を併記） |
| 5 | ヒットなし → ユーザに保存提案、承諾なら `credentials-manager` へ引き継ぎ（[`handoff.md`](handoff.md) 参照） |
| 6 | ユーザへの応答にフル値を含めない（マスク済み値のみ） |

### ユーザ表示例

```
Using stored credential 'openai-api-key' (sk-p****f456) for api.openai.com.
```

## 3. 一覧（list）

| ステップ | 動作 |
|---------|------|
| 1 | パス解決 + 読み込み |
| 2 | 表形式で表示: 名前 / 種別 / 説明 / 関連ドメイン / マスク値 / 更新日時 |
| 3 | 表の下にスコープ（project-scoped or user-scoped）と保存パスを併記 |

### 出力例

```
[credentials-manager] Stored credentials (project-scoped):
| name              | type    | domains              | masked       | updated_at           |
|-------------------|---------|----------------------|--------------|----------------------|
| openai-api-key    | api_key | api.openai.com       | sk-p****f456 | 2026-04-10T12:34:00Z |
| github-token      | token   | api.github.com       | ghp_****xxxx | 2026-04-12T08:11:00Z |
Path: <repo_root>/.claude/.local/plugins/credentials-manager/credentials.json
```

## 4. マスキング規則

| 値の長さ | マスク表現 |
|--------|----------|
| 9 文字以上 | `<先頭4文字>****<末尾4文字>` |
| 8 文字以下 | 全マスク `****`（部分露出は禁止） |

## 5. 例外処理

| 状況 | 動作 |
|-----|------|
| `credentials.json` 不在 | 空ストアとして処理（list は「保存済み認証情報はありません」と返す、retrieve は保存提案へ） |
| JSON パース失敗 | エラー通知 + `credentials-manager` への引き継ぎを提案（書き込み修復は本スキル責務外） |
| 親ディレクトリ不在 | 参照のみのため作成しない。`credentials-manager` 起動時に作成される |
