# Case 13: Phase G の Failed 6 件以上（個別判断 UI 非提示）

## 入力

| 項目 | 値 |
|-----|---|
| 起動経路 | `/update-all` |
| コマンドから委譲される `mode` | `normal` |
| コマンドから委譲される `scope` | `all` |
| 既存状態 | Phase C / D / E のいずれかで合計 7 件の Failed が発生（5 件閾値超） |

## 期待動作

### Phase A〜E: 通常通り実行
- 7 件のプラグインが Failed

### Phase F: 結果報告
- サマリ: 成功 N 件 / Failed 7 件 / Skipped 0 件
- Failed の詳細リストを表示

### Phase G: 失敗対応の確認（5 件超）
- ADR-PU-007 / phase-flow.md G-1 に基づき、**「個別に判断」選択肢を除外**
- 選択肢は以下の 2 択のみ:

```text
AskUserQuestion({
  questions: [{
    question: "Failed 7 件についてどう対応しますか？（5 件超のため一括処理のみ）",
    header: "Phase G リトライ",
    options: [
      { label: "全件リトライ", description: "7 件すべてを順次再試行します。" },
      { label: "中止",         description: "リトライせず終了します。" }
    ],
    multiSelect: false
  }]
})
```

- 「個別判断」選択肢が含まれていないことを期待
- 全件リトライ選択時、7 件すべてを `claude plugin update <name>@<mp>` で再実行

### 最終出力（Phase F 再描画）
- リトライ結果を反映した最終サマリ

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| AskUserQuestion 選択肢数 | 2（個別判断は除外） |
| 変更系 CLI 呼び出し | 初回 7 + リトライ分 |
| 終了状態 | 全件成功なら exit 0、残 Failed があれば exit ≠ 0 |

## 分岐の根拠

このケースが分岐するトリガーは Failed >= 6 件 である（ADR-PU-007 の 5 件閾値超）。

## 関連ケース

- `case-09_phase_g_retry.md`（5 件以下で個別判断 UI 提示）
- ADR-PU-007: 失敗対応の対話モデル
