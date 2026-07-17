# case-06 言語プロファイル受領とエージェントへの適用（O10）

オーケストレーターから `language-profiles` 引数を受け取り、検出言語の観点プロファイルを内部エージェントのプロンプトに反映するケース。O10 の委譲経路を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `<差分スコープ> <プロジェクト規約サマリ> language-profiles=languages/typescript.md(主), frameworks/frontend-tooling.md mode=standard` |
| 起動形態 | 委譲（code-review オーケストレーターから Skill ツール経由） |
| 差分内容 | TypeScript + Vitest テストの変更（`.ts` + `.test.ts`） |

## 分岐の根拠

references/skill-rules-matrix.md O10、`${CLAUDE_PLUGIN_ROOT}/references/common-references.md` セクション 4.5、SKILL.md 実行フロー手順 1.5。

## 期待動作

- 実行フロー手順 1.5 で `language-profiles` 引数を解釈し、適用プロファイル（`${CLAUDE_PLUGIN_ROOT}/references/languages/typescript.md`（主）+ `frameworks/frontend-tooling.md`）を確定する（O10）
- test-engineer / test-runner の各プロンプトに、common-references.md セクション 4.5 のテンプレートに従って言語プロファイル参照指示を含める
- test-engineer は typescript.md のテスト規約と frontend-tooling.md の Vitest / Jest 観点（テストの独立性・非同期テストの await 漏れ・モックリセット漏れ・カバレッジ偽装）を評価に使用する
- test-runner は typescript.md セクション 6 の動的検証コマンド（`vitest run`）を参照する
- プロジェクト独自規約が最優先で、プロファイルのデファクトはプロジェクト規約が無い項目のみに適用する

## 関連ケース

- case-01: 委譲・runner 実行あり（language-profiles を含む基本委譲）
- code-review/case-06: オーケストレーター側の言語検出（送出側）
