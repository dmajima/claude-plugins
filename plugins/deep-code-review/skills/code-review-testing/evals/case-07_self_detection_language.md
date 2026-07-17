# case-07 単独起動時の言語・FW 自己検出（O10 自己検出）

`language-profiles` 引数を受領しない単独起動で、本スキルが差分から言語・FW を自己検出し（language-detection.md の手順）、検出プロファイルを test-engineer / test-runner のプロンプトに適用するケース。オーケストレーターからの受領経路（case-06）ではなく、自己検出経路（O10 後段）を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "テストコードをレビューして"（`language-profiles` 引数なし） |
| 起動形態 | 単独（オーケストレーター不在・ユーザー直接起動） |
| 差分内容 | C# + xUnit のユニットテスト変更（`*.Tests/*.cs` + テストプロジェクトの `*.csproj`（`xunit` / `Microsoft.NET.Test.Sdk` を参照・ASP.NET Core / EF Core への参照なし）。`language-profiles` は未受領） |

## 分岐の根拠

SKILL.md「入力」表の「言語プロファイル」行「…未受領時は `${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` で自己検出する（O10）」、SKILL.md「実行フロー」手順 1.5「`language-profiles` の適用観点プロファイルを確認し（未受領時は … language-detection.md で自己検出）…」、references/skill-rules-matrix.md O10、`${CLAUDE_PLUGIN_ROOT}/references/common-references.md` セクション 4.5 手順 2（引数が無い場合（単独実行時）は language-detection.md の手順で自己検出する）、`${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` セクション 2〜3。

**既存ケースとの差別化**: case-06 は **オーケストレーターから `language-profiles` を受領した** 委譲経路（O10 前段・TypeScript + Vitest）を検証するのに対し、本ケースは **引数を受領しない単独起動** で本スキルが自ら language-detection.md の手順を実行して言語・FW を確定する **自己検出経路**（O10 後段）を、別言語（C# + xUnit）で検証する。

## 期待動作

- `language-profiles` 引数が無いことを検知し、`${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` の手順で自己検出に切り替える（SKILL.md 実行フロー手順 1.5 / common-references.md セクション 4.5 手順 2 / O10）
- 差分拡張子 `.cs` から C# を言語候補として列挙し、マーカーファイル `*.csproj` を Glob・Read する（language-detection.md セクション 3 Step 1〜3）
- `*.csproj` の依存を確認し、`xunit` / `Microsoft.NET.Test.Sdk` は検出するが **ASP.NET Core / EF Core のマーカーが無いため `frameworks/dotnet.md` は適用しない**（language-detection.md セクション 3 Step 3「マーカーファイルを確認せずに拡張子だけで FW を断定しない」・セクション 5 禁止事項）
- 検出結果から `languages/csharp.md`（主）を適用プロファイルに確定する（language-detection.md セクション 2.1）
- test-engineer / test-runner の各プロンプトに、common-references.md セクション 4.5 のテンプレートに従い、自己検出した csharp.md への参照指示を含める（O10）
- test-runner は csharp.md セクション 6 の動的検証コマンド（`dotnet test`）を参照する（対応 Bash 権限がなければ SKIPPED 記録。SKILL.md「動的検証」/ universal-rules.md U13）
- test-engineer は SKILL.md「前提」観点表の観点（網羅性・エッジケース・モック過剰・命名・AAA パターン遵守）で評価し、csharp.md の規約（命名・スタイル）を根拠補強に用いる（common-references.md セクション 4.5 の test-engineer 行）
- オーケストレーター不在のため、本スキル自身で progress.md を作成・維持する（checklist.md O8）
- プロジェクト独自規約が最優先で、プロファイルのデファクトはプロジェクト規約が無い項目のみに適用する（conventions-resolution.md の 5 段階解決）

## 関連ケース

- case-06: language-profiles 受領とエージェントへの適用（O10 前段・委譲経路）
- case-03: E2E テスト実行依頼（同じ単独起動・progress.md 自スキル作成）
