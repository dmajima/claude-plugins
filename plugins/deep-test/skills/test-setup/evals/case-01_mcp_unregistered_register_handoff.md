# case-01 MCP 未登録（新規登録 + 再起動ハンドオフ）

Playwright MCP が未登録の環境で test-setup を起動したケース。規約コマンドで登録し、同一セッションでの利用を試みずに再起動ハンドオフを出力して停止することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | 「テストツールチェーンを準備して。Playwright MCP も使えるようにして」 |
| 起動形態 | 単独（ユーザー直接起動） |
| 前提 | `claude mcp list` に playwright 系サーバーの登録が 1 件もない / テストランナー（pytest）が検出可能 / venv 未構築 |

## 分岐の根拠

SKILL.md「実行フロー」手順 2・6 および「重要な制約」（新規登録した場合、同一セッションで MCP ツールの利用を試みず、必ず再起動ハンドオフを出力して停止する）、references/setup-procedures.md 3.2 章（新規登録）・3.4 章（再起動ハンドオフ）・6.2 章（RESTART_REQUIRED の判定条件）、`${CLAUDE_PLUGIN_ROOT}/references/playwright-mcp.md` 1 章（規約コマンド）・3 章（ハンドオフの 3 要素とメッセージ例）。

## 期待動作

- `claude mcp list` を実行して既存登録なしを確認してから登録する（検出を省略して登録しない）
- playwright-mcp.md 1 章の規約コマンドを**そのまま**実行する（`-s local` / `--headless` / `--output-dir '.claude/.local/plugins/deep-test/playwright'` / `--ignore-https-errors` を欠落・改変しない）
- 登録後、ToolSearch による利用や MCP ツールの呼び出しを試みない（登録直後のセッションでは未ロードのため）
- 残りのチェック（テストランナー検出・venv 確認/構築）は継続して完了させる（setup-procedures.md 1 章）
- 環境検証レポートを返却する: 総合判定 `RESTART_REQUIRED`、Playwright MCP 登録 = `newly-registered`、ロード = `not-loaded`、ランナー = `detected`（pytest・根拠ファイル併記）、venv = `created`
- レポートに続けて再起動ハンドオフ（状態保存の確認・再起動依頼・再開手順の 3 要素。playwright-mcp.md 3 章のメッセージ例に準拠）を出力して停止する
- run 未開始のため、再開手順は「再起動後に元のコマンドを再実行」で案内する

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | Playwright MCP を規約コマンドで新規登録・venv 構築（created）。test-results.yaml へは書き込まない |
| 標準出力（要約） | 環境検証レポート（MCP 登録 = newly-registered / ロード = not-loaded / ランナー = detected / venv = created）+ 再起動ハンドオフ |
| 終了状態 | 総合判定 RESTART_REQUIRED で停止（再起動後に元コマンド再実行を案内） |

## 関連ケース

- case-02: 登録済み + ロード済み（READY で続行）
- case-03: 登録済み + 未ロード（登録は行わず再起動案内のみ）
