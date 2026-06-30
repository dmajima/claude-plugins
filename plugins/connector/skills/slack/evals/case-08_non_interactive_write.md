# Case 08: 非対話モードでの書き込み（AskUserQuestion 省略）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | `Skill(skill: "connector:slack", args: "チャンネル #general にメッセージ送信。内容: 本日の定例は15時に変更します。--non-interactive")` |
| 引数 | チャンネル名 + メッセージ内容 + `--non-interactive` |
| フラグ | `--non-interactive` |
| 既存状態 | MCP ツール `mcp__claude_ai_Slack__*` 利用可能。呼び出し元は別スキルから操作種別・対象・内容がすべて確定済み |

## 期待動作

1. 非対話モードと判別（`--non-interactive` フラグ）
2. チャンネル名 → channel_id を `slack_search_channels` で解決
3. **AskUserQuestion による送信承認を省略**（非対話モード）
4. `slack_send_message` でメッセージ送信

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし |
| 標準出力（要約） | メッセージ送信完了（チャンネル名・メッセージリンク） |
| 終了状態 | 成功 |

## 分岐の根拠

非対話モードでの書き込み。対話モード（case-03 等）では AskUserQuestion で承認を得るが、非対話モードではエージェント判断で省略する。SKILL.md「書き込み承認 > 非対話モード」セクションに基づく。

## 関連ケース

- `case-03_send_message.md`（対話モードでの送信。AskUserQuestion 承認あり）
