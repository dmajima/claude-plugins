# Case 22: PreToolUse hook — Read .env.example → no-op

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) | `{"tool_name":"Read","tool_input":{"file_path":"/repo/.env.example"}}` |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: ツール種別判定

- `tool_name` → `Read`、`file_path` 抽出

### Phase 2: ファイルパス判定（除外）

- `detect_credential_file` が basename `.env.example` を検出
- `.env.<name>` 分岐に入るが、case 文で `.env.example` は除外リストに含まれる
  - 除外: `.env.example` / `.env.sample` / `.env.template` / `.env.dist` / `.env.test` / `.env.spec`
- `REASON` が空のまま `exit 0`

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | 空 |
| 終了コード | 0 |
| Claude のコンテキスト | 追加されない |

## 分岐の根拠

過検出抑制の境界ケース。サンプル / テンプレートファイル（実シークレット非含有）に通知が走らないことの根拠。

## 関連ケース

- `case-21_pretooluse_read_env_trigger.md`（trigger する境界）
