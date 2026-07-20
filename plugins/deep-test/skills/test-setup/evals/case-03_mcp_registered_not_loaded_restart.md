# case-03 MCP 登録済み + 未ロード（再起動案内）

前セッションで登録済みだが、現セッションで MCP ツールがロードされていないケース。再登録・重複登録を行わず、再起動案内（RESTART_REQUIRED）を返すことを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `levels=functional --non-interactive` |
| 起動形態 | 委譲（オーケストレータ `test` から Skill ツール経由・非対話） |
| 前提 | `claude mcp list` に playwright 系の登録あり / 現セッションで `mcp__playwright__*` ツールが未ロード（ToolSearch で 1 件もマッチしない） |

## 分岐の根拠

SKILL.md「実行モード判定」（非対話でも再起動が必要な場合は自動続行せず停止）および「重要な制約」（重複登録・上書き禁止）、references/setup-procedures.md 3.3 章（実利用可否判定で not-loaded）・3.4 章（登録済みだが未ロード → 再登録はしない・ハンドオフ）・6.2 章（RESTART_REQUIRED）、`${CLAUDE_PLUGIN_ROOT}/references/playwright-mcp.md` 4 章（未ロード時はゲート停止 → 再起動ハンドオフ）、`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 9 章（非対話既定値表: MCP ゲートで未ロード → 停止・自動続行しない）。

## 期待動作

- 既存登録を検出し再利用する。`claude mcp add`（再登録・上書き）を実行しない
- ToolSearch の結果 1 件もマッチしないことをもって `not-loaded` と判定する
- 利用可を装って続行しない（「登録済みなので利用可」とする判定は禁止）
- 残りのチェック（venv）は完了させたうえで、総合判定 `RESTART_REQUIRED` のレポートを返却する
- レポートに再起動ハンドオフ（playwright-mcp.md 3 章準拠）を添える。非対話モードでも自動続行せず停止する
- 委譲のため、ハンドオフ文面はオーケストレータへの返却に含め、ユーザーへの提示はオーケストレータに委ねる

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（既存登録を再利用し再登録しない。test-results.yaml へは書き込まない） |
| 標準出力（要約） | 環境検証レポート（登録 = registered / ロード = not-loaded〔ToolSearch 0 件〕+ venv チェック結果）+ 再起動ハンドオフ（オーケストレータへの返却に含める） |
| 終了状態 | 総合判定 RESTART_REQUIRED で停止（非対話でも自動続行しない） |

## 関連ケース

- case-01: 未登録（登録を伴うハンドオフ）
- case-02: 登録済み + ロード済み（READY）
