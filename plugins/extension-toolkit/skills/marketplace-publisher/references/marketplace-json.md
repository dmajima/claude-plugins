# marketplace.json 更新仕様

`.claude-plugin/marketplace.json` の `plugins[]` 配列を更新する際のルール。

## ファイルパス

```
<repo-root>/.claude-plugin/marketplace.json
```

## エントリ追加（新規プラグイン）

`plugins[]` に以下の形式で要素を追加:

```json
{
  "name": "{plugin-name}",
  "source": "./plugins/{plugin-name}",
  "description": "{プラグインの 1 行説明}"
}
```

### 必須フィールド

| フィールド | 内容 |
|----------|------|
| `name` | プラグイン名（plugin.json の `name` と一致） |
| `source` | リポジトリルートからの相対パス |
| `description` | 1 行説明 |

### 任意フィールド

| フィールド | 内容 |
|----------|------|
| `keywords` | 検索キーワード配列（plugin.json と同期推奨） |
| `category` | カテゴリ分類（必要時） |

## エントリ更新（既存プラグイン）

| 変更可 | 変更内容 |
|-------|---------|
| `description` | 1 行説明の修正 |
| `source` | パス変更（プラグイン移動時） |
| `keywords` | キーワード追加・削除 |

| 変更不可 | 理由 |
|---------|------|
| `name` | 識別子のため、変更時は削除 + 別 name で新規追加扱い |
| `version` | marketplace.json には書かない（plugin.json で管理） |

## エントリ削除

プラグイン自体を削除する場合のみ。`plugins/{plugin-name}/` ディレクトリも合わせて削除する必要があるため **必ずユーザに確認**。

```text
プラグイン `{plugin-name}` をマーケットプレイスから削除します:

- marketplace.json のエントリ削除
- plugins/{plugin-name}/ ディレクトリ削除

実行しますか？（yes/no）
```

## 並び順

`plugins[]` は **アルファベット順** に並べる（メンテナンス性のため）。

## 更新前の確認

1. 同名のエントリがすでに存在しないか
2. 現在の JSON が valid（パース確認）
3. `source` パスが実在するか

## 更新後の確認

1. JSON が valid
2. 追加・変更したエントリの内容を diff としてユーザに提示

## 例

### 追加前

```json
{
  "name": "dmajima-claude-plugins",
  "owner": { "name": "dmajima" },
  "description": "dmajima 個人用 Claude Code プラグインマーケットプレイス",
  "plugins": []
}
```

### `extension-toolkit` を追加後

```json
{
  "name": "dmajima-claude-plugins",
  "owner": { "name": "dmajima" },
  "description": "dmajima 個人用 Claude Code プラグインマーケットプレイス",
  "plugins": [
    {
      "name": "extension-toolkit",
      "source": "./plugins/extension-toolkit",
      "description": "Claude Code の各種拡張要素の作成からマーケットプレイス公開までを支援するツールキット"
    }
  ]
}
```

## エンコーディング・改行コード

既存 `marketplace.json` のエンコーディング・改行コードを維持する（`~/.claude/rules/common/file-encoding.md`）。通常は UTF-8（BOM なし）+ LF。

JSON 書き戻し時は以下に注意:

| 観点 | 推奨 |
|-----|------|
| インデント | 2 スペース |
| 末尾改行 | 1 行 |
| 日本語の保持 | `ensure_ascii=False`（Python） |
| キー順序 | 既存順序を維持（`name` → `owner` → `description` → `plugins`） |
