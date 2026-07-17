# case-19 Agent Teams パターン5 選定（大規模 UI・Vue.js 再設計・Liquid 再構築主体・frontend-quality-extended）（C4）

標準モードで大規模 UI 刷新・Vue.js コンポーネント設計の全面再構成・Liquid/DotLiquid テンプレート再構築主体の大規模差分をレビューし、Step 3.5 で Agent Teams パターン5（frontend-quality-extended・リード architect + impl / test / sec、前段 web-designer 重点）を選定、ユーザー承認を経て Step 4-T で継続するケース。差分の主たる性質が「大規模 UI・Vue.js 再設計・Liquid 再構築」である点で、セキュリティクリティカル起点の case-10（パターン2）・DB 起点の case-17（パターン4）・大規模設計変更起点の case-18（パターン3）と選定分岐が異なる。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "このブランチをレビューして"（差分: 大規模 UI 刷新・Vue.js コンポーネント設計の全面再構成・Liquid/DotLiquid テンプレート再構築主体 22 ファイル / 約 1,800 行。アクセシビリティ要件強化・フロントエンドビルド設定変更を含む） |
| モード | 対話（標準） |

## 分岐の根拠

references/flow/flow.md Step 3.5「採用条件（標準モード かつ 大規模UI/フロントエンド変更 / 大規模変更（10ファイル超 or 1,000行超））」、references/flow/team-selection.md セクション 1（選定フロー: 大規模UI・Vue.js設計・Liquid/DotLiquid再構築 → パターン5）・セクション 2 パターン5（frontend-quality-extended・起動条件「大規模UI変更、Vue.js コンポーネント設計刷新、Liquid/DotLiquid テンプレート再構築、アクセシビリティ要件強化、フロントエンドビルド設定変更」・前段 web-designer 重点）・セクション 3.1（ユーザー承認）・セクション 0.4（Step 4-T 実行手順）、flow.md Step 4-T（4-T-1〜4-T-4）、skill-rules-matrix.md C4（Agent Teams 採用判定）/ C23（検出言語・FW のチーム引き渡し）/ U14。差分の主たる性質を「大規模 UI・Vue.js 再設計・Liquid 再構築」と判定し前段に web-designer を重点起用する点で、パターン2 の case-10・パターン4 の case-17・パターン3 の case-18 と分岐が分かれる（パターン4 が dba を重点起用するのに対しパターン5 は web-designer を重点起用）。

## 期待動作

- Step 3.5: 標準モード かつ 大規模UI/フロントエンド変更（22 ファイル / 1,800 行・Vue.js 再設計・Liquid 再構築）のため Agent Teams 採用条件を満たすと判定する（flow.md Step 3.5 採用条件）
- Step 3.5: team-selection.md セクション 1 の選定フローで差分の主たる性質（大規模UI・Vue.js設計・Liquid/DotLiquid再構築）から **パターン5（frontend-quality-extended・リード architect・メンバー implementation-engineer / test-engineer / security-engineer）** を選ぶ
- Step 3.5: AskUserQuestion でメリット（今回の差分固有: Vue コンポーネント分割粒度・Liquid/DotLiquid テンプレートの XSS / null 安全性・WCAG 2.2 AA 準拠を web-designer 重点レポートに基づき impl / test / sec が相互検証し、単独レビューで見落としやすいテンプレート XSS の影響範囲・UI 変更のバックエンド契約への影響を検出）とデメリット（通常レビューの最大 6 倍程度のコスト）を提示し、ユーザー承認を取る（team-selection.md セクション 3.1）
- ユーザーが「利用する」を選択したため **Step 4-T のみ実行**し、Step 4（観点別スキル並列）は行わない（flow.md Step 4-T 冒頭の排他注記・team-selection.md セクション 0.1）
- Step 4-T-1: 前段サブエージェントとして **web-designer（重点）** + linter-static-analysis + test-runner を Agent ツールで並列起動する。観点別スキル経由ではない（二重起動防止・team-selection.md パターン5）
- Step 4-T-2: TeamCreate でチームを作成し、**web-designer の中間レポートを重点情報として**メンバー（architect / implementation-engineer / test-engineer / security-engineer）に渡してスポーンする
- Step 4-T-2: 各メンバーのスポーンプロンプトに Step 2 の「検出言語・FW と適用観点プロファイル」欄（C23）と U14 コード信頼性原則の注意喚起を必ず含める（flow.md Step 4-T-2）
- Step 4-T-3: 最低 3 ラウンドの議論で合意形成し、合意に至らない項目はトレードオフとして確認先（ユーザー / PdM / 顧客）を提示する
- Step 4-T-4: shutdown_request 送信 → TeamDelete でクリーンアップする
- Step 5 以降: 議論結果を統合し、Finding ID 採番・Verdict 判定・統合サマリ出力の共通フローを実行する
- Step 8: 集計セクションの「Agent Teams 採用パターン」に `frontend-quality-extended` を記載する（output-format.md セクション 1.4）
- （以下は検出してはならない誤り）
    - 大規模 UI・フロントエンド主体の差分に対しパターン1（quality-assurance）を選び web-designer を前段の重点に据えない（主たる性質の誤判定）
    - web-designer を前段サブエージェントの重点に据えず通常観点のまま扱う
    - Step 4-T の最中に観点別スキル（Skill ツール）を呼び出す（二重起動禁止・flow.md Step 4-T 禁止事項）
    - 議論ラウンドを 3 未満で打ち切る
    - AskUserQuestion によるユーザー承認を取らずにチームを起動する（team-selection.md セクション 3.1）
    - Step 4-T と Step 4 を両方実行する（排他違反）

## 関連ケース

- case-17: Agent Teams パターン4 選定（DB 主体・data-quality-extended・承認パス）
- case-18: Agent Teams パターン3 選定（大規模設計変更・system-design・承認パス）
- case-10: Agent Teams パターン2 選定（security-compliance・承認パス）
- case-11: Agent Teams 却下 → サブエージェント方式フォールバック（パターン1）
