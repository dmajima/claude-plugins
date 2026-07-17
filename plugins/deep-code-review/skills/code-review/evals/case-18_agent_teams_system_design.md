# case-18 Agent Teams パターン3 選定（大規模設計変更・技術選定主体・system-design）（C4）

標準モードで大規模リファクタリング・コンポーネント境界再設計・技術選定変更主体の大規模差分をレビューし、Step 3.5 で Agent Teams パターン3（system-design・リード architect + impl / sec / pl）を選定、ユーザー承認を経て Step 4-T で継続するケース。差分の主たる性質が「大規模設計変更・技術選定」である点で、セキュリティクリティカル起点の case-10（パターン2）・DB 起点の case-17（パターン4）・主性質なしで却下される case-11（パターン1）と選定分岐が異なる。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "このブランチをレビューして"（差分: 大規模リファクタリング・コンポーネント境界の再設計・状態管理ライブラリの技術選定変更主体 20 ファイル / 約 1,600 行。DI コンテナ刷新・モジュール依存方向の変更を含む） |
| モード | 対話（標準） |

## 分岐の根拠

references/flow/flow.md Step 3.5「採用条件（標準モード かつ 大規模設計変更 / 大規模変更（10ファイル超 or 1,000行超））」、references/flow/team-selection.md セクション 1（選定フロー: 大規模リファクタ・コンポーネント境界変更・技術選定 → パターン3）・セクション 2 パターン3（system-design・起動条件「大規模リファクタリング、コンポーネント境界変更、DI/状態管理刷新、技術スタック変更、依存方向の変更」）・セクション 3.1（ユーザー承認）・セクション 0.4（Step 4-T 実行手順）、flow.md Step 4-T（4-T-1〜4-T-4）、skill-rules-matrix.md C4（Agent Teams 採用判定）/ C23（検出言語・FW のチーム引き渡し）/ U14。差分の主たる性質を「大規模設計変更・技術選定」と判定する点で、認証・認可主体でパターン2 を選ぶ case-10、DB スキーマ主体でパターン4 を選ぶ case-17、主性質がなくパターン1 を提案して却下される case-11 と分岐が分かれる。

## 期待動作

- Step 3.5: 標準モード かつ 大規模設計変更（20 ファイル / 1,600 行・コンポーネント境界の再設計・状態管理の技術選定変更）のため Agent Teams 採用条件を満たすと判定する（flow.md Step 3.5 採用条件）
- Step 3.5: team-selection.md セクション 1 の選定フローで差分の主たる性質（大規模リファクタ・コンポーネント境界変更・技術選定）から **パターン3（system-design・リード architect・メンバー implementation-engineer / security-engineer / project-leader）** を選ぶ
- Step 3.5: AskUserQuestion でメリット（今回の差分固有: コンポーネント境界の再設計・依存方向の変更に対し arch の設計案を impl が実装実現性・sec が攻撃面の変化・pl がスコープ / スケジュール影響から相互反証し、単独レビューで見落としやすい設計負債・移行リスクを検出）とデメリット（通常レビューの最大 6 倍程度のコスト）を提示し、ユーザー承認を取る（team-selection.md セクション 3.1）
- ユーザーが「利用する」を選択したため **Step 4-T のみ実行**し、Step 4（観点別スキル並列）は行わない（flow.md Step 4-T 冒頭の排他注記・team-selection.md セクション 0.1）
- Step 4-T-1: 前段サブエージェントとして linter-static-analysis + performance-reviewer + test-runner を Agent ツールで並列起動する。観点別スキル経由ではない（二重起動防止・team-selection.md パターン3）
- Step 4-T-2: TeamCreate でチームを作成し、前段サブエージェントの中間レポートを渡してメンバー（architect / implementation-engineer / security-engineer / project-leader）をスポーンする
- Step 4-T-2: 各メンバーのスポーンプロンプトに Step 2 の「検出言語・FW と適用観点プロファイル」欄（C23）と U14 コード信頼性原則の注意喚起を必ず含める（flow.md Step 4-T-2）
- Step 4-T-3: 最低 3 ラウンドの議論で合意形成し、合意に至らない項目はトレードオフとして確認先（ユーザー / PdM / 顧客）を提示する
- Step 4-T-4: shutdown_request 送信 → TeamDelete でクリーンアップする
- Step 5 以降: 議論結果を統合し、Finding ID 採番・Verdict 判定・統合サマリ出力の共通フローを実行する
- Step 8: 集計セクションの「Agent Teams 採用パターン」に `system-design` を記載する（output-format.md セクション 1.4）
- （以下は検出してはならない誤り）
    - 大規模設計変更・技術選定主体の差分に対しパターン1（quality-assurance）を選ぶ（主たる性質の誤判定でリード / メンバー構成が変わる）
    - パターン3 のメンバーに legal-advisor / infrastructure-engineer（パターン2 の構成）を混在させる
    - Step 4-T の最中に観点別スキル（Skill ツール）を呼び出す（二重起動禁止・flow.md Step 4-T 禁止事項）
    - 議論ラウンドを 3 未満で打ち切る
    - AskUserQuestion によるユーザー承認を取らずにチームを起動する（team-selection.md セクション 3.1）
    - Step 4-T と Step 4 を両方実行する（排他違反）

## 関連ケース

- case-17: Agent Teams パターン4 選定（DB 主体・data-quality-extended・承認パス）
- case-19: Agent Teams パターン5 選定（大規模 UI 主体・frontend-quality-extended・承認パス）
- case-10: Agent Teams パターン2 選定（security-compliance・承認パス）
- case-11: Agent Teams 却下 → サブエージェント方式フォールバック（パターン1）
