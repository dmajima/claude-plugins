# Case 31: PreToolUse hook — Read README.md → no-op

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) | `{"tool_name":"Read","tool_input":{"file_path":"C:/repo/README.md"}}` |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: ツール種別判定

- `tool_name` → `Read`、`tool_input.file_path` 抽出

### Phase 2: ファイルパス判定

- ファイル名 `readme.md` は `.env` 系・認証情報ストア・秘密鍵・クラウド認証のいずれにも該当しない
- 拡張子 `.md` は秘密鍵 / 証明書の拡張子リストに含まれない
- `Read` はコンテンツを持たないため、シークレットパターンの照合は行わない
- `REASON` が空のまま `exit 0`

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | 空 |
| 終了コード | 0 |
| Claude のコンテキスト | 追加されない |

## 分岐の根拠

`Read` 側の過検出抑制の境界ケース。`Read` は最も頻繁に呼ばれるツールの 1 つであり、
無関係なファイルで通知が出ると、読み取りのたびに context を消費する。

## 関連ケース

- `case-21_pretooluse_read_env_trigger.md`（対比：trigger するケース）
- `case-22_pretooluse_read_env_example_noop.md`（同じ no-op カテゴリで除外リスト側）
- `case-20_pretooluse_bash_local_noop.md`（同じ no-op カテゴリで Bash 側）
