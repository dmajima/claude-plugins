<!-- TEST-RUN-SCN-EVAL-BLOCKED-MIDWAY-SENTINEL-v1 -->
# case-17 exploratory ケース × セッション開始後の探索続行不能（総合結果 blocked）

`automation: exploratory` の uat スコープのケースについて、セッションは正常に**開始・進行した**が、途中で探索が続行不能になり終了聴取の総合結果が **blocked（探索不能）** となる分岐を検証する。セッション**開始不能**による blocked（case-14）とは検出タイミングが異なり（開始後 vs 開始前）、タイムボックス満了による正常終了（case-16）とも区別する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=order-management-web` / `run_id=R20260719-160000` / ケース: `[TC-UAT-006]`（`automation: exploratory`。case-11 と同一のチャーターケース・`timeout_sec: 3600` = タイムボックス 60 分）/ アプリ情報: `https://localhost:5001` |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ・対話） |
| 前提 | 対話モード。セッションは正常に開始・進行するが、探索の途中で続行不能になる（例: 探索中に対象環境が不安定化して以降の操作が実施できない・探索前提のデータ状態が壊れて予定していた探索が成立しなくなる）。開始そのものは成立している（開始不能は case-14）・タイムボックスは満了していない（満了は case-16） |

## 分岐の根拠

SKILL.md「実行モード判定」の manual-assist / exploratory 分岐（対話時は `${CLAUDE_PLUGIN_ROOT}/references/manual-execution.md` に従う）、`${CLAUDE_PLUGIN_ROOT}/references/manual-execution.md` 3 章（exploratory セッション終了聴取の総合結果選択肢: pass〔重大発見なし・完遂〕/ fail〔欠陥発見〕/ **blocked〔探索不能〕**）・6.2（セッション開始不能の blocked は「開始前の前提不成立」= 本ケースの「開始後の続行不能」とは検出タイミングが異なる）・6.3〜6.5（セッションの進め方・セッションシート・発見事象の記録）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（blocked = テスト論理上のブロック / skipped = 実行手段・応答可能性の不在の使い分け）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 4 章（executed_by の enum: exploratory → human-assisted）。

## 期待動作

- セッションは開始・進行した事実を記録したうえで、途中で探索が続行不能になった場合に終了聴取の総合結果を **`status: blocked` + reason**（探索不能に至った理由・どこまで進めたか）で `executed_by: human-assisted` として記録する（manual-execution.md 3 章）
- **検出タイミングの区別**: 開始不能（case-14・開始前の前提不成立）と混同しない。本ケースは開始成立後に続行不能になった blocked（manual-execution.md 6.2 の対比）
- **タイムボックス満了との区別**: タイムボックス満了は正常終了（case-16・blocked にしない）。本ケースは満了前に続行不能になった blocked（探索の前提が崩れたテスト論理起因）
- blocked を skipped と混同しない（blocked = テスト論理起因の続行不能 / skipped = 実行手段・人間の応答可能性の不在。yaml-schema-results.md 6 章）
- 開始〜続行不能までに得られたセッションノート・部分的な発見事象は捏造せず実際の範囲で記録する（続行不能後の未実施範囲を「確認済み」と書かない）。得られた発見がある場合は results[] 直下の `extras.session_findings`（blocked は fail ではないため defect にしない）へ記録してよい
- scope 全件について 1 エントリを返す
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `evidence/R20260719-160000/TC-UAT-006/session-sheet.md`（開始〜続行不能までの実績・探索不能の理由を記載）+ 補助取得物。test-results.yaml へは書き込まない |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-scenario" / 受領 run_id / results 1 件・status: blocked + reason〔探索不能の理由〕・executed_by: human-assisted・部分発見があれば results[] 直下 `extras.session_findings`） |
| 終了状態 | 探索続行不能を blocked で記録して返却（対象の安定化後、ng-only 再テストの対象になる） |

## 関連ケース

- case-11: 同じ exploratory ケースの対話主系（開始成立・時間内完了 → pass。本ケースは開始成立後に続行不能）
- case-14: セッション**開始不能**による blocked（開始前の前提不成立。本ケースは開始後の続行不能という検出タイミングの違い）
- case-16: タイムボックス満了による正常終了（blocked を適用しない側。本ケースは満了前の続行不能 blocked）
- test-run-functional evals case-12: exploratory の fail 終端（発見事象の defect 化。本ケースは欠陥確定ではなく探索そのものが不能）
