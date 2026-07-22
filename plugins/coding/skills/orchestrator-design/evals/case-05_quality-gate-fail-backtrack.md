# Case 05: 品質ゲート FAIL → 遡行制御（Phase 3 → Phase 2 分析起因を主シナリオに、設計 WF の全遡行分類の共通挙動）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「通知機能を既存のイベント基盤に載せる設計をして」 |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | TypeScript プロジェクト。Phase 3 の設計中に、Phase 2 Analyze が既存イベント基盤の依存方向（購読側と発行側の結合）を取り違えていたことが判明し、設計の前提が崩れる状況 |

## 期待動作

### Phase 3: Design（FAIL 検出）
- [design-principles.md](../../../references/design-principles.md) の観点で設計を進める過程で、`impact-analysis.md` の現状構造把握に誤り（依存方向の取り違え）があり、設計の前提が成立しないと判明する
- 品質ゲート観点「設計観点・リスク対応・データフローが設計書に含まれるか」を満たせず、品質ゲート判定 = FAIL
- 原因が **分析不足**（Phase 2 の現状構造把握漏れ）のため、`references/workflow.md` 0.3 遡行規定「Phase 3 で分析不足が判明 → Phase 2」に従い **Phase 2 へ遡行** すると判断する

### 遡行処理
- Phase 2: 既存イベント基盤の依存方向を再調査し `impact-analysis.md` を更新する
- Phase 3: 修正後の現状構造で設計をやり直し `implementation-design.md` を作成する
- 同一フェーズへの遡行は最大 3 回。超過時はユーザに状況（試行内容・残る問題・選択肢）を報告して判断を仰ぐ

### 他の遡行分類も同一の制御で動作すること（期待動作に明記）
本ケースの Phase 3 → Phase 2 に限らず、設計 WF（4 フェーズ・実装を伴わない）の遡行はいずれも「該当フェーズの品質ゲート FAIL → `references/workflow.md` 0.3 遡行テーブル参照 → 指定フェーズへ遡行 → 修正 → 通常フロー再開、同一フェーズ最大 3 回」という共通制御に従う:

| 発生フェーズ | 検出内容 | 遡行先（0.3 テーブル） |
|------|---------|---------|
| Phase 2 Analyze | 前提（依頼理解）の誤りが判明 | Phase 1 Intake |
| Phase 3 Design | 分析不足が判明（現状構造把握漏れ等）※本ケースの主シナリオ | Phase 2 Analyze |
| Phase 4 Report | 成果物の欠落を検出 | 該当フェーズ |

- 遡行先はメインの恣意ではなく **遡行テーブルの規定** で決まる（同じトリガー分類なら同じ遡行先）
- 設計 WF はコード変更を伴わないため、実装 WF 固有の「実装済みコードの破棄確認」（`orchestrator-coding` case-10 等）は発生しない
- 再開後も同一フェーズへの遡行が 3 回を超えたらユーザ判断を仰ぐ（上限は全分類共通）

### Phase 4: Report
- `design-report.md` に経緯（分析の見直しにより設計を作り直した旨）を平易な言葉で記録する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 遡行先 | Phase 2（分析起因） |
| 生成ファイル | `impact-analysis.md`（更新）+ `implementation-design.md`（再作成）+ `design-report.md` |
| 終了状態 | 成功（遡行後 PASS）または 3 回超過時のユーザ判断待ち |

## 分岐の根拠

このケースが分岐するトリガーは 品質ゲート判定 = FAIL（かつ原因 = 分析不足）である。
`references/workflow.md` 0.3 遡行規定「Phase 3 で分析不足が判明 → Phase 2」を主シナリオに適用しつつ、`orchestrator-coding` case-11（前段遡行の共通挙動）と同様に、設計 WF の全遡行分類（Phase 2 → 1 / Phase 3 → 2 / Phase 4 → 該当）が同一の遡行制御（テーブル参照 → 遡行 → 再開・最大 3 回）で動作することを 1 ケースで一般化して検証する。`orchestrator-coding` は case-08 / case-10 / case-11 で遡行を検証済みだが、`orchestrator-design` の遡行は未検証だったため本ケースで補完する（設計 WF は 4 フェーズ・実装なしのため、遡行先が Phase 2 になる点・実装コード破棄確認が発生しない点が固有）。

## 関連ケース

- [case-01_design-only-request.md](case-01_design-only-request.md)（全フェーズ PASS の正常系との対比）
- [case-03_large-scale-architect-review.md](case-03_large-scale-architect-review.md)（architect レビュー指摘で設計を修正する分岐。本ケースは前フェーズの分析不足による遡行）
- `../../orchestrator-coding/evals/case-08_quality-gate-fail-backtrack.md`（実装 WF での遡行。**コードパスが異なる**: case-08 は Phase 5 レビュー指摘（設計起因）→ Phase 3 遡行。本ケースは設計 WF の Phase 3 で分析不足を検出 → Phase 2 遡行で、実装・自己レビューのフェーズを持たない）
