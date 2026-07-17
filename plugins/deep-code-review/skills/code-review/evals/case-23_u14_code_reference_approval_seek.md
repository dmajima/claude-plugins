# case-23 U14 コード信頼性原則のコード類推 承認シークフロー（明文化規約なし → AskUserQuestion 2択）

提出差分が明文化規約のない新規パターンを導入し、規約を差分外の既存コードまたは提出コード内パターンから類推せざるを得ない状況で、コード類推の可否をユーザーに承認シークするケース。case-03（前回承認済みパターンの再利用）と対になり、本ケースは承認シーク本体（検出 → 承認取得 → 記録 / 非承認継続）を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "このブランチをレビューして"（提出差分が独自パターン（例: 独自 Repository パターン / 独自例外クラス / 独自命名規約）を新規導入。`CLAUDE.md` / `.claude/rules/` / `.editorconfig` に該当規約なし・inputs フォルダに関連仕様なし → 差分外の既存コードまたは提出コード内のパターンから規約を類推せざるを得ない） |
| モード | 対話 |

## 分岐の根拠

references/skill-rules-matrix.md セクション 2 U14（提出コード内のパターンを規約として類推しない。類推が必要な場合はユーザー承認を義務化し、承認結果を state.yaml に記録）+ セクション 4 C20（U14 のオーケストレーター適用）。承認シークの検出・取得・記録は references/state/code-trustworthiness.md セクション 3.1（承認が必要な場面の検出）/ 3.2（承認の取り方）/ 3.3（承認結果の記録）、無断類推の禁止は同 セクション 5 禁止事項。フロー上の適用点は references/flow/flow.md Step 0-P-4（コード信頼性原則の適用準備）および Step 2「コード信頼性原則の適用」。

## 期待動作

- Step 2: プロジェクト規約読込で `CLAUDE.md` / `.claude/CLAUDE.md` / `.claude/rules/**/*.md` / `.editorconfig` / `CONTRIBUTING.md` を探索し、当該パターンに対応する明文化規約が存在しないことを確認する（code-trustworthiness.md セクション 2.1 の無条件参照可能な情報源に該当なし）
- Step 0-P-3 / Step 2: inputs フォルダに当該パターンに関する仕様記述が無いこと（inputs 空 or 該当記述なし）を確認する
- 検出 (a): 「明文化規約なし」かつ「inputs に関連仕様なし」かつ「提出コードのパターンの是非を規約上の根拠で判断できない」が揃うため、コードからの規約類推が必要な状況として検出する（code-trustworthiness.md セクション 3.1 のトリガー表）
- 承認シーク (a): コードからの類推を行う前に `AskUserQuestion` を発火する。header は「コード類推」、question に対象パターンの説明と情報源（差分外の既存コード / 提出コード内）を明示し、選択肢は「参考にしてよい」「参考にしない」の 2 択（multiSelect: false）とする（code-trustworthiness.md セクション 3.2）
- 承認時＝「参考にしてよい」(b): 当該パターンをレビュー基準に含め、`project-rules-summary` に「ユーザー承認済みのコード類推パターン」として追記し、Step 4 で観点別スキルへ引き継ぐ（code-trustworthiness.md セクション 4.1 / flow.md Step 4）
- 承認時の記録 (b): 承認結果を state.yaml トップレベルの `code_as_reference_decisions` に `description` / `user_approved: true` / `approved_at` / `context` 付きで記録する（code-trustworthiness.md セクション 3.3 / references/flow/flow-steps-output.md Step 8.5 / references/state/state-management.md の `code_as_reference_decisions`）
- 非承認時＝「参考にしない」(c): 明文化された規約のみでレビューを継続し、当該コードパターンからの規約類推は行わない（該当観点の指摘は規約上の根拠がある項目に限定する）
- 非承認時の記録 (c): 承認シークの結果（`user_approved: false`）も `code_as_reference_decisions` に記録する（code-trustworthiness.md セクション 5 禁止事項「ユーザー承認の結果を state.yaml に記録しないこと」の裏返し）
- 共通: いずれの分岐でも `project-rules-summary` 末尾に「提出コードのパターンを規約として類推しない」旨の U14 注意喚起を含めて観点別スキルへ渡す（code-trustworthiness.md セクション 4.1 / flow.md Step 4）
- 禁止動作（NG・発生してはならない）: ユーザー承認を得ずに提出コードまたは差分外既存コードのパターンを規約として無断類推し、それを根拠に指摘・評価を行うこと（code-trustworthiness.md セクション 5 禁止事項）

## 関連ケース

- case-03: 前回 state.yaml の `code_as_reference_decisions` を引き継いだ承認済みパターンの再利用（本ケースの承認シーク結果を次回消費する対の分岐）
- case-01: 初回レビュー（state.yaml なし・`project-rules-summary` 末尾への U14 注意喚起の付与を前提として共有）
