# Case 50: SessionStart hook — 検出フックの前提を欠く → 動作していないことを通知

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | Claude Code セッション開始 |
| 既存状態 例 1 | `jq` が PATH に無い |
| 既存状態 例 2 | `jq` はあるが、`references/scripts/hooks/lib/credential_patterns.sh` が無い（不完全なインストール等） |
| フラグ | なし |

## 期待動作

### Phase 1: 自己診断

- 検出フック（PreToolUse / UserPromptSubmit）が動く前提を確かめる: `jq` がある / `bash` が 4 以上 / 共通のパターン定義がある
- 欠けているものを並べた通知文を作る（例: `jq が見つからない`）

### Phase 2: 出力

- 例 1: `jq` が無い（または `bash` が 4 未満）ため JSON を組み立てられない。通知文を **平文** で標準出力に出し、テンプレートの配置は行わずに `exit 0`
- 例 2: 通常どおりテンプレートの配置を判定し、`additionalContext` の先頭に通知文を添えて出力する（配置しない場合も通知文だけを出す）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | 例 1: `[credentials-manager] 認証情報の検出フック（PreToolUse / UserPromptSubmit）が動作しません（jq が見つからない）。…` の平文 / 例 2: 同じ通知文を含む `hookSpecificOutput.additionalContext` の JSON |
| 終了コード | 0 |
| Claude のコンテキスト | 検出フックが動作していないこと、ユーザに伝えて前提を整えるよう案内すること |

## 分岐の根拠

検出フックは前提を欠くと何もせずに終了する（フェイルオープン）。通知が出ない状態は「検出対象が無い」状態と区別できず、
保護が外れたことに気付けない。SessionStart の標準出力は終了コード 0 ならそのままコンテキストに入るため、
`jq` が無くても平文で知らせられる。前提を満たす通常の環境では、自己診断は何も出力しない（`case-14`〜`16`・`25` の動作は変わらない）。

## 関連ケース

- `case-25_session_start_missing_env_silent_exit.md`（前提は満たし、環境変数が無いケース。何も出力しない）
- `case-42_pretooluse_invalid_input_silent_exit.md`（検出フック側のフェイルオープン）
