# Case 08: 認証情報の自動除外

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "Git から同期して" |
| 引数 | `--repo https://github.com/myaccount/claude-settings` |
| フラグ | なし |
| 既存状態 | リモート repo に **誤って** `credentials.json` / `.env.production` がコミットされている |

## 期待動作

### Phase 4: 差分検出 + 除外フィルタ
- リモート側を走査する際、以下に該当するパスは差分一覧から除外
  - `credentials.json`
  - `.env` および `.env.*`
  - `*.pem` / `*.key` / `*.pfx` 等
  - `.git/` 配下
  - `plugins/cache/` 配下
- 除外されたパスは Verbose ログに記録（標準出力には警告メッセージとして表示）

### Phase 5 以降: 通常フロー
- 除外されたファイルは適用されない（バックアップ・上書きの対象外）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | 通常の同期成果物。`credentials.json` / `.env.*` は変更されない |
| 標準出力（要約） | 「除外対象のためスキップ: credentials.json」等の警告 |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは リモート側のパスが除外リスト（`EXCLUDE_TARGETS` / `EXCLUDE_PATTERNS`）に一致 することである。

## セキュリティ的根拠

- `credentials-manager` プラグインで管理される認証情報を保護する
- リモート repo にうっかり認証情報がコミットされた場合の事故防止
- ユーザが `--targets credentials.json` を明示指定してもスクリプトは拒否（引数バリデーション）

## 関連ケース

- `case-02_interactive_overwrite.md`（通常の同期フロー）
