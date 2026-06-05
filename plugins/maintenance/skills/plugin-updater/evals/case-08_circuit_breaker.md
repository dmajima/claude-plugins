# Case 08: Phase B サーキットブレーカー発動（MP 単位累計 3 件 Failed）

## 入力

| 項目 | 値 |
|-----|---|
| 起動経路 | `/update-all` |
| コマンドから委譲される `mode` | `normal` |
| コマンドから委譲される `target` | `all` |
| 既存状態 | マーケットプレイス A / B / C、各 MP に複数プラグイン。Phase B 開始時点で MP `A` の累計 Failed が既に 3 件に達している（前回実行で記録、または当該セッション内累積） |

## 期待動作

### Phase A-0〜A-3: 通常通り
- 引数バリデーション・対象収集・入力検証は正常完了

### Phase B: マーケットプレイス更新
- MP `A` / `B` / `C` を順次 `claude plugin marketplace update <name>` で更新
- サーキットブレーカーの集計対象は ADR-PU-006 に定義
- MP `A` の Failed が累計 3 件に達した時点で MP `A` 配下のプラグインを Skip 扱いとする

### Phase C / D / E: プラグイン更新
- MP `A` 配下のプラグインは Skip（理由: `circuit-breaker / mp=A`）
- MP `B` / `C` 配下のプラグインは通常通り更新

### Phase F: 結果報告
- Skip された MP `A` 配下のプラグインを「Skipped (Circuit Breaker)」として明示
- サマリには Skipped 件数を独立カラムで表示
- 「サーキットブレーカー発動: MP A の累計 Failed が 3 件に達したため、配下プラグインを Skip しました」と説明文を出力

### Phase G: 失敗対応
- Skipped はリトライ対象外（ADR-PU-007）のため、サーキットブレーカー Skip は AskUserQuestion の選択肢に含めない
- 通常 Failed があれば別途リトライ確認

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更系 CLI 呼び出し | MP 更新（A / B / C） + B/C 配下のプラグイン更新のみ |
| 標準出力（要約） | 「Circuit Breaker: MP=A」「Skipped: N 件（理由: circuit-breaker）」 |
| 終了状態 | exit 0 または Phase G の対話結果に従う |

## 分岐の根拠

このケースが分岐するトリガーは Phase B でのマーケットプレイス単位累計 Failed >= 3 である（ADR-PU-006）。

## 関連ケース

- `case-09_phase_g_retry.md`（通常の Failed → Phase G）
- ADR-PU-006: サーキットブレーカー
- ADR-PU-007: Skipped はリトライ対象外
