# Case 05: --non-interactive モード（質問なしで生成）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "新しい `/extension` コマンドを作って" |
| 引数 | `extension --description "拡張要素の作成・公開を支援" --placement plugins/dev-toolkit --non-interactive` |
| フラグ | `--non-interactive` |
| 既存状態 | 同名コマンド未存在 |

## 期待動作

### Phase 1: モード判定

`--non-interactive` 検出 → 非対話モード。
必須情報（コマンド名 / description / 配置先）がフラグで明示されているため、ユーザ確認をスキップ。

### Phase 2: 必須フラグ検証

| 必須フラグ | 提供 |
|-----------|-----|
| コマンド名（位置引数） | あり |
| `--description` | あり |
| `--placement` | あり |

不足があれば対話なしで **エラー終了**（標準エラー出力に提示）。

### Phase 3: 命名衝突チェック

`plugins/dev-toolkit/commands/extension.md` 未存在を確認。衝突時は対話なしでエラー終了（非対話モードでは上書き許可不可）。

### Phase 4: テンプレート展開（自動）

`${CLAUDE_PLUGIN_ROOT}/references/templates/command/command.md` を配置先にコピーし、プレースホルダ置換。`AskUserQuestion` は **一切呼び出さない**。

### Phase 5: 検証 + 引き渡し

| 項目 | 動作 |
|-----|------|
| frontmatter `description` 60 文字以内 | 必須 |
| プレースホルダ残存なし | 必須 |
| パスポータビリティ合格 | 必須 |

不合格項目は標準エラー出力に提示し、対話なしで終了。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `plugins/dev-toolkit/commands/extension.md` |
| 標準出力 | 「`/extension` コマンド生成完了」+ ファイルパス |
| 終了状態 | 成功 |
| ユーザ対話 | 発生しない |

## 分岐の根拠

`--non-interactive` フラグ + 必須フラグ完備 → 自動生成。
必須フラグ不足や命名衝突時はエラー終了（対話のかわりにエラーメッセージ）。

## 関連ケース

- `case-01_new_command_interactive.md`（対話モード・新規作成）
- `case-04_naming_collision.md`（命名衝突時の対話確認）
