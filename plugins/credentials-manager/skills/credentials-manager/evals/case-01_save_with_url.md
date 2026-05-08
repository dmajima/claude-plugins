# Case 01: URL 関連付き API キー保存（対話モード）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "https://api.example.com/v1/data にアクセスして。APIキーは abc-secret-1234567890 を使って。" |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | リポジトリ内、`.claude/.local/` は `.gitignore` 登録済み、`credentials.json` 未存在 |

## 期待動作

### Phase 1: パス解決

- 現在ディレクトリの祖先に `.git` を発見し、`<repo_root>/.claude/.local/plugins/credentials-manager/credentials.json` を解決パスとする
- 親ディレクトリが無ければ作成
- ファイル不在のため空ストア `{"credentials": {}}` で初期化

### Phase 2: 識別名・種別の確定

- 識別名が明示されていないため `AskUserQuestion` で「保存名は何にしますか?」を確認
- ユーザが「example-api-key」と回答したと仮定
- 種別は `api_key` と推定

### Phase 3: URL/ドメイン抽出

- `urls`: `["https://api.example.com/v1/*"]`
- `domains`: `["api.example.com"]`
- `auth_method`: `header:Authorization:Bearer`（既定）

### Phase 4: 保存・確認

- エントリを書き込み
- マスク済み値で確認: `abc-****7890`

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `<repo_root>/.claude/.local/plugins/credentials-manager/credentials.json` |
| 標準出力（要約） | "Saved credential 'example-api-key' (api_key): abc-****7890 — domains: api.example.com (project-scoped)" |
| 終了状態 | 成功 |

## 分岐の根拠

このケースは「保存（save）+ URL 提供あり + 対話モード」分岐に該当する。識別名がユーザ入力に含まれないため `AskUserQuestion` を発火する。

## 関連ケース

- `case-08_non_interactive.md`（非対話モードでの保存差分）
- `credentials-reader:case-01_auto_match_single.md`（保存後の自動マッチ、reader 側）
