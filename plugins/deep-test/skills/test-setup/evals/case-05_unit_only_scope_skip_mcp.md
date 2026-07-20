# case-05 unit のみのスコープ（MCP チェック省略）

予定テストレベルが unit のみの場合に、Playwright MCP チェックを対象外として省略し、ランナー・venv のみをチェックすることを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `levels=unit --non-interactive` |
| 起動形態 | 委譲（オーケストレータ `test` から Skill ツール経由・非対話） |
| 前提 | Playwright MCP は未登録 / jest が `package.json` から検出可能 / venv 未構築で setup スクリプトあり |

## 分岐の根拠

SKILL.md「前提」の引数表（`levels=` は MCP チェック要否の導出材料）、references/setup-procedures.md 2 章（`levels=unit` → playwright チェック対象外・runner は unit を含むため対象・venv は常に対象）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 1.4 章（レベル別の MCP 要否: unit は不要）。

## 期待動作

- `levels=unit` から、playwright = 対象外 / runner = 対象 / venv = 対象を導出する
- Playwright MCP が未登録であっても**登録を行わない**（チェック対象外のため。不要な再起動ハンドオフを発生させない）
- `claude mcp list` の実行や ToolSearch 判定を省略してよいが、レポートの Playwright MCP 登録・ロードの行は `not-checked` として残す（行を省略しない）
- jest を検出し `detected`（根拠ファイル・実行コマンド例併記）、venv を構築し `created` とする
- 総合判定 `READY` のレポートを返却する（`not-checked` は対象外であり READY 判定を妨げない。setup-procedures.md 6.2 章）
- 再起動ハンドオフを出力しない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | venv 構築（workspace/.venv・created）。Playwright MCP は未登録でも登録しない。test-results.yaml へは書き込まない |
| 標準出力（要約） | 環境検証レポート（MCP 登録・ロード = not-checked / ランナー = detected〔jest・根拠ファイル併記〕/ venv = created） |
| 終了状態 | 総合判定 READY（not-checked は判定を妨げず、再起動ハンドオフなし） |

## 関連ケース

- case-01: 全チェック時の未登録分岐（登録 + ハンドオフ）
- case-04: ランナー検出の返却形式
