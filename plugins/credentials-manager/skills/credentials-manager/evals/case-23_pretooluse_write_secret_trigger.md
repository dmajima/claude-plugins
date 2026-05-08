# Case 23: PreToolUse hook — Write コンテンツにシークレットパターン → trigger

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) | `{"tool_name":"Write","tool_input":{"file_path":"/tmp/notes.txt","content":"github_token=ghp_abcdefghijklmnop1234567890"}}` |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: ツール種別判定

- `tool_name` → `Write`
- `file_path` 抽出 → `/tmp/notes.txt`

### Phase 2: ファイルパス判定

- `detect_credential_file` で basename `notes.txt` は認証情報系ファイル該当なし
- `REASON` 未設定のまま次の判定へ

### Phase 3: コンテンツ判定

- `tool_name != Read` のため、INPUT_FLAT 全体を `SECRET_PATTERN` で grep
- `ghp_<20+ 文字>` にマッチ
- `set_reason "Write のコンテンツに認証情報パターンを検出"` に到達

### Phase 4: Claude へ通知

- `additionalContext` で **`credentials-reader`** 最優先起動を要求 + マスキング処理（先頭4+****+末尾4、8文字以下は全マスク****） + 既存照合 → 保存提案 → ユーザ承諾時のみ `credentials-manager` 引き継ぎ を要求

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | 有効な JSON（コンテンツ内シークレット検出 reason 含む） |
| 終了コード | 0 |

## 分岐の根拠

ファイルパス判定では引っかからない / コンテンツ判定で引っかかる二段検出の根拠。`Write` / `Edit` / `MultiEdit` / `NotebookEdit` で同様。`Read` ではコンテンツ検出はしない（既存ファイルの内容を hook 側で覗かないため）。

## 関連ケース

- `case-21_pretooluse_read_env_trigger.md`（ファイルパス側で trigger）
- `case-17_prompt_secret_pattern_trigger.md`（同パターンを UserPromptSubmit 側で検出）
