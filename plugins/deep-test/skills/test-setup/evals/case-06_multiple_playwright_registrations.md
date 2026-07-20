# case-06 playwright 系登録が複数 × 対話（AskUserQuestion で選択）

対話モードで `claude mcp list` に playwright 系の登録が複数見つかる曖昧なケース。AskUserQuestion で採用する登録をユーザーに選択させることを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | 「テストツールチェーンを準備して」 |
| 起動形態 | 単独（ユーザー直接起動・対話） |
| 前提 | `claude mcp list` に playwright 系サーバーが複数登録されている（例: 登録名 `playwright` と、別名で Playwright MCP を起動する登録の 2 件） |

## 分岐の根拠

`${CLAUDE_SKILL_DIR}/references/setup-procedures.md` 3.1（既存登録の検出・複数件の対応: 対話時は AskUserQuestion で採用する登録を確認する）、SKILL.md「実行モード判定」（対話は曖昧な状況〔playwright 系登録が複数見つかる等〕のみ AskUserQuestion で確認）、`${CLAUDE_PLUGIN_ROOT}/references/playwright-mcp.md` 2 章（既存登録の検出・再利用・重複登録禁止）。

## 期待動作

- `claude mcp list` で複数の playwright 系登録を検出する（検出条件は playwright-mcp.md 2 章）
- 重複登録・上書き（remove して add し直す等）を行わない（既存を再利用する。playwright-mcp.md 2 章）
- AskUserQuestion で採用する登録をユーザーに選択させる（検出した登録を選択肢として提示する。曖昧な状況のみ確認し、登録が 1 件なら発行しない。SKILL.md 実行モード判定）
- 勝手にどちらかを採用して先へ進まない（採用の確定はユーザー選択による）
- 採用した登録に対して 3.3 の実利用可否判定（ToolSearch）へ進む。ツール名プレフィクスは採用登録名に従う（別名時は読み替え。playwright-mcp.md 2 章）
- 採用しなかった登録を環境検証レポートの引き継ぎ事項に明記する

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（既存登録を再利用するため新規登録・上書きをしない） |
| 標準出力（要約） | 環境検証レポート（Playwright MCP 登録 = registered〔ユーザー選択の採用登録名〕・ロード = ToolSearch 判定結果）。採用しなかった登録を引き継ぎ事項に列挙 |
| 終了状態 | ユーザー選択で採用登録を確定（重複登録なし） |

## 関連ケース

- case-09: 同じ前提の非対話版（`playwright` 優先・無ければ先頭を自動採用する側）
- case-02: 登録 1 件・ロード済み（曖昧さがなく AskUserQuestion 不要）
- case-03: 登録済み + 未ロード（採用後の実利用可否判定で未ロードとなる分岐）
- case-07: venv 失敗との混在で PARTIAL となる総合判定
