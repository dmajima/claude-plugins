# case-17 Agent Teams パターン4 選定（DB 変更主体・data-quality-extended）（C4）

標準モードで DB スキーマ・マイグレーション主体の大規模差分をレビューし、Step 3.5 で Agent Teams パターン4（data-quality-extended・dba 重点）を選定、ユーザー承認を経て Step 4-T で継続するケース。パターン2 採用の case-10・パターン1 却下の case-11 と合わせ、選定フローの分岐を網羅する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "このブランチをレビューして"（差分: スキーマ変更・マイグレーション・ストアドプロシージャ主体 16 ファイル / 約 1,300 行。NOT NULL 追加・インデックス再設計・大量データ移行スクリプトを含む） |
| モード | 対話（標準） |

## 分岐の根拠

references/flow/flow.md Step 3.5「採用条件（標準モード かつ DB スキーマ・マイグレーション変更）」、references/flow/team-selection.md セクション 1（選定フロー: DB スキーマ・マイグ・SP・大量クエリ → パターン4）・セクション 2 パターン4（data-quality-extended）・セクション 3.1（ユーザー承認）、flow.md Step 4-T（4-T-1〜4-T-4・パターン4 の前段 dba 重点例）、skill-rules-matrix.md C4 / C23 / U14。

## 期待動作

- Step 3.5: 標準モード かつ DB スキーマ・マイグレーション主体の大規模変更（16 ファイル / 1,300 行）のため Agent Teams 採用条件を満たすと判定する（flow.md Step 3.5 採用条件）
- Step 3.5: team-selection.md セクション 1 の選定フローで差分の主たる性質（DB スキーマ・マイグ・SP）から **パターン4（data-quality-extended・リード architect・メンバー impl / test / sec）** を選ぶ
- Step 3.5: AskUserQuestion でメリット（今回の差分固有: マイグレーションのロック / ロールバック安全性・データ整合性を dba 重点レポートに基づき impl / test / sec が相互検証）とデメリット（通常レビューの最大 6 倍程度のコスト）を提示し承認を取る（team-selection.md セクション 3.1）
- ユーザーが「利用する」を選択したため **Step 4-T のみ実行**し、Step 4（観点別スキル並列）は行わない（排他・team-selection.md セクション 0.1）
- Step 4-T-1: 前段サブエージェントとして **dba（重点）** + performance-reviewer + linter-static-analysis + test-runner を Agent ツールで並列起動する（観点別スキル経由ではない・二重起動防止・team-selection.md パターン4）
- Step 4-T-2: TeamCreate でチームを作成し、**dba の中間レポートを重点情報として**メンバー（architect / implementation-engineer / test-engineer / security-engineer）に渡してスポーンする
- Step 4-T-2: 各メンバーのスポーンプロンプトに Step 2 の「検出言語・FW と適用観点プロファイル」欄（C23）と U14 コード信頼性原則の注意喚起を必ず含める
- Step 4-T-3: 最低 3 ラウンドの議論で合意形成し、合意に至らない項目はトレードオフとして確認先を提示する
- Step 4-T-4: shutdown_request 送信 → TeamDelete でクリーンアップする
- Step 8: 集計セクションの「Agent Teams 採用パターン」に `data-quality-extended` を記載する（output-format.md セクション 1.4）
- （以下は検出してはならない誤り）
    - Step 4-T の最中に観点別スキル（Skill ツール）を呼び出す（二重起動禁止・flow.md Step 4-T 禁止事項）
    - DB 主体の差分に対しパターン1（quality-assurance）やパターン2（security-compliance）を選ぶ（主たる性質の誤判定）
    - dba を前段サブエージェントの重点に据えず通常観点のまま扱う
    - Step 4-T と Step 4 を両方実行する（排他違反）

## 関連ケース

- case-10: Agent Teams 採用（パターン2 security-compliance・承認パス）
- case-11: Agent Teams 却下 → サブエージェント方式フォールバック（パターン1）
