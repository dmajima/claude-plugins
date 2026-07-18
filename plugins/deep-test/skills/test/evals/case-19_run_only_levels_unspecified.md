# case-19 run-only モードで対象レベル（levels=）未指定（憶測補完せず対象レベルを求める / 非対話はエラー中断）

`run-only` モードは対象レベルの指定（`levels=<level,...>`）が必須である。`levels=` を伴わない run-only 起動では、実行に進まず、対話時は対象レベルを確認し、非対話時はエラー中断すること（LLM の判断でレベルを憶測補完しない）を検証する。run-only の主系（levels 指定あり）は case-08 が扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| ユーザー発話（対話） | 「（レベルを言わず）とりあえず実行だけして」相当（`/deep-test:test run-only`。`levels=` なし） |
| ユーザー発話（非対話） | 同上 + `--non-interactive` |
| 前提 | `{base}/{target-slug}/` に approved 済み test-cases.yaml が存在し環境検証済み。複数レベル（functional・integration-internal など）のケースを含む |

## 分岐の根拠

SKILL.md「実行モード判定」（部分: run-only = `run-only levels=<level,...>`〔**対象レベル指定必須**〕）、`${CLAUDE_SKILL_DIR}/references/flow.md` 1 章の状態遷移図（`Phase0 --> Phase4: 再テスト / run-only（環境検証済み）`。run-only は select full の結果を指定レベルで絞り込む前提）・6 章 Phase 4、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 9 章（非対話既定値: 判断に必要な指定が欠ける場合に憶測で自動選択しない方針）、`${CLAUDE_PLUGIN_ROOT}/references/retest-policy.md` 8 章（select を経ない対象確定の禁止）。

## 期待動作

- run-only モードでありながら `levels=` が無いことを検出し、**実行（select / start-run）に進まない**
- **対話時**: 対象テストレベルを確認する（どのレベルを実行するか）。approved 済みケースに含まれるレベルから選ばせる。LLM の判断で「全レベル」や特定レベルを憶測補完しない
- **非対話時**: 対象レベルを確認できないため **エラー中断**し、`run-only levels=<level,...>` の明示指定による再実行を案内する
- `start-run` を実行せず run_id を採番しない（未実行の run レコードを残さない）
- test-results.yaml を Edit / Write で直接編集しない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（実行に進まないため test-results.yaml を更新しない） |
| 標準出力（要約） | 対話時: 対象レベルを求める確認。非対話時: 「run-only は対象レベル指定が必須のため中断した」旨と `levels=` 明示指定による再実行案内 |
| 終了状態 | 対話時: 対象レベル確認待ち（指定後に case-08 の主系フローへ）/ 非対話時: エラーで中断（レベルを憶測補完しない） |

## 関連ケース

- case-08: run-only 主系（`levels=` 指定あり・select full を指定レベルで絞り込み・Phase 5 で完了）。本ケースはその levels 未指定の分岐
- case-17: 非対話で target-slug 複数 → 自動選択せずエラー中断（同じく非対話で憶測補完を避けてエラー中断する系）
- case-07: design-only（run へ進まない別モード）
