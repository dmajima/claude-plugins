# case-01 標準モード・初回レビュー（state.yaml なし・サブエージェント方式）

前回 state.yaml が存在しないブランチ差分を標準モードでレビューする初回ケース。Agent Teams は採用せず、観点別スキルを並列起動するサブエージェント方式で実行する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "このブランチをコードレビューして"（前回 state.yaml なし・10 ファイル未満かつ 1,000 行未満の変更） |
| モード | 対話（AskUserQuestion で標準を選択） |

## 分岐の根拠

references/flow/flow.md Step 0-P-2「state.yaml なし → 初回レビューとして扱う。review_round: 1 で開始」、references/flow/mode-selection.md セクション 2（明示指定なし → AskUserQuestion → 標準）、flow.md Step 3.5 のフォールバック条件（軽微変更）によりサブエージェント方式（Step 4）。

## 期待動作

- Step 0-P-1: git branch --show-current でブランチ名を確定する
- Step 0-P-2: `.claude/.local/plugins/deep-code-review/{branch}/` 配下に前回 state.yaml がないことを確認し、review_round: 1 で開始する
- Step 0-P-3: inputs フォルダなし + spec 引数なしのため、inputs-management.md セクション 4 のヒアリングフローを実行する（ユーザーが「仕様確認不要」と回答した場合はスキップ）
- Step 0: AskUserQuestion でモードを確認し、選択された標準モードを採用する
- Step 1: 比較ブランチを origin/develop → origin/main → origin/master の順で自動判定する（scope-detection.md セクション 1.2）
- Step 2: 差分ファイルとマーカーファイルから言語・FW を検出し（language-detection.md / C23）、適用観点プロファイル一覧を確定する。プロジェクト規約を読み込み project-rules-summary（最大 2,000 文字）を生成し、言語・FW 検出結果を適用規約サマリとして統合、末尾に U14 コード信頼性原則の注意喚起を含める（flow.md Step 4）
- Step 3: 必須トリオに加え、設計影響があれば architecture、UI 変更があれば frontend を動員判定する
- Step 3.5: Agent Teams 採用条件に該当しないため、サブエージェント方式（Step 4）に分岐する
- Step 4: 選定した観点別スキルを 1 メッセージ内で並列起動する（Skill ツール・Independent 型）
- Step 5-6: 結果統合・重複排除を行い、Finding ID（CR-001 から）を一括採番する
- Step 7: レビュー結果を判定する（Critical / High が 1 件以上なら NG・再レビュー要）
- Step 8: references/template/output/review-summary.md 準拠の統合サマリを出力する（「6. 既存指摘の解消判定」は「該当なし（初回レビュー）」）
- Step 8.5: state.yaml と review-summary.md を `.claude/.local/plugins/deep-code-review/{branch}/{yyyyMMdd_HHmmss}/` に保存する（`.claude/.local/work/` には保存しない）

## 関連ケース

- case-02: 簡易モード（必須トリオのみ）
- case-03: 前回 state.yaml ありの再レビュー
