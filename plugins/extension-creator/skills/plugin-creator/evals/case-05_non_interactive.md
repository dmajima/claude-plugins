# Case 05: 非対話モード

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "plugin-creator dev-toolkit を非対話で外形作成" |
| 引数 | `dev-toolkit --description "開発支援" --include-types "commands,skills" --author dmajima` |
| フラグ | `--non-interactive` |
| 既存状態 | 未存在 |

## 期待動作

### Phase 1: モード判定

`--non-interactive` フラグありのため対話せず引数値で確定。

### Phase 2: 外形生成

case-01 と同じ手順を非対話で実行。不足パラメータはデフォルト値を使用:

| パラメータ | デフォルト |
|----------|----------|
| keywords | `[]` |
| author | `dmajima`（引数指定済み） |

### Phase 3: 検証 + 引き渡し

質問なしで完了報告のみ。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | case-01 と同じ |
| 標準出力（要約） | 完了報告のみ |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは `--non-interactive` フラグ である。
