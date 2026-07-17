# case-11 Agent Teams 却下 → サブエージェント方式フォールバック（C4）

Step 3.5 で Agent Teams 採用条件を満たし提案したが、ユーザーが AskUserQuestion で「利用しない（サブエージェント）」を選択したため、Step 4-T を実行せず Step 4（観点別スキル並列・Independent 型）にフォールバックするケース。case-10（承認パス）と対になる分岐。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "このブランチをレビューして"（差分: 複数モジュールに跨る大規模変更 14 ファイル / 約 1,100 行。単純なリファクタ主体で認証・DB・UI の主性質なし） |
| モード | 対話（標準） |

## 分岐の根拠

references/flow/flow.md Step 3.5「採用条件（標準モード かつ 大規模変更）」およびフォールバック条件「ユーザーが却下」、references/flow/team-selection.md セクション 1（選定フロー・上記以外の標準的な品質レビュー → パターン1 quality-assurance）・セクション 3.1（ユーザー承認）・セクション 4（フォールバック条件「ユーザーが『サブエージェントで』を選択」）、skill-rules-matrix.md C4 / C3（観点別スキル並列起動）。

## 期待動作

- Step 3.5: 標準モード かつ 大規模変更（14 ファイル / 1,100 行）のため Agent Teams 採用条件を満たすと判定する
- Step 3.5: team-selection.md セクション 1 の選定フローで、差分に認証/DB/UI の主性質がないため **パターン1（quality-assurance・リード architect）** を候補に選ぶ
- Step 3.5: AskUserQuestion でメリット（差分固有の議論効果）とデメリット（最大 6 倍のコスト）を提示し承認を求める（team-selection.md セクション 3.1）
- ユーザーが「利用しない（サブエージェント）」を選択したため、**Step 4-T を実行せず Step 4 にフォールバックする**（flow.md Step 3.5 フォールバック条件「ユーザーが却下」・team-selection.md セクション 4）
- TeamCreate / TaskCreate を一切呼ばない（チームを組成しない）
- Step 4: 標準モードの観点別スキル（impl / testing / security ＋設計影響で architecture ＋ UI 変更で frontend）を 1 メッセージ内で並列起動する（Independent 型・C3）
- Step 5 以降: サブエージェント方式の結果を統合し、Finding ID 採番・Verdict 判定・統合サマリ出力の共通フローを実行する
- Step 8: 集計セクションの「Agent Teams 採用パターン」に `不採用（サブエージェント方式）` を記載する（output-format.md セクション 1.4）
- （以下は検出してはならない誤り）
    - ユーザーが却下したのに TeamCreate を実行してチームを組成する
    - 却下後に Step 4-T と Step 4 を両方実行する
    - フォールバック後も集計セクションで Agent Teams を「採用」と記載する
    - 却下を理由にレビュー自体を中止する（フォールバックして完遂する）

## 関連ケース

- case-10: Agent Teams 承認パス（Step 4-T で継続）
- case-01: サブエージェント方式（観点別スキル並列）の基本フロー
