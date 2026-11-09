# Case 49: PreToolUse hook — Grep / Glob で通常のファイルを検索 → no-op

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) 例 1 | `{"tool_name":"Glob","tool_input":{"pattern":"plugins/credentials-manager/**/*.md"}}` |
| stdin (Claude → hook) 例 2 | `{"tool_name":"Grep","tool_input":{"pattern":"sk-[A-Za-z0-9]+","path":"/repo/src"}}` |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: ツール種別判定

- `tool_name` → `Glob` / `Grep` の分岐に入る

### Phase 2: 検索対象の判定

- 例 1: `pattern` の末尾は `*.md` で、パスの途中の `credentials-manager` は認証情報系ファイルの規則に該当しない（語の一部の一致では判定しない）
- 例 2: `path` の `/repo/src` は該当しない。`pattern`（検索する正規表現）は判定の対象外
- `REASON` が空のまま `exit 0`

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | 空 |
| 終了コード | 0 |
| Claude のコンテキスト | 追加されない |

## 分岐の根拠

Grep / Glob は呼び出しが多い（過去の記録で Grep 約 2,600 件・Glob 約 650 件）。手掛かりの語の部分一致で判定すると、
`credentials-manager` のようなパスを含む検索のたびに通知されるため、ファイル名の規則で判定する。
過去の記録の Grep / Glob では、この規則で通知の対象になる呼び出しは無かった。

## 関連ケース

- `case-48_pretooluse_grep_glob_credential_trigger.md`（対比：trigger するケース）
- `case-47_pretooluse_shell_credential_file_noop.md`（同じ境界をシェルのコマンドで判定するケース）
