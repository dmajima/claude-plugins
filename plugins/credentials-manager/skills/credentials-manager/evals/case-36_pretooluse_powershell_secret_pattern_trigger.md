# Case 36: PreToolUse hook — PowerShell + コマンド中の秘密情報パターン → trigger

## 入力

| 項目 | 値 |
|-----|---|
| トリガー | PreToolUse hook |
| stdin (Claude → hook) | `{"tool_name":"PowerShell","tool_input":{"command":"Write-Output \"sk-<英数字 16 文字以上のダミー>\""}}`（コマンドに `sk-` で始まる値を直接書いた状態を想定） |
| 既存状態 | 任意 |

## 期待動作

### Phase 1: ツール種別判定

- `tool_name` → `PowerShell`、`tool_input.command` 抽出

### Phase 2: コマンド解析

- コマンドがシークレットパターン（`sk-` に英数字等が 16 文字以上続く）に一致する
- `REASON` = `PowerShell コマンドに認証情報パターンを検出`
- `Authorization = "Bearer <16 文字以上>"` のような Bearer トークンは `PowerShell コマンドに Bearer トークンを検出` になる

### Phase 3: Claude へ通知

- `additionalContext` で credentials-reader の最優先起動と、フル値を復唱せずマスクして扱うことを指示する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| Hook stdout | `hookSpecificOutput.additionalContext` に `PowerShell コマンドに認証情報パターンを検出` とマスキング指示を含む JSON |
| 終了コード | 0 |

## 分岐の根拠

フックは実行を止めないため、通知が届く時点で値は既にトランスクリプトに記録されている。
それでも、以後の扱い（照合スキルの起動・値のマスク）を念押しするために検出する。
回帰テストでは、`sk-` に `x` を 24 文字続けたダミー値を実行時に組み立てて検証する
（ファイルに直書きすると、編集するセッションのフック自体が反応するため）。

## 関連ケース

- `case-23_pretooluse_write_secret_trigger.md`（同じパターンで Write のコンテンツ側）
- `case-17_prompt_secret_pattern_trigger.md`（同じパターンでユーザ入力側）
