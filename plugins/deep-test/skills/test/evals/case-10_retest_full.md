# case-10 再テスト full の対象判定（na・deprecated を除く承認済み全ケースが対象）

再テストの `full`（na・deprecated を除く承認済み全ケース）の対象判定が、select による機械的抽出で正しく行われることを検証する。`ids=`（指定 ID のみ・na 警告・deprecated 除外）の対象判定は case-21 が扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| ユーザー発話 | 「修正したので全体を再テストして」（`/deep-test:test-retest` → full、または `retest full`） |
| 前提 | latest に pass / fail / blocked / skipped が混在。`na` のケース 1 件、`deprecated: true` のケース 1 件、未実行（結果なし）ケース 1 件が存在 |

## 分岐の根拠

SKILL.md「実行モード判定」（再テスト: Phase 0→(1 必要時)→4→5→6→7）・「重要な制約」（select を経ない再テスト対象の確定禁止）、`${CLAUDE_PLUGIN_ROOT}/references/retest-policy.md` 1 章（モード定義: full = na・deprecated を除く承認済み全ケース）・2 章（対象判定マトリクス: na は full 対象外 / deprecated は除外 / 未実行は対象）・8 章（select を経ない確定禁止）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-cases.md` 3 章（deprecated 論理削除）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` 6 章（na = 対象外判定）。

## 期待動作

- `results_manager.py select --mode full` を実行し、na と deprecated を除く承認済み全ケース（pass / fail / blocked / skipped + 未実行）を scope に確定する（retest-policy.md 2 章のマトリクス）。na・deprecated は scope に含めない
- LLM の判断で対象を追加・除外せず、select の出力（`cases` / `draft_cases`）をそのまま scope とする（retest-policy.md 8 章）
- 抽出後は承認済みケースゲート（draft 混入時 test-review 設計文脈）→ 人間承認ゲート → MCP ゲートを経て `start-run` で**新規 run_id** を採番する（既存 run の上書きをしない）
- 設計フェーズ（Phase 2〜3）は原則起動しない（再テストは Phase 4 から。ただし draft 混入時のみ承認済みケースゲートで test-review を先行）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | test-results.yaml（新規 run を append + latest 更新）。既存 runs / results は書き換えない |
| 標準出力（要約） | full の select 結果（na / deprecated 除外の全承認ケース）と実行後の集計を含む「引き渡し」 |
| 終了状態 | 新規 run_id で実行し finish-run の status=completed。deprecated 除外を引き渡しに明示 |

## 関連ケース

- case-21: 再テスト ids（指定 ID のみ・na 警告・deprecated 除外の分岐）。本ケースはその full の分岐
- case-02: 再テスト ng-only（fail / blocked / skipped + 未実行が対象・pass 除外の分岐と対）
- case-01: フルフロー（設計フェーズを含む分岐と対）
- case-06: 再テスト中の fail 記録でも同じ一次バリデーションが働く
