# case-07 言語プロファイル受領とエージェントへの適用（O10）

オーケストレーターから `language-profiles` 引数を受け取り、検出言語・FW の観点プロファイルを内部エージェントのプロンプトに反映するケース。O10 の委譲経路を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `<差分スコープ> <プロジェクト規約サマリ> language-profiles=languages/csharp.md(主), frameworks/dotnet.md, frameworks/orm.md mode=standard` |
| 起動形態 | 委譲（code-review オーケストレーターから Skill ツール経由） |
| 差分内容 | C# / ASP.NET Core + EF Core の変更（`.cs` + `.csproj`） |

## 分岐の根拠

references/skill-rules-matrix.md O10（`language-profiles` 引数に基づき検出言語・FW の観点プロファイルをエージェントプロンプトに含める）、`${CLAUDE_PLUGIN_ROOT}/references/common-references.md` セクション 4.5、`${CLAUDE_PLUGIN_ROOT}/references/agents.md` セクション 4.3.5、SKILL.md 実行フロー手順 1.5。

## 期待動作

- 実行フロー手順 1.5 で `language-profiles` 引数を解釈し、適用プロファイル（`${CLAUDE_PLUGIN_ROOT}/references/languages/csharp.md`（主）+ `frameworks/dotnet.md` + `frameworks/orm.md`）を確定する（O10）
- implementation-engineer / linter-static-analysis / performance-reviewer の各プロンプトに、common-references.md セクション 4.5 のテンプレートに従って言語プロファイル参照指示を含める
- implementation-engineer は csharp.md 観点 3.1〜3.5・3.8（正確性 / エラー処理・silent-failure / 型・null 安全 / 非同期 / 命名・スタイル / コメント整合）と dotnet.md の DI ライフタイム・EF Core 観点を評価に使用する
- performance-reviewer は csharp.md 観点 3.6 と dotnet.md / orm.md の N+1・AsNoTracking 観点を評価に使用する
- linter-static-analysis は csharp.md セクション 6 の動的検証コマンド（`dotnet build` / `dotnet format`）を参照する
- プロジェクト独自規約（適用規約サマリ）が最優先で、プロファイルのデファクトはプロジェクト規約が無い項目のみに適用する（conventions-resolution.md）

## 関連ケース

- case-01: 委譲・spec_summary なし（language-profiles を含む基本委譲）
- code-review/case-06: オーケストレーター側の言語検出（送出側）
