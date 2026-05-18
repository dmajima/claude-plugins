# Case 05: 危険な command 入力時の警告と修正提案

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "PreToolUse フックで Bash 実行をログ" |
| 引数 | `--event PreToolUse --matcher Bash --command "C:\Users\me\scripts\log.bat" --timeout 5` |
| フラグ | なし |
| 既存状態 | フック未存在 |

## 期待動作

### Phase 1: 入力解析

`--command` の値が以下のいずれかに該当するかを検査:

| パターン | リスク |
|---------|------|
| ローカル絶対パス（`C:\...` / `/home/...` / `/Users/...`） | パスポータビリティ NG |
| `$(...)` / `` `...` ``（コマンド置換）| コマンドインジェクションリスク |
| `eval ...` / `bash -c ...` | 動的コード実行リスク |
| クォート無しの文字列補間 | インジェクションリスク |

本入力では `C:\Users\me\scripts\log.bat` がローカル絶対パスに該当 → 警告対象。

### Phase 2: 警告 + 修正提案

```text
入力された command にパスポータビリティ違反を検出しました:

入力: C:\Users\me\scripts\log.bat

問題:
- ローカル絶対パスのハードコード（[references/path-portability.md] 違反）
- 利用者環境では存在しないパスのため、フックが動作しない

修正案:
1. ${CLAUDE_PLUGIN_ROOT}/references/scripts/hooks/log-tool-use.ps1 に変更（プラグイン同梱スクリプトとして配備、PowerShell 統一）
2. ${HOME}/.claude/scripts/log-tool-use.ps1 に変更（利用者ホーム配下、ただし存在は前提）
3. このまま続行（ユーザ責任、推奨しない）
4. キャンセル
```

`AskUserQuestion` で選択させる。

### Phase 3: 選択分岐

| 選択 | 動作 |
|-----|------|
| 1 | `${CLAUDE_PLUGIN_ROOT}/references/scripts/hooks/log-tool-use.ps1` に書き換え、同パスのスケルトン作成も提案（ADR-025 配置義務準拠） |
| 2 | `${HOME}/.claude/scripts/log-tool-use.ps1` に書き換え、利用者環境への配置案内 |
| 3 | 二重確認 + ハードコード継続を記録 |
| 4 | 何もせず終了 |

### Phase 4: hooks.json 生成 + 検証

選択 1 / 2 の場合、修正された command で `hooks.json` を生成。
パスポータビリティチェック合格を確認。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | 選択により異なる（選択 1 の場合: `hooks.json` + `references/scripts/hooks/log-tool-use.ps1` スケルトン、ADR-025 配置義務準拠） |
| 標準出力 | パスポータビリティ警告 + 修正提案 + 選択結果 |
| 終了状態 | 成功（選択 1/2） / 警告継続（選択 3） / キャンセル（選択 4） |

## 分岐の根拠

`--command` 入力に危険パターン検出 → fail-safe 警告フロー。
利用者が誤ってローカル絶対パスを含むフックを作成することを防ぐ。

## 関連ケース

- `case-01_plugin_hook.md`（プラグイン同梱フック、正常入力）
- `case-04_non_interactive.md`（非対話モード、危険入力検出時はエラー終了）
