<!-- R13-EVAL-ORCH-28-SENTINEL-v1 -->
# case-28 人間承認ゲートでの手動実施ケース件数提示（select 出力の機械集計）

Phase 4 の人間承認ゲートで、scope に `automation: manual-assist` / `exploratory` のケースが含まれる場合に、select 出力の `details.automation` から手動実施ケース件数（manual-assist / exploratory の内訳）を**機械集計**して提示することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| ユーザー発話 | 「このアプリをテストして」（フルフロー・対話モード） |
| 前提 | 設計・設計レビューは PASS 済み（全ケース approved）。`select --mode full` の scope は 12 ケース（unit / functional / uat）で、うち `automation: manual-assist` 2 件・`exploratory` 1 件・残り 9 件は自動実行（playwright / test-framework 等）。`destructive: true` は 0 件 |

## 分岐の根拠

SKILL.md「実行フロー」Phase 4（人間承認ゲート）と Phase 5 の手動実施ケース節（レベル内で自動実行ケース群の後に処理・規範は `${CLAUDE_PLUGIN_ROOT}/references/manual-execution.md`）、プラグイン共通 references/execution-policy.md 1.3（提示必須項目: 手動実施ケース件数 = `automation: manual-assist` / `exploratory` を select 出力の `details.automation` から destructive と同型で機械集計。対話が発生する旨と概算拘束時間の根拠。文言例「手動確認 2 件〔うち探索的 1〕」）、references/flow.md 3 章（人間承認ゲートの判定材料: select 出力の `details.automation` の manual-assist / exploratory を destructive と同型で機械集計）、results_manager.py select の `details`（automation キーを含む select 出力契約）。

## 期待動作

- 手動実施ケース件数を select 出力 `details` の `automation` フィールドから**機械集計**する（LLM の自由記述推測・test-cases.yaml の目視カウントで数えない。destructive 集計と同型）
- AskUserQuestion の質問文に提示必須項目を埋め込む: 実行ケース数（12）/ 対象テストレベル（unit, functional, uat）/ 想定所要時間（details の timeout_sec 合計を上限とする概算。手動ケースの timeout_sec〔exploratory はタイムボックス〕も概算に寄与する）/ 破壊的操作を含むケース数（0 件）/ **手動実施ケース件数（3 件〔うち探索的 1〕= manual-assist 2 + exploratory 1 の内訳付き）**（execution-policy.md 1.3 の文言例と同型）
- 手動ケースがある場合、実行中に対話（人手確認・探索セッション）が発生し人間の拘束時間が生じる旨が提示から読み取れる
- 各選択肢（実行する / 対象を見直す / 中断する）に帰結を 1 行で添える
- 「実行する」選択後は MCP ゲート → Phase 5 へ進み、手動ケースはレベル内で自動ケース群の後に処理される（cases= の並び順は自動 → 手動）
- 非対話時は本ゲート自体をスキップする（case-05。手動ケースは手順書縮退 = case-29）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | ゲート時点ではなし（scope 確定は select 出力の受領のみ。実績・ケースとも未変更） |
| 標準出力（要約） | AskUserQuestion の提示（対象 12 ケース / unit, functional, uat / 想定所要時間 / 破壊的操作 0 件 / 手動確認 3 件〔うち探索的 1〕）。件数はすべて select 出力由来の機械集計値 |
| 終了状態 | 承認選択に応じて進行（「実行する」= MCP ゲートへ / 「中断する」= case-11 の中断挙動） |

## 関連ケース

- case-11: 同ゲートで「中断する」を選択した場合の中断挙動
- case-12: 破壊的操作ケース数の提示（同型の select 機械集計。本ケースは手動件数側）
- case-05: 非対話時は本ゲートをスキップする（提示自体が発生しない）
- case-29: 非対話時の手動ケースの扱い（手順書一括生成 → skipped 縮退）
