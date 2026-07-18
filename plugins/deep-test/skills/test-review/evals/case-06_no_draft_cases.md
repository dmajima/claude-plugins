# case-06 設計文脈でレビュー対象 draft が 0 件（全 approved）

設計文脈で `scope=` 指定がなく、有効ケースがすべて approved（draft 0 件）の場合に、エージェントを起動せず「レビュー対象の draft ケースなし」を返却することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args / 起動フレーズ | `context=design target=orderapp-web`（委譲）または「orderapp-web のテストケースをレビューして」（単独・対話） |
| 起動形態 | 委譲 / 単独のいずれでも同一挙動 |
| 前提 | test-plan.md / test-cases.yaml は存在する。test-cases.yaml の有効ケース（`deprecated: true` でない）はすべて `review_status: approved` で、draft ケースが 0 件。`scope=` 指定なし |

## 分岐の根拠

references/review-procedures.md 3.1（レビュー対象の確定表: `scope=` 指定なし → `review_status: draft` かつ `deprecated: true` でない全ケース / 対象が 0 件〔全ケース approved 済み等〕→ エージェントを起動せず「レビュー対象の draft ケースなし」を返却する〔再レビューが目的なら `scope=` の明示を案内〕）、SKILL.md「前提」の引数表（`scope=` 省略時は draft の全有効ケース）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-cases.md` 3 章（review_status の遷移: approved はレビュー済みの状態）。

## 期待動作

- test-plan.md / test-cases.yaml を Read し、`scope=` 指定がないためレビュー対象を「draft かつ deprecated でない全ケース」で確定しようとして 0 件であることを検出する
- **エージェント（coverage / feasibility / user-perspective）を 1 体も起動しない**（レビュー対象なしのまま並列レビューへ進まない）
- 「レビュー対象の draft ケースなし（全ケース approved 済み）」を明示して返却し、approved 済みケースの再レビューが目的の場合は `scope=` によるケース ID の明示指定を案内する
- 対象 0 件を PASS 判定として扱わない（判定は実施していない旨が判別できる返却にする。承認処理も実施しない）
- test-cases.yaml へ一切書き込まない（approved 済みの状態を変更しない）
- エラー扱いにしない（成果物不在のエラー中断とは区別する。test-plan.md / test-cases.yaml が存在しない場合のみエラー中断）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（test-cases.yaml / test-results.yaml へ一切書き込まない） |
| 標準出力（要約） | 「レビュー対象の draft ケースなし（全ケース approved 済み）」の返却と、再レビュー目的の場合の `scope=` 明示指定の案内（PASS / NEEDS REVISION の判定・承認処理は未実施であることが判別できる形式） |
| 終了状態 | エージェント未起動のまま返却（判定なし・書き込みなし） |

## 関連ケース

- case-01: draft ケースが存在し 3 エージェント並列レビュー → PASS となる主系
- case-04: PASS 時の承認処理（本ケースは承認処理に到達しない）
