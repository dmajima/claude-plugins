# case-08 run-only モード（levels 指定あり・指定レベルで絞り込み・Phase 5 で完了）

`run-only` モード（対象レベル `levels=` 指定あり）で、select full の結果を指定レベルで機械的に絞り込むこと・全ゲート通過後に run を実行して Phase 5（finish-run）で完了することを検証する。`levels=` 未指定時の扱いは case-19 が扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| ユーザー発話 | 「機能テストレベルだけ実行して」（または `/deep-test:test run-only levels=functional`） |
| 前提 | `{base}/{target-slug}/` に approved 済み test-cases.yaml が存在（環境検証済み）。functional・integration-internal など複数レベルのケースを含む。Playwright MCP はロード済み。`levels=` は指定済み（未指定時の扱いは case-19） |

## 分岐の根拠

SKILL.md「実行モード判定」（部分: run-only = `run-only levels=<level,...>`〔対象レベル指定必須〕・Phase 0→(1 必要時)→4→5〔select full の結果を指定レベルで絞り込む〕）、`${CLAUDE_SKILL_DIR}/references/flow.md` 1 章の状態遷移図（Phase0 --> Phase4: run-only〔環境検証済み〕・Phase5 --> Phase6: finish-run 完了〔run-only はここで完了〕）・6 章 Phase 4〜5、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 1 章（4 ゲート）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema.md` 2.2（run_id は start-run が採番）。

## 期待動作

- 設計フェーズ（Phase 2〜3）は起動しない（環境検証済み・approved 前提のため Phase 4 から開始する）
- `results_manager.py select --mode full` で scope を機械確定し、その結果を指定レベル（例: functional）で**絞り込む**（LLM の判断で対象を追加・除外しない。retest-policy.md の select 経由）
- 承認済みケースゲート（draft 混入時は test-review 設計文脈を先行）→ 人間承認ゲート（AskUserQuestion）→ MCP ゲート（functional は Playwright 必要のため ToolSearch 実判定）を経る
- 全ゲート通過後に `start-run --mode full` で run_id を採番し、指定レベルのケースをレベル順に逐次 test-run-* へ Skill 起動 → `record` → `finish-run`
- **Phase 5（finish-run）到達で run-only は完了**とし、結果レビュー（Phase 6）・報告（Phase 7）へ自動で進まない（flow.md 1 章の「run-only はここで完了」）
- test-results.yaml を Edit / Write で直接編集しない（すべて results_manager.py 経由）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | test-results.yaml（start-run / record / finish-run で更新）・指定レベルケースのエビデンス。指定外レベルのケースは scope に含めない |
| 標準出力（要約） | run_id・指定レベルの実行結果集計を含む「引き渡し」。report を含まないため報告書パスは提示しない |
| 終了状態 | finish-run の status=completed（Phase 5 完了） |

## 関連ケース

- case-19: run-only で `levels=` 未指定の分岐（対象レベルを憶測補完せず確認 / 非対話はエラー中断）
- case-01: フルフロー（Phase 2〜7 を含む分岐と対）
- case-07: design-only（run へ進まない分岐と対）
- case-05: 非対話時の人間承認スキップ（run-only 併用時も同じゲート挙動）
