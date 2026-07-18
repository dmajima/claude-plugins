# case-02 MCP 登録済み + ロード済み（READY 返却）

Playwright MCP が登録済みかつ現セッションでロード済みの環境。既存登録を再利用し、実利用可否を ToolSearch で確認して READY を返却することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `levels=functional,system session=.claude/.local/work/20260717_01_webapp_test` |
| 起動形態 | 委譲（オーケストレータ `test` から Skill ツール経由） |
| 前提 | `claude mcp list` に登録名 `playwright` のサーバーが存在 / 現セッションで `mcp__playwright__*` ツールがロード済み / venv は構築済み |

## 分岐の根拠

SKILL.md「実行フロー」手順 2（登録済みなら ToolSearch で実利用可否を判定）および「重要な制約」（重複登録・上書き禁止 / `claude mcp list` の登録有無だけで判定しない）、references/setup-procedures.md 2 章（`levels=` からのチェック対象導出）・3.1 章（既存登録の検出と再利用）・3.3 章（実利用可否判定）・6.2 章（READY の判定条件）、`${CLAUDE_PLUGIN_ROOT}/references/playwright-mcp.md` 2 章（既存登録の再利用）・4 章（ToolSearch による実判定）。

## 期待動作

- `claude mcp list` で既存登録を検出し、**再利用**する（`claude mcp add` / remove を実行しない）
- ToolSearch で `mcp__playwright__` 系ツールを検索し（例: `select:mcp__playwright__browser_snapshot`）、スキーマ取得成功をもって `loaded` と判定する
- 登録の有無だけで「利用可」と判定していない（ToolSearch の実結果を判定根拠としてレポートに記録する）
- `levels=functional,system` に unit を含まないため、テストランナーチェックは対象外（レポートで `not-checked` として行を残す）
- venv は既存を確認し `ready` とする（再構築しない）
- 環境検証レポートを返却する: 総合判定 `READY`、登録 = `registered`、ロード = `loaded`、ランナー = `not-checked`、venv = `ready`
- 引き継ぎ事項に MCP ゲート（execution-policy.md 1.4 章）の判定材料としてロード済みである旨を含める
- 再起動ハンドオフは出力しない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（既存登録を再利用・venv は既存確認のみ。test-results.yaml へは書き込まない） |
| 標準出力（要約） | 環境検証レポート（登録 = registered / ロード = loaded〔ToolSearch 実判定〕/ ランナー = not-checked / venv = ready）+ MCP ゲート判定材料の引き継ぎ事項 |
| 終了状態 | 総合判定 READY（再起動ハンドオフなし） |

## 関連ケース

- case-01: 未登録（新規登録 + ハンドオフ）
- case-03: 登録済みだが未ロード（再起動案内）
- case-05: unit のみで MCP チェック自体が対象外
