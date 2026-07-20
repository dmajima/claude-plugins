# case-09 playwright 系登録が複数 × 非対話（優先採用）

非対話モードで `claude mcp list` に playwright 系の登録が複数見つかる場合に、AskUserQuestion を使わず規約の優先順位で採用を確定することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target=<slug> --non-interactive` |
| 起動形態 | 委譲（オーケストレータ test の setup フェーズ・非対話） |
| 前提 | `claude mcp list` に playwright 系サーバーが複数登録されている（例: 登録名 `playwright` と、別名で Playwright MCP を起動する登録の 2 件） |

## 分岐の根拠

`${CLAUDE_SKILL_DIR}/references/setup-procedures.md` 3.1（既存登録の検出・複数件の対応: 非対話時は登録名 `playwright` を優先採用し、無ければ最初に検出した 1 件を採用する〔採用しなかった登録はレポートに列挙する〕）、`${CLAUDE_PLUGIN_ROOT}/references/playwright-mcp.md` 2 章（既存登録の検出・再利用・重複登録禁止・別名時のプレフィクス読み替え）。

## 期待動作

- `claude mcp list` で複数の playwright 系登録を検出する（検出条件は playwright-mcp.md 2 章）
- **AskUserQuestion を発行しない**（非対話モード。エラー中断もしない: slug 解決と異なり優先採用の規約が定義されている）
- 登録名 `playwright` があればそれを優先採用する。無ければ最初に検出した 1 件を採用する（setup-procedures.md 3.1）
- 重複登録・上書き（remove して add し直す等）を行わない（既存を再利用する。playwright-mcp.md 2 章）
- 採用した登録に対して 3.3 の実利用可否判定（ToolSearch）へ進む。ツール名プレフィクスは採用登録名に従う（別名採用時は読み替え）
- 採用しなかった登録を環境検証レポートの引き継ぎ事項に列挙する（黙って捨てない）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（既存登録を再利用するため新規登録・上書きをしない） |
| 標準出力（要約） | 環境検証レポート（Playwright MCP 登録 = registered〔採用登録名 = `playwright` 優先、無ければ先頭〕・ロード = ToolSearch 判定結果）。採用しなかった登録を引き継ぎ事項に列挙 |
| 終了状態 | AskUserQuestion なしで `playwright` 優先（無ければ先頭）採用を確定。重複登録なし |

## 関連ケース

- case-06: 同じ前提の対話版（AskUserQuestion で採用登録を選択する側）
- case-02: 登録 1 件・ロード済み（曖昧さがなく優先採用の規約も不要な側）
