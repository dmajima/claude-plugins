# Case 04: 非対話モード

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "hook-toolkit dev-toolkit に PreToolUse Bash ログフックを非対話で追加" |
| 引数 | `--plugin dev-toolkit --event PreToolUse --matcher Bash --command "node \${CLAUDE_PLUGIN_ROOT}/scripts/log_command.js" --timeout 5` |
| フラグ | `--non-interactive` |
| 既存状態 | プラグイン既存、`hooks/hooks.json` 未存在 |

## 期待動作

### Phase 1: モード判定

`--non-interactive` フラグありのため対話せず引数値で確定する。

### Phase 2: テンプレート展開

`templates/hook/hooks.json` をコピー、引数値を反映。

### Phase 3: パスポータビリティチェック

`command` フィールドが `${CLAUDE_PLUGIN_ROOT}` を使用していることを確認。NG パス検出時はエラー終了（非対話モードでもセキュリティ・パスポータビリティはユーザに通知）。

### Phase 4: 検証 + 引き渡し

質問なしで完了報告のみ。動作確認手順は提示する。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `plugins/dev-toolkit/hooks/hooks.json` |
| 標準出力 | 完了報告 + 動作確認手順（質問なし） |
| 終了状態 | 成功 |

## 分岐の根拠

`--non-interactive` フラグ + 全パラメータ引数指定 である。

## 関連ケース

- `case-01_plugin_hook.md`（対話モード）
