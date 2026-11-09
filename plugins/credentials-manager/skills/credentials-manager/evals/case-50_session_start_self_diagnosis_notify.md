# Case 50: SessionStart hook — jq が無い → ルールを配置し、検出フックが動作しないことを平文で通知

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | Claude Code セッション開始 |
| 既存状態 | `jq` が PATH に無い（`mkdir` / `cp` は使える）。ルールファイルは未配置 |
| フラグ | なし |

## 期待動作

### Phase 1: 自己診断

- 検出フック（PreToolUse / UserPromptSubmit）が動く前提を確かめる: `jq` がある / `bash` が 4 以上 / `references/scripts/hooks/lib/` の共通定義がある
- 欠けているもの（`jq が見つからない`）と、その対処（`jq をインストールする`）を並べた通知文を作る

### Phase 2: ルールの配置

- 前提を欠いていても、通常どおりスコープを判定してルールのテンプレートを配置する（検出フックの念押しが無い分、ルールで補う）

### Phase 3: 出力

- `jq` が無いため JSON を組み立てられない。自己診断の通知文と配置の通知を **平文** で標準出力に出して `exit 0`

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | `[credentials-manager] 認証情報の検出フック（PreToolUse / UserPromptSubmit）が動作しません（jq が見つからない）。…対処（jq をインストールする）を案内してください。 [credentials-manager] project 向けにルール … を配置しました。…` の平文 |
| 配置 | `.claude/rules/security/credentials-management.md`（テンプレートと同じ内容） |
| 終了コード | 0 |
| Claude のコンテキスト | 検出フックが動作していないこと、ユーザに伝えて `jq` のインストールを案内すること、ルールを配置したこと |

## 分岐の根拠

検出フックは前提を欠くと何もせずに終了する（フェイルオープン）。通知が出ない状態は「検出対象が無い」状態と区別できず、
保護が外れたことに気付けない。SessionStart の標準出力は終了コード 0 ならそのままコンテキストに入るため、
`jq` が無くても平文で知らせられる。ルールは検出フックが動かない環境でこそ必要なため、配置は省略しない。

## 関連ケース

- `case-51_session_start_self_diagnosis_with_jq.md`（`jq` はあるが他の前提を欠くケース。JSON で通知）
- `case-52_session_start_install_failed_notify.md`（ルールを配置できないケース）
- `case-42_pretooluse_invalid_input_silent_exit.md`（検出フック側のフェイルオープン）
