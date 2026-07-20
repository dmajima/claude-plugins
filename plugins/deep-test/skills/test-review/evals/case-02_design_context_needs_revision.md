# case-02 設計文脈 NEEDS REVISION（High 指摘・承認しない）

設計文脈のレビューで High 指摘が検出されるケース。NEEDS REVISION 判定・承認処理の不実施・差し戻し事項の返却を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | 「orderapp-web のテストケースをレビューして」 |
| 起動形態 | 単独（ユーザー直接起動・対話） |
| 前提 | test-cases.yaml に draft ケース 8 件。うち 1 件はデータ削除を行うのに preconditions / steps に破壊的操作の明示がなく、主要機能「注文確定」の異常系ケースが存在しない（coverage / feasibility から High 以上の指摘が出る状態）。加えて、いずれかのエージェントから**信頼度 35 の Critical 相当指摘 1 件**（根拠の弱い指摘）が出る |

## 分岐の根拠

SKILL.md「責務」4（判定基準: Critical / High 指摘が 1 件以上なら NEEDS REVISION）と「重要な制約」（NEEDS REVISION 後の修正ループ制御はオーケストレータ責務）、references/review-criteria.md 1.2 章（破壊的操作の未明示 = Critical 相当・主要機能の異常系欠落 = High 相当）・2.1 章（基本判定）・2.2 章（信頼度下限: 信頼度 40 未満の指摘は判定のカウント対象外とし「参考指摘」として別掲する）・2.3 章（NEEDS REVISION 時は書き込まない）、references/review-procedures.md 3.4 章（PASS 時のみ承認処理）・3.5 章（差し戻し事項の整理）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-cases.md` 3 章（draft → approved の遷移は PASS のみ）。

## 期待動作

- 3 エージェントを 1 メッセージ内で並列起動し、統合後に Critical / High 指摘（信頼度 40 以上）が 1 件以上あることを確認して **NEEDS REVISION** と判定する
- test-cases.yaml に**一切書き込まない**（review_status は draft のまま。部分的に一部ケースだけ approved 化することもしない）
- 差し戻し事項を test-design が着手できる粒度（対象ケース ID / 何をどう直すか / 根拠）で整理して返却する
- 修正ループ（test-design の再実行）を本スキルからは起動しない（差し戻し事項の提示まで。ループ制御はオーケストレータ責務）
- レポートに指摘一覧（重要度降順 → 信頼度降順・出所エージェント併記）と「承認処理: 未実施（NEEDS REVISION のため）」を明記する
- **信頼度 35 の Critical 相当指摘は判定のカウント対象外**とする: NEEDS REVISION の根拠（Critical / High のカウント）に含めず、信頼度 40 以上の指摘のみで判定する（review-criteria.md 2.2）
- 当該参考指摘を隠さない: 「参考指摘（判定カウント外）」であることを明示してレポートに別掲する（仮に信頼度 40 以上の Critical / High 指摘が 1 件もなかった場合、この参考指摘だけを根拠に NEEDS REVISION としてはならない）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（test-cases.yaml に一切書き込まない。review_status は draft のまま・一部ケースのみの approved 化もしない）。test-results.yaml へも書き込まない |
| 標準出力（要約） | 判定 NEEDS REVISION（信頼度 40 以上の Critical / High 指摘に基づく）・指摘一覧（重要度降順 → 信頼度降順・出所併記、信頼度 35 の Critical 相当指摘は判定カウント外の参考指摘として別掲）・test-design が着手できる粒度の差し戻し事項・「承認処理: 未実施（NEEDS REVISION のため）」の明記 |
| 終了状態 | NEEDS REVISION で差し戻し（8 件すべて draft のまま）。修正ループは本スキルから起動せずオーケストレータへ委ねる |

## 関連ケース

- case-01: 指摘が Medium / Low のみで PASS
- case-04: PASS 時の承認処理の書き換え範囲
