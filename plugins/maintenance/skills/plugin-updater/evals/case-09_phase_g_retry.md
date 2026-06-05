# Case 09: Phase G 失敗対応 AskUserQuestion + リトライ

## 入力

| 項目 | 値 |
|-----|---|
| 起動経路 | `/update-all` |
| コマンドから委譲される `mode` | `normal` |
| コマンドから委譲される `target` | `all` |
| 既存状態 | Phase C / D / E のいずれかで 3 件の Failed が発生（5 件閾値未満）|

## 期待動作

### Phase A〜E: 通常通り実行
- 一部プラグインが Failed で完了

### Phase F: 結果報告
- サマリ: 成功 N 件 / Failed 3 件 / Skipped 0 件
- Failed の詳細（プラグイン名 / スコープ / エラー内容）を表示

### Phase G: 失敗対応の確認
- 5 件閾値以下のため、個別判断 UI を発火（ADR-PU-007）

```text
AskUserQuestion({
  questions: [{
    question: "Failed 3 件についてどう対応しますか？",
    header: "Phase G リトライ",
    options: [
      { label: "全件リトライ", description: "3 件すべてを順次再試行します。" },
      { label: "個別に判断", description: "各 Failed を 1 件ずつ確認します。" },
      { label: "全件スキップ", description: "Failed エントリは諦めて完了する" }
    ],
    multiSelect: false
  }]
})
```

- ユーザが「全件リトライ」を選択した場合、Failed 3 件を順次 `claude plugin update <name>@<mp>` で再実行
- 「個別判断」を選んだ場合、各 Failed について以下を再度確認:
  - 「再試行 / スキップ / 中止」
- リトライ成功した件数を最終サマリに反映
- 再度 Failed のままの件数も明示

### 最終出力（Phase F 再描画）
- Phase G 経由のリトライ結果を反映した最終サマリ
- 「リトライ成功: M 件 / 残 Failed: N 件」

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| AskUserQuestion 発火回数 | 1 回（個別判断選択時は Failed 件数分） |
| 変更系 CLI 呼び出し | 初回 + リトライ分 |
| 終了状態 | 全件リトライ成功なら exit 0、残 Failed があれば exit ≠ 0 |

## 分岐の根拠

このケースが分岐するトリガーは Failed >= 1 件 かつ Failed <= 5 件 である（ADR-PU-007 / ADR-PU-009）。

5 件を超える場合は個別判断 UI を発火せず、一括処理のみ提示する。

## 関連ケース

- `case-08_circuit_breaker.md`（Skipped は Phase G の対象外）
- ADR-PU-007 / ADR-PU-009: 失敗対応の対話モデル
