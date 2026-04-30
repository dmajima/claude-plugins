# Case 01: マーケットプレイス新規構築

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "新しいマーケットプレイス `acme-claude-plugins` を作って" |
| 引数 | `acme-claude-plugins --owner acme-corp --description "Acme Corp 内製プラグイン"` |
| フラグ | なし |
| 既存状態 | 対象パスに `.claude-plugin/marketplace.json` 未存在 |

## 期待動作

### Phase 1: モード判定

対象パスに `marketplace.json` 未存在 → **新規構築モード**。

### Phase 2: 必須入力確認

| 項目 | 動作 |
|-----|------|
| `name` | `acme-claude-plugins`（引数から） |
| `owner.name` | `acme-corp`（フラグから） |
| `description` | "Acme Corp 内製プラグイン"（フラグから） |
| `target-path` | カレントディレクトリ or ユーザ確認 |

不足項目があれば `AskUserQuestion` で確認。

### Phase 3: テンプレート展開

[`../../../references/templates/marketplace/`](../../../references/templates/marketplace/) を `<target-path>` にコピー:

| 生成ファイル | 内容 |
|-----------|------|
| `<target-path>/.claude-plugin/marketplace.json` | プレースホルダ置換済 |
| `<target-path>/README.md` | プラグイン一覧テーブルは空、追加方法・自動更新セクションは完備 |
| `<target-path>/.gitignore` | `.claude/.local/` 等を含む |

### Phase 4: プレースホルダ置換

| プレースホルダ | 置換値 |
|--------------|-------|
| `{marketplace-name}` | `acme-claude-plugins` |
| `{owner-name}` | `acme-corp` |
| `{description}` | "Acme Corp 内製プラグイン" |
| `{marketplace-url}` | 未指定なら `<未設定>` プレースホルダのまま、ユーザに後から追加するよう案内 |

### Phase 5: 検証

| 項目 | 動作 |
|-----|------|
| `marketplace.json` JSON valid | 必須 |
| README 必須セクション存在 | 「プラグイン一覧」「マーケットプレイスの追加方法」「自動更新の有効化」が揃う |
| プレースホルダ残存 | `{marketplace-url}` のみ許容（ユーザが後から埋める旨を提示） |

### Phase 6: 引き渡し

```text
マーケットプレイス acme-claude-plugins の構築が完了しました。

次のステップ:
1. リポジトリ URL を README に反映する
2. plugin-toolkit で最初のプラグインを作成する
3. git init / 初回コミット / リモートリポジトリへ push

plugin-toolkit を起動しますか？
```

`AskUserQuestion` で次のアクション選択。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `<target-path>/.claude-plugin/marketplace.json` / `<target-path>/README.md` / `<target-path>/.gitignore` |
| 標準出力 | 構築完了メッセージ + 次ステップ提案 |
| 終了状態 | 成功 |

## 分岐の根拠

対象パスに `marketplace.json` 未存在 → 新規構築モードを選択。

## 関連ケース

- `case-02_add_plugin.md`（既存マーケットプレイスへのプラグイン追加）
- `case-06_non_interactive.md`（非対話モード）
