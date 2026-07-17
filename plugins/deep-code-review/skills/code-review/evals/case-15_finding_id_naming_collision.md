# case-15 Finding ID 命名衝突時の REV-NNN プレフィクス切替

レビュー対象コードに既存の `CR-XXX` マーカー（旧コードレビュー票番号のコメント等）が存在するため、Finding ID の既定プレフィクス `CR-NNN` が衝突するケース。Step 6 の一括採番で別プレフィクス `REV-NNN` へ切り替える分岐を検証する。既定採番の case-01 と対になる。C25（case-14）とは別規範（output-format.md セクション 1.5）の分岐。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "このブランチをレビューして"（差分・対象コード内に既存の `CR-045` / `CR-046` 形式のマーカーコメント（旧レビュー票番号）が含まれる） |
| モード | 標準 |

## 分岐の根拠

`${CLAUDE_SKILL_DIR}/references/output/output-format.md` セクション 1.5「Finding ID 採番規則」の「命名衝突」行（コード側に `CR-XXX` のような既存マーカーがある場合のみ、別プレフィクス `REV-NNN` を使用）・「表記場所」行、references/flow/flow.md Step 6.2「Finding ID の一括採番」、skill-rules-matrix.md C13 / C14。

## 期待動作

- Step 6: 優先度ランキング確定後、Finding ID を一括採番する前に、レビュー対象コード側に `CR-XXX` 形式の既存マーカーが存在することを検出する（output-format.md セクション 1.5 命名衝突）
- Step 6: 衝突するため、既定の `CR-NNN` ではなく **別プレフィクス `REV-NNN` を使用**して全 finding を採番する（output-format.md セクション 1.5 命名衝突行）
- Step 6: プレフィクス以外の採番規則は不変とする（`REV-001` から開始・3 桁ゼロ詰め・Issues → Suggestions → Scope-out の記載順で統合サマリ全体を連続通番・C13 / C14）
- Step 8: 表記場所すべてで一貫して `REV-NNN` を使用する（(1) サマリー詳細補足の見出し `<h4>REV-NNN: ...</h4>` (2) サマリー表の ID 列 (3) PR インラインコメント本文冒頭 `## [REV-NNN] ...` (4) サマリースレッドの目次 (5) 完了報告。output-format.md セクション 1.5 表記場所）
- （以下は検出してはならない誤り）
    - 既存 `CR-XXX` マーカーがあるのに既定の `CR-NNN` で採番して衝突させる
    - CR-NNN と REV-NNN を混在させる（プレフィクスは全 finding で統一する）
    - 衝突が無い（`CR-XXX` マーカーが存在しない）のに REV-NNN へ切り替える（既定は CR-NNN）

## 関連ケース

- case-01: 既定プレフィクス（CR-001 から）での一括採番
- case-03: 再レビュー時の採番起点（前回最終 ID + 1）
