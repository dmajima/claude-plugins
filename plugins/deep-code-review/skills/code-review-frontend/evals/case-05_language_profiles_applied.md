# case-05 言語プロファイル受領と web-designer への適用（O10）

オーケストレーターから `language-profiles` 引数を受け取り、検出言語・FW の観点を web-designer のプロンプトに反映するケース。O10 の委譲経路とテンプレートエンジン横断（React + CSS）を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `<差分スコープ> <プロジェクト規約サマリ> language-profiles=languages/html.md, languages/css.md, frameworks/react.md(主) mode=standard` |
| 起動形態 | 委譲（code-review オーケストレーターから Skill ツール経由） |
| 差分内容 | React コンポーネント + CSS の変更（`.tsx` + `.css`）。テンプレートは JSX |

## 分岐の根拠

references/skill-rules-matrix.md O10、`${CLAUDE_PLUGIN_ROOT}/references/common-references.md` セクション 4.5、SKILL.md 実行フロー手順 1.5。

## 期待動作

- 実行フロー手順 1.5 で `language-profiles` 引数を解釈し、適用プロファイル（`${CLAUDE_PLUGIN_ROOT}/references/languages/html.md` + `css.md` + `frameworks/react.md`（主））を確定する（O10）
- web-designer のプロンプトに、common-references.md セクション 4.5 のテンプレートに従って言語プロファイル参照指示を含める
- web-designer は html.md 観点（セマンティクス・a11y・テンプレートエンジンのエスケープ迂回）と css.md 観点（詳細度・BEM・レスポンシブ・a11y）と react.md 観点（hooks ルール・key 欠落・dangerouslySetInnerHTML の XSS・不要再レンダリング）を評価に使用する
- JSX（`.tsx`）内のマークアップは html.md、スタイルは css.md、コンポーネントロジックは react.md で横断的に評価する
- プロジェクト独自規約が最優先で、プロファイルのデファクトはプロジェクト規約が無い項目のみに適用する

## 関連ケース

- case-01: 委譲・UI 変更（language-profiles を含む基本委譲）
- code-review/case-06: オーケストレーター側の言語検出（送出側）
