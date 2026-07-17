# case-13 Verdict 判定境界（Needs Attention / Ready to Merge）（C6）

severity 集計と test-runner ステータスから、Critical/High を伴わない 2 つの Verdict 値（Needs Attention・Ready to Merge）を確定するケース。Needs Work を扱う case-09 と合わせて 3 値を網羅する。output-format.md セクション 3.1 のマトリクスの下 2 行を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "このブランチをレビューして"（標準モード） |
| 想定シナリオ | (A) Critical/High = 0・Medium = 2 件・test-runner GREEN / (B) Critical/High/Medium すべて 0・改善提案 2 件あり・test-runner が SKIPPED（理由: 権限なし） |

## 分岐の根拠

`${CLAUDE_SKILL_DIR}/references/output/output-format.md` セクション 3.1（Critical/High/Medium 件数 × test-runner ステータスの判定マトリクス下 2 行）・セクション 3.3（レビュー結果ごとの推奨アクション）・セクション 1.2（レビュー結果は「総合判定 + 再レビュー要否を統合した単一フィールド」）、references/flow/flow.md Step 7、skill-rules-matrix.md C6（Verdict 判定マトリクス）/ U13（動的検証の SKIPPED 明示）。

## 期待動作

- シナリオ (A): Critical/High = 0 かつ Medium ≥ 1 かつ test-runner GREEN のため **NG・再レビュー不要（Needs Attention）** と判定する（output-format.md セクション 3.1 の「0 / 0 / ≥1 / GREEN」行）
- シナリオ (A): 推奨アクション「Medium 指摘を確認・対応の判断後、マージ可否を決定する」を添える（output-format.md セクション 3.3）
- シナリオ (A): Medium のみを理由に Needs Work へ引き上げない（Needs Work は Critical/High ≥ 1 または test-runner RED のみ・セクション 3.1）
- シナリオ (B): Critical/High/Medium すべて 0 かつ test-runner GREEN/SKIPPED のため **OK（Ready to Merge）** と判定する（output-format.md セクション 3.1 の最終行）
- シナリオ (B): 改善提案（Suggestions）が 2 件あっても Verdict には影響しない（判定マトリクスは Critical/High/Medium と test-runner のみで決まる）。推奨アクション「必須修正なし。改善提案は任意検討の上、マージ可」を添える（セクション 3.3）
- シナリオ (B): test-runner SKIPPED を GREEN と同様に扱いつつ、「7. 未確認事項・制約」に `SKIPPED（理由: 権限なし）` として記録し「問題なし」と書き換えない（U13・output-format.md セクション 4）
- 両シナリオとも、レビュー結果を「OK（Ready to Merge）/ NG・再レビュー不要（Needs Attention）」の単一統合フィールドで表現する（output-format.md セクション 1.2）
- （以下は検出してはならない誤り）
    - シナリオ (A) の Medium のみを Needs Work と誤判定する
    - シナリオ (B) の test-runner SKIPPED を RED と混同して Needs Work にする
    - シナリオ (B) で改善提案の存在を理由に Ready to Merge 以外にする
    - SKIPPED を未確認事項に記載せず「問題なし」と書き換える（U13 違反）

## 関連ケース

- case-09: Verdict オーバーライド（Needs Work 側・test-runner RED / エージェント強制評価）
- case-08: マージ可否判断フレーズでの起動と Verdict 明示
