# Case 51: SessionStart hook — jq はあるが検出フックの前提を欠く → 配置の通知に添えて JSON で通知

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | Claude Code セッション開始 |
| 既存状態 例 1 | `references/scripts/hooks/lib/credential_patterns.sh` と `credential_files.sh` が無い（不完全なインストール等） |
| 既存状態 例 2 | `bash` が 4 未満（macOS の既定の bash 3.2 等） |
| フラグ | なし |

## 期待動作

### Phase 1: 自己診断

- 欠けているものと、問題ごとの対処を並べた通知文を作る（同じ対処は 1 回だけ）
- 例 1: `lib/credential_patterns.sh が無い、lib/credential_files.sh が無い` / 対処 `プラグインを更新するか入れ直す`
- 例 2: `bash 3.2.57 では動かない（4 以上が必要）` / 対処 `bash 4 以上を使う（macOS は Homebrew の bash 等）`

### Phase 2: ルールの配置

- 通常どおりスコープを判定してルールのテンプレートを配置する（既に配置済みなら配置しない）。
  このフックは `bash` 3.2 でも動く書き方に限っているため、例 2 でも配置できる

### Phase 3: 出力

- `jq` があるため、`additionalContext` の先頭に自己診断の通知文を添えて JSON で出力する（配置しない場合も通知文だけを出す）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | `hookSpecificOutput.additionalContext` に `[credentials-manager] 認証情報の検出フック（PreToolUse / UserPromptSubmit）が動作しません（…）。…対処（…）を案内してください。` と配置の通知を含む JSON |
| 終了コード | 0 |
| Claude のコンテキスト | 検出フックが動作していないこと、ユーザに伝えて対処を案内すること |

## 分岐の根拠

問題によって対処が異なる（`lib` の欠けは `jq` や `bash` を整えても直らない）ため、問題ごとの対処を案内する。
前提を満たす通常の環境では、自己診断は何も出力しない（`case-14`〜`16`・`25` の動作は変わらない）。

## 関連ケース

- `case-50_session_start_self_diagnosis_notify.md`（`jq` が無いケース。平文で通知）
- `case-25_session_start_missing_env_silent_exit.md`（前提は満たし、環境変数が無いケース。何も出力しない）
