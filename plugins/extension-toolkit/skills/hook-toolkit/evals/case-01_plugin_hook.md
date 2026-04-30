# Case 01: プラグイン同梱フック新規作成

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`dev-toolkit` プラグインに Bash ログ用 PreToolUse フックを追加" |
| 引数 | `--plugin dev-toolkit --event PreToolUse --matcher Bash --command "node \${CLAUDE_PLUGIN_ROOT}/scripts/log_command.js" --timeout 5` |
| フラグ | なし |
| 既存状態 | `dev-toolkit` プラグイン既存、`hooks/` ディレクトリは未存在 |

## 期待動作

### Phase 1: 配置先決定

`plugins/dev-toolkit/hooks/hooks.json` を配置先として確定。

### Phase 2: テンプレート展開

`${CLAUDE_PLUGIN_ROOT}/references/templates/hook/hooks.json` をコピー、引数値を反映。

### Phase 3: パスポータビリティチェック

`command` フィールドが `${CLAUDE_PLUGIN_ROOT}` を使っていることを確認。ローカル絶対パスがあれば修正提案。

### Phase 4: 検証 + 引き渡し

JSON valid、timeout 指定あり、matcher 正規表現 valid。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `plugins/dev-toolkit/hooks/hooks.json` |
| 標準出力 | 「PreToolUse フックを `dev-toolkit` プラグインに追加」+ 動作確認手順 |
| 終了状態 | 成功 |

## 分岐の根拠

`--plugin` 引数（プラグイン同梱配置） である。
