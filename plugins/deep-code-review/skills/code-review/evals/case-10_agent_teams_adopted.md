# case-10 Agent Teams 採用（大規模・クリティカル差分・ユーザー承認パス）（C4）

標準モードで大規模かつセキュリティクリティカルな差分をレビューし、Step 3.5 で Agent Teams パターンを選定、AskUserQuestion でユーザーが承認して Step 4-T（チーム議論）で継続するケース。Step 4（サブエージェント方式）とは排他。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "このブランチをレビューして"（差分: 認証・認可の全面刷新を含む 18 ファイル / 約 1,400 行。JWT 検証・ロールベース認可・セッション管理の変更） |
| モード | 対話（標準） |

## 分岐の根拠

references/flow/flow.md Step 3.5「採用条件（標準モード かつ 大規模変更（10ファイル超 or 1,000行超）／ セキュリティクリティカル変更）」、references/flow/team-selection.md セクション 1（選定フロー）・セクション 2 パターン2（security-compliance）・セクション 3.1（ユーザー承認）・セクション 0.4（Step 4-T 実行手順）、flow.md Step 4-T（4-T-1〜4-T-4）、skill-rules-matrix.md C4（Agent Teams 採用判定）/ C23（検出言語・FW のチーム引き渡し）/ U14。

## 期待動作

- Step 3.5: 標準モード かつ 大規模変更（18 ファイル / 1,400 行）かつ 認証・認可のクリティカル変更のため、Agent Teams 採用条件を満たすと判定する（flow.md Step 3.5 採用条件）
- Step 3.5: team-selection.md セクション 1 の選定フローで差分の主たる性質（認証・認可）から **パターン2（security-compliance・リード security-engineer）** を候補に選ぶ
- Step 3.5: AskUserQuestion でメリット（今回の差分固有: 認証ロジックの攻撃シナリオを sec が提示し impl/legal/infra が相互反証して権限昇格経路を検出）とデメリット（通常レビューの最大 6 倍程度のコスト）を提示し、ユーザー承認を取る（team-selection.md セクション 3.1）
- ユーザーが「利用する」を選択したため **Step 4-T のみ実行**し、Step 4（観点別スキル並列）は行わない（flow.md Step 4-T 冒頭の排他注記・team-selection.md セクション 0.1）
- Step 4-T-1: 前段サブエージェント（dependency-safety / linter-static-analysis / dba（DB 絡む場合））を Agent ツールで並列起動する。観点別スキル経由ではない（二重起動防止・team-selection.md セクション 0.3）
- Step 4-T-2: TeamCreate でチームを作成し、前段サブエージェントの中間レポートを渡してメンバー（security-engineer / implementation-engineer / legal-advisor / infrastructure-engineer）をスポーンする
- Step 4-T-2: 各メンバーのスポーンプロンプトに Step 2 の「検出言語・FW と適用観点プロファイル」欄（C23）と U14 コード信頼性原則の注意喚起を必ず含める（flow.md Step 4-T-2）
- Step 4-T-3: 最低 3 ラウンドの議論で合意形成し、合意に至らない項目はトレードオフとして確認先を提示する
- Step 4-T-4: shutdown_request 送信 → TeamDelete でクリーンアップする
- Step 5 以降: 議論結果を統合し、Finding ID 採番・Verdict 判定・統合サマリ出力の共通フローを実行する
- Step 8: 集計セクションの「Agent Teams 採用パターン」に `security-compliance` を記載する（output-format.md セクション 1.4）
- （以下は検出してはならない誤り）
    - Step 4-T の最中に観点別スキル（Skill ツール）を呼び出す（二重起動禁止・flow.md Step 4-T 禁止事項）
    - 議論ラウンドを 3 未満で打ち切る
    - AskUserQuestion によるユーザー承認を取らずにチームを起動する（team-selection.md セクション 3.1）
    - Step 4-T と Step 4 を両方実行する（排他違反）

## 関連ケース

- case-11: Agent Teams 却下パス（サブエージェント方式へフォールバック）
- case-01: 軽微変更で Agent Teams を採用しないサブエージェント方式の基本フロー
