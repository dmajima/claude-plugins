# case-04 承認処理（review_status 更新の書き換え範囲）

設計文脈 PASS 時の承認処理そのものを検証するケース。書き換えが「レビュー対象ケースの review_status + meta.updated_at」のみの最小差分であること、対象外ケース・他ファイルに影響しないことを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `context=design target-slug=orderapp-web scope=TC-FUNC-003,TC-FUNC-004`（承認済みケースゲートからの委譲想定） |
| 起動形態 | 委譲（オーケストレータ `test` から Skill ツール経由） |
| 前提 | test-cases.yaml に TC-FUNC-001（approved / revision: 1）・TC-FUNC-002（approved / revision: 2）・TC-FUNC-003（draft / revision: 2・内容変更で draft に戻ったケース）・TC-FUNC-004（draft / revision: 1・新規）が存在 / レビュー結果は Low 指摘のみで PASS 見込み / 同ディレクトリに test-results.yaml が存在 |

## 分岐の根拠

SKILL.md「重要な制約」（唯一の例外 = 承認処理。書き換え範囲は review_status と meta.updated_at のみ）と「検証」（PASS 時の書き換え範囲・results 不書き込み）、references/review-procedures.md 3.1 章（scope= 指定時は指定 ID が対象）・3.4 章（承認処理の手順と書き換え範囲の制約・Grep での整合確認）、references/review-criteria.md 2.3 章（PASS 時の動作）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-cases.md` 2 章（review_status の定義）・3 章（draft → approved は test-review PASS のみ）。

## 期待動作

- レビュー対象を `scope=` の TC-FUNC-003 / TC-FUNC-004 の 2 件に限定する（他の draft を勝手に対象へ加えない）
- PASS 判定後、Edit による変更が以下**のみ**であること:
  - TC-FUNC-003 の `review_status: draft` → `approved`
  - TC-FUNC-004 の `review_status: draft` → `approved`
  - `meta.updated_at` の更新
- 以下に**変更がない**こと: 各ケースの `revision`（003 は 2 のまま・インクリメントしない）/ ケース側の `updated_at` / `steps`・`expected` 等の内容フィールド / スコープ外の TC-FUNC-001・TC-FUNC-002
- test-results.yaml に一切書き込まない（同ディレクトリに存在しても触れない）
- 更新後に Grep で対象 2 ケースに draft が残っていないことを確認する
- レポートの「承認処理」に approved 化したケース ID（TC-FUNC-003 / TC-FUNC-004）を明記する

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | test-cases.yaml の該当ケース（TC-FUNC-003 / TC-FUNC-004）の `review_status` を approved に更新 + `meta.updated_at` のみ（最小差分。`revision`・内容フィールド・スコープ外ケースは不変更）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 承認したケース ID（TC-FUNC-003 / TC-FUNC-004）と PASS 判定・書き換え範囲の報告 |
| 終了状態 | 設計文脈 PASS で approved 反映（対象 2 件に draft 残なしを Grep で確認・results には不書き込み） |

## 関連ケース

- case-01: draft 全件を対象とする承認（scope 未指定）
- case-02: NEEDS REVISION 時は一切書き込まない（対になる分岐）
