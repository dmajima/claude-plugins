# Case 06: --non-interactive モード（質問なしで構築）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "新しいマーケットプレイス `acme-claude-plugins` を作って" |
| 引数 | `acme-claude-plugins --non-interactive --owner acme-corp --description "Acme Corp プラグイン" --target-path ./acme-claude-plugins` |
| フラグ | `--non-interactive` |
| 既存状態 | 対象パスに `marketplace.json` 未存在 |

## 期待動作

### Phase 1: モード判定 + 必須フラグ検証

`--non-interactive` 検出 → 非対話モード。
必須フラグの揃いを検査:

| 必須フラグ | 提供 |
|-----------|-----|
| `--owner` | あり |
| `--description` | あり |
| `--target-path` | あり |

不足があれば対話なしで **エラー終了**（標準エラー出力に提示）。

### Phase 2: テンプレート展開（自動）

[`../../../references/templates/marketplace/`](../../../references/templates/marketplace/) を `<target-path>` にコピー、プレースホルダ置換。
ユーザ確認は **一切行わない**。

### Phase 3: 検証 + 引き渡し

検証チェックリスト合格後、生成ファイルパスのみを標準出力に提示。
不合格項目があった場合は標準エラー出力に提示し、対話なしで終了。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `<target-path>/.claude-plugin/marketplace.json` / `<target-path>/README.md` / `<target-path>/.gitignore` |
| 標準出力 | 構築完了メッセージ + ファイルパス（次ステップ提案は文字列のみ、対話なし） |
| 終了状態 | 成功 |
| ユーザ対話 | 発生しない |

## 分岐の根拠

`--non-interactive` フラグ + 必須フラグ完備 → 自動構築。
必須フラグ不足時はエラー終了（対話のかわりにエラーメッセージ）。

## 関連ケース

- `case-01_new_marketplace.md`（対話モード・新規構築）
