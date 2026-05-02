# case-09 non interactive

非対話モード（引数完全指定 / `--non-interactive` 相当）でコマンドを実行する変形ケース。本ケースでは `/router-toggle off --non-interactive` を例に取る。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "/router-toggle off" を引数完全指定で実行 |
| 既存状態 | プラグイン有効化済 / 現在 ON 状態 |
| モード | 非対話（確認スキップ・自動進行） |

## トリガープロンプト

```text
/router-toggle off
```

または明示的フラグ指定:

```text
/router-toggle off --non-interactive
```

## 期待動作

| Phase | 動作 |
|-------|------|
| 1 | コマンド解釈で引数 `off` を確定 |
| 2 | `AskUserQuestion` を発行せず即時実行 |
| 3 | `<base>/disabled` を `touch` で作成 |
| 4 | 結果を 1 行で出力（対話的な補足案内なし） |

## 期待出力

| 出力 | 内容 |
|-----|------|
| 標準出力 | `skill-router toggled OFF (flag: <base>/disabled)` のみ |
| 副作用 | `<base>/disabled` ファイル作成 |
| ユーザ介入 | なし（確認・選択ダイアログ非発生） |

## 分岐の根拠

eval-guide.md セクション 4「必須カバレッジ」で対話モードと非対話モード両方のケース化を要求。CI 自動化・スクリプトからの呼び出しに耐える挙動を確認する必要があるため。

## 関連ケース

- `case-03_disable` — 同操作の対話モード版
- `case-08_toggle_on` — 裏返し操作

## 備考

- `/router-rebuild` は引数なしのため常に非対話的に動作する（このケースの考え方を `rebuild` にも適用可能）
- `/router-status --clean` も引数完全指定で非対話実行が可能
- 非対話モードでもエラー時はフェイルオープン原則（exit 0）を維持する
