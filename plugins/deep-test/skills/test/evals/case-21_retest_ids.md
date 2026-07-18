# case-21 再テスト ids の対象判定（指定 ID のみ・na への警告付き対象・deprecated 除外）

再テストの `ids=`（指定 case_id のみを対象とし、`na` のケースは警告付きで対象・`deprecated` のケースは明示指定でも警告を表示して除外）の対象判定が、select による機械的抽出で正しく行われることを検証する。再テスト `full`（承認済み全ケース）は case-10 が扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| ユーザー発話 | 「TC-FUNC-002 と TC-SEC-001 だけ再テストして」（`retest ids=TC-FUNC-002,TC-SEC-001`） |
| 前提 | latest に pass / fail / blocked / skipped が混在。`na` のケース 1 件、`deprecated: true` のケース 1 件、未実行（結果なし）ケース 1 件が存在。ids 指定には na のケースと deprecated のケースを 1 件ずつ含める |

## 分岐の根拠

SKILL.md「実行モード判定」（再テスト: Phase 0→(1 必要時)→4→5→6→7）・「重要な制約」（select を経ない再テスト対象の確定禁止）、`${CLAUDE_PLUGIN_ROOT}/references/retest-policy.md` 1 章（モード定義: ids = 指定 case_id のみ）・2 章（対象判定マトリクス: ids 指定時の na は警告付き対象 / deprecated は ids 明示でも警告除外 / 未実行は対象）・8 章（select を経ない確定禁止）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-cases.md` 3 章（deprecated 論理削除）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（na = 対象外判定）。

## 期待動作

- `results_manager.py select --mode ids --ids "TC-FUNC-002,TC-SEC-001"`（および na・deprecated を含む指定）を実行する（LLM の判断で対象を追加・除外しない。retest-policy.md 8 章）:
  - 指定 ID のうち通常ケースは status に関わらず対象とする
  - **na のケースを ids 指定した場合は警告付きで対象**とする（対象外判定そのものの再確認意図。retest-policy.md 2 章）
  - **deprecated のケースは ids で明示指定されても警告を表示して除外**する（retest-policy.md 2 章）
- select の出力（`cases` / `draft_cases`）をそのまま scope とする（retest-policy.md 8 章）
- 抽出後は承認済みケースゲート（draft 混入時 test-review 設計文脈）→ 人間承認ゲート → MCP ゲートを経て `start-run` で**新規 run_id** を採番する（既存 run の上書きをしない）
- 設計フェーズ（Phase 2〜3）は原則起動しない（再テストは Phase 4 から。ただし draft 混入時のみ承認済みケースゲートで test-review を先行）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | test-results.yaml（新規 run を append + latest 更新）。既存 runs / results は書き換えない |
| 標準出力（要約） | ids の select 結果（指定分・na 警告・deprecated 除外の警告）と実行後の集計を含む「引き渡し」 |
| 終了状態 | 新規 run_id で実行し finish-run の status=completed。deprecated 除外・na 警告を引き渡しに明示 |

## 関連ケース

- case-10: 再テスト full（na・deprecated を除く承認済み全ケースが対象）。本ケースはその ids の分岐
- case-02: 再テスト ng-only（fail / blocked / skipped + 未実行が対象・pass 除外の分岐と対）
- case-18: 承認済みケースゲート（ids 再テストで draft が混入した場合の先行 test-review）
