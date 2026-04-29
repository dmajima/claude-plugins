# Case 03: 既存プラグインへの追加配置

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`dev-toolkit` プラグインに既存スキル `linter` を追加" |
| 引数 | `dev-toolkit --add skill:linter` |
| フラグ | なし |
| 既存状態 | `dev-toolkit` プラグインが既存、`linter` スキルが未配置 |

## 期待動作

### Phase 1: プラグイン存在確認

`plugins/dev-toolkit/` の存在を確認。存在するため追加シナリオで進行。

### Phase 2: 衝突確認

`plugins/dev-toolkit/skills/linter/` の存在を確認。未存在なので新規追加へ。

### Phase 3: 移管実行

case-02 と同じ移管手順。

### Phase 4: プラグイン README 更新案内

「提供機能」が変わるため `readme-creator` への接続を提案。

### Phase 5: 検証 + 引き渡し

通常の検証 + マーケットプレイス公開済みの場合は `marketplace-publisher` で更新公開を提案。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `plugins/dev-toolkit/skills/linter/`（移管） |
| 標準出力（要約） | 「`linter` スキルを `dev-toolkit` プラグインに追加」+ README 更新と公開の案内 |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーはプラグイン名 = 既存プラグイン である。
