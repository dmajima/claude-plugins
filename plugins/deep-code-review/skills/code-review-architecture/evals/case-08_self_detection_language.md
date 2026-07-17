# case-08 単独起動時の言語・FW 自己検出（O10 自己検出）

`language-profiles` 引数を受領しない単独起動で、本スキルが差分から言語・FW を自己検出し（language-detection.md の手順）、検出プロファイルを architect のプロンプトに適用するケース。DB 変更が無いため dba は内部省略する。オーケストレーターからの受領経路（case-06）ではなく、自己検出経路（O10 後段）を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "アーキテクチャ観点でレビューして"（`language-profiles` 引数なし） |
| 起動形態 | 単独（オーケストレーター不在・ユーザー直接起動） |
| 差分内容 | C# + ASP.NET Core のアプリケーション層リファクタリング（サービスクラス追加・DI 登録変更。`.cs` + `*.csproj`（`Microsoft.AspNetCore.*` / `Microsoft.NET.Sdk.Web`）。SQL / マイグレーション / DB スキーマ変更は無し。`language-profiles` は未受領） |

## 分岐の根拠

SKILL.md「入力」表の「言語プロファイル」行「…未受領時は `${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` で自己検出する（O10）」、SKILL.md「実行フロー」手順 1.5（未受領時は language-detection.md で自己検出）および手順 2（DB 変更判定 → dba 起動可否決定）、SKILL.md「動的に省略可（責務はオーケストレーター）」の表（architect: 常に起動 / dba: SQL・DB スキーマ・マイグレーション変更が一切ない場合のみ内部で省略）、references/skill-rules-matrix.md O10、`${CLAUDE_PLUGIN_ROOT}/references/common-references.md` セクション 4.5 手順 2、`${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` セクション 2〜3。

**既存ケースとの差別化**: case-06 は **オーケストレーターから `language-profiles`（SQL + ORM）を受領した** 委譲経路（O10 前段・dba 主担当）を検証する。case-03 は同じ単独起動だが **DB 変更ありで dba を起動し progress.md 自スキル作成** を主眼とする。本ケースは **引数を受領しない単独起動 + DB 変更なし** で、architect が自ら csharp.md / dotnet.md を自己検出して適用し dba を内部省略する **自己検出経路**（O10 後段）を検証する。

## 期待動作

- `language-profiles` 引数が無いことを検知し、`${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` の手順で自己検出に切り替える（SKILL.md 実行フロー手順 1.5 / common-references.md セクション 4.5 手順 2 / O10）
- 差分拡張子 `.cs` から C# を列挙し、マーカーファイル `*.csproj` を Glob・Read して `Microsoft.AspNetCore.*` / `Microsoft.NET.Sdk.Web` を確認する（language-detection.md セクション 3 Step 1〜3。マーカーを確認せず拡張子だけで断定しない）
- 検出結果から `languages/csharp.md`（主）+ `frameworks/dotnet.md`（ASP.NET Core）を適用プロファイルに確定する（language-detection.md セクション 2.1 / 2.2）
- 差分に SQL / DB スキーマ / マイグレーション変更が一切ないと判定し、dba を内部省略する（SKILL.md「実行フロー」手順 2 / 「動的に省略可」の表）。architect は常に起動する
- architect のプロンプトに、common-references.md セクション 4.5 のテンプレートに従い、自己検出した csharp.md / dotnet.md への参照指示を含める（O10）
- architect は dotnet.md の DI ライフタイム・レイヤリング・依存方向の観点と csharp.md セクション 5（フレームワーク観点）を、コンポーネント境界・技術的負債の評価に用いる（common-references.md セクション 4.5 の architect 行）
- 中間レポートは「## アーキテクチャ観点レビュー結果」+「### architect」の構造で返却し、dba を省略した旨と理由（DB 変更なし）を明記する（SKILL.md「出力フォーマット」/ checklist.md C-Auto-1 / C-Auto-3）
- オーケストレーター不在のため、本スキル自身で progress.md を作成・維持する（checklist.md O8）
- 検出されなかった言語・FW のプロファイルは適用しない（language-detection.md セクション 5 禁止事項）

## 関連ケース

- case-06: language-profiles 受領と FW 構造観点への適用（O10 前段・委譲経路）
- case-02: DB 変更なし（dba 内部省略・省略理由の明記）
- case-03: 単独起動（progress.md 自スキル作成・DB 変更あり）
