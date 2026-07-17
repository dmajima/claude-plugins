# case-03 前回 state.yaml ありの再レビュー（remaining_issues 引き継ぎ）

同一ブランチで 2 回目以降のレビューを実行するケース。前回 state.yaml の findings / remaining_issues を読み込み、解消確認と引き継ぎを行う。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "指摘を修正したので再レビューして"（`.claude/.local/plugins/deep-code-review/{branch}/` に前回 state.yaml あり） |
| モード | 対話 |

## 分岐の根拠

references/flow/flow.md Step 0-P-2「state.yaml あり → 前回の findings / remaining_issues / ignored_by_user / code_as_reference_decisions を保持し、review_round を +1」、flow.md Step 5「前回指摘の解消確認（再レビュー時）」、references/state/state-management.md セクション 4 / 5。

## 期待動作

- Step 0-P-2: タイムスタンプフォルダを日時降順でソートし、最新の state.yaml を読み込む
- review_round を前回 +1 で算出する
- 前回 findings + remaining_issues の各項目について、ファイル・行番号の変更有無と detail_summary との照合で解消判定する（flow.md Step 5）
- 解消と判定した前回指摘は resolved_since_last に、未解消は remaining_issues として今回の state.yaml に記録する
- 前回 ignored_by_user に含まれる指摘は再指摘しない
- 前回 code_as_reference_decisions の承認済みパターンを project-rules-summary に追記して観点別スキルへ引き継ぐ（flow.md Step 4）
- 新規発見指摘の Finding ID は前回最終 ID + 1 から採番する（references/output/output-format.md セクション 1.5）
- 統合サマリのタイトルの回数（第 N 回）を前回 +1 の通番で記載する
- 同一 Finding ID が remaining_issues と resolved_since_last の両方に存在しないことを検証する（flow.md Step 8.5-7）
- 今回の state.yaml を新しいタイムスタンプフォルダに保存し、previous_review_dir に前回フォルダ名を記録する

## 関連ケース

- case-01: 初回レビュー（state.yaml なし）
