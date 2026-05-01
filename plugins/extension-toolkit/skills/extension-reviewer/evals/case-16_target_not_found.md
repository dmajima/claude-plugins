# Case 16: 機械チェックの target 不在エラー

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`plugins/non-existent-plugin` をレビュー" |
| 引数 | レビュー対象 = 存在しないパス |
| フラグ | なし |
| 既存状態 | `plugins/non-existent-plugin/` は実在しない |

## 期待動作

### Phase 1: 対象判定

`extension-reviewer` が対象種別の判定を試みる際、ディレクトリが実在しないため事前に存在確認に失敗する。

### Phase 2: 機械チェックスクリプトの起動

`run_checks.py --target plugins/non-existent-plugin --output ...` を起動。スクリプトは以下のように振る舞う:

```text
[ERROR] target not found: plugins/non-existent-plugin
exit code: 2
```

`stderr` に ASCII プレフィックス（`[ERROR]`）付きで出力され、JSON ファイルは作成されない。

### Phase 3: ユーザへの提示

| 提示項目 | 内容 |
|---------|------|
| エラー要因 | レビュー対象パスが存在しない旨 |
| 推奨アクション | パスの綴り確認 / `Glob` ツールによる存在検索 / 正しいプラグイン/スキル名の指定 |
| 自動リトライ | しない（ユーザに確定を委ねる） |

## 期待出力

```markdown
## レビュー中断

**理由**: 指定された対象が存在しません: `plugins/non-existent-plugin`

**確認事項**:
- パスのタイプミスはありませんか?
- 正しいプラグイン名・スキル名を指定していますか?

**次のアクション**: 正しいパスを指定して再実行してください。
```

| 項目 | 期待値 |
|-----|-------|
| 機械チェック JSON | 未生成 |
| エージェント並列起動 | 行わない（対象不在のため） |
| 終了状態 | 中断（exit 1 相当）|

## 分岐の根拠

`run_checks.py` 冒頭の `target.exists()` 確認に失敗すると `[ERROR] target not found` を出力して exit code 2 で終了するため、`extension-reviewer` 側はこれを検知してエージェント起動をスキップする必要がある。

## 関連ケース

- case-01〜10（target 実在の正常系）
- case-17（scope 違反による拒否）
