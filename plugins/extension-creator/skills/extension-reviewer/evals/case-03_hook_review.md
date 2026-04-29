# Case 03: フックレビュー（security-engineer 必須）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`dev-toolkit` プラグインのフック設定をレビュー" |
| 引数 | `dev-toolkit/hooks/hooks.json` |
| フラグ | なし |
| 既存状態 | フック設定が存在 |

## 期待動作

### Phase 1: 対象判定

`hooks.json` → フックレビューモード。

### Phase 2: 観点選定（security-engineer 必須）

| エージェント | 観点 |
|------------|------|
| `security-engineer`（リード・必須） | command の安全性・終了コード・ブロック動作 |
| `implementation-engineer` | timeout 設定・パスポータビリティ |
| `infrastructure-engineer` | 副作用・パフォーマンス影響 |

### Phase 3: 並列起動 + 機械チェック

特に command フィールドの危険コマンド検出に注力。

### Phase 4: セキュリティ指摘の扱い

セキュリティ指摘は **必ずユーザ確認** を求める（自動修正対象外）。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 標準出力 | フック毎のセキュリティ評価 + 総合判定 |
| 終了状態 | レビュー完了 |

## 分岐の根拠

対象 = フック → security-engineer 必須。
