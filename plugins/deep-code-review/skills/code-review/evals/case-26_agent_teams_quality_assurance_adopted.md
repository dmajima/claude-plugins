# case-26 Agent Teams パターン1 採用（標準的大規模品質レビュー・quality-assurance）（C4）

標準モードで認証/DB/UI/大規模設計のいずれの主性質も持たない大規模差分をレビューし、Step 3.5 で Agent Teams パターン1（quality-assurance）を選定、ユーザー承認を経て Step 4-T で継続するケース。同じパターン1を却下する case-11 と対になり、パターン1 の採用（実行）パスを網羅する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "このブランチをレビューして"（差分: 複数モジュールに跨る一般的な品質改善 12 ファイル / 約 1,050 行。認証・決済・PII・DB スキーマ・大規模設計変更・UI 刷新のいずれの主性質もなし） |
| モード | 対話（標準） |

## 分岐の根拠

references/flow/flow.md Step 3.5「採用条件（標準モード かつ 大規模変更）」、references/flow/team-selection.md セクション1（選定フロー: 認証/DB/UI/大規模設計の主性質なし → パターン1 quality-assurance）・references/flow/team-selection-patterns.md セクション2 パターン1（quality-assurance）、references/flow/team-selection-flow.md セクション0.1（Step 4 / Step 4-T 排他）・セクション0.4（実行手順）・セクション3.1（ユーザー承認）、flow.md Step 4-T（4-T-1〜4-T-4）、skill-rules-matrix.md C4 / C23 / U14。

## 期待動作

- Step 3.5: 標準モード かつ 大規模変更（12 ファイル / 1,050 行）かつ複数観点に跨るため Agent Teams 採用条件を満たすと判定する（flow.md Step 3.5）
- Step 3.5: team-selection.md セクション1の選定フローで、差分に認証/決済/PII/DB/大規模設計/UI の主性質がないため **パターン1（quality-assurance・リード architect・メンバー implementation-engineer / test-engineer / security-engineer）** を選ぶ（team-selection-patterns.md セクション2 パターン1）
- Step 3.5: AskUserQuestion でメリット（今回の差分固有: 実装正確性・テスト網羅性・セキュリティ・アーキテクチャ整合性の各次元を4メンバーが相互反証し、単独レビューで見落としやすい欠陥を検出）とデメリット（通常の最大6倍程度のコスト）を提示し承認を取る（team-selection-flow.md セクション3.1）
- ユーザーが「利用する」を選択したため **Step 4-T のみ実行**し、Step 4（観点別スキル並列）は行わない（排他・team-selection-flow.md セクション0.1）
- Step 4-T-1: 前段サブエージェントとして linter-static-analysis / performance-reviewer / dependency-safety / test-runner を Agent ツールで並列起動する（パターン1 の前段構成・観点別スキル経由ではない・二重起動防止）
- Step 4-T-2: TeamCreate でチーム（architect / implementation-engineer / test-engineer / security-engineer）を作成し、前段の中間レポートを渡してスポーンする
- Step 4-T-2: 各メンバーのスポーンプロンプトに Step 2 の「検出言語・FW と適用観点プロファイル」欄（C23）と U14 コード信頼性原則の注意喚起を必ず含める
- Step 4-T-3: 最低 3 ラウンドの議論で品質次元間のトレードオフを含め合意形成し、合意に至らない項目は確認先を提示する
- Step 4-T-4: shutdown_request 送信 → TeamDelete でクリーンアップする
- Step 8: 集計セクションの「Agent Teams 採用パターン」に `quality-assurance` を記載する（output-format.md セクション1.4）
- （以下は検出してはならない誤り）
    - パターン1 なのに前段サブエージェントで dba / web-designer を重点起動する（パターン4/5 の誤選定）
    - Step 4-T の最中に観点別スキル（Skill ツール）を呼び出す（二重起動禁止・排他違反）
    - Step 4-T と Step 4 を両方実行する（排他違反）
    - 承認を取らずに TeamCreate を実行してチームを組成する

## 関連ケース

- case-11: パターン1 却下 → サブエージェント方式フォールバック（本ケースの承認 / 却下の対）
- case-17: パターン4 採用（DB 主体・data-quality-extended）
- case-10: パターン2 採用（security-compliance）
