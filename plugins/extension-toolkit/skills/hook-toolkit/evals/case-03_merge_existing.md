# Case 03: 既存フックへの追加（マージ）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "Bash ログフックに加えて Edit ログも追加" |
| 引数 | `--plugin dev-toolkit --event PreToolUse --matcher Edit --command "node \${CLAUDE_PLUGIN_ROOT}/scripts/log_edit.js"` |
| フラグ | なし |
| 既存状態 | `plugins/dev-toolkit/hooks/hooks.json` に `PreToolUse:Bash` フックあり |

## 期待動作

### Phase 1: 既存ファイル読込

既存 `hooks.json` を Read。

### Phase 2: 衝突確認

同じ matcher（`Edit`）のエントリが既存していないか確認。重複時はユーザに以下を提示:

```text
同じ matcher（Edit）のフックが既に存在します。

選択肢:
1. 既存を上書き（既存内容を新エントリに置換）
2. 追加（既存と新エントリの両方を保持、複数フックの並行実行）
3. 既存を編集（既存エントリを修正してマージ）
4. キャンセル

どうしますか？
```

| 選択 | 動作 |
|-----|------|
| 1 | 既存エントリを削除、新エントリを追加 |
| 2 | 配列に新エントリを追加（既存維持） |
| 3 | 既存エントリの修正パッチを適用 |
| 4 | 何もせず終了 |

### Phase 3: マージ

既存の `PreToolUse` 配列に新エントリを追加。既存の `Bash` matcher エントリを破壊しない。

### Phase 4: 検証 + 引き渡し

通常検証 + 既存エントリの保全確認。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 変更ファイル | `plugins/dev-toolkit/hooks/hooks.json`（マージ） |
| 標準出力 | 「Edit ログフックを追加（Bash ログフックは維持）」 |
| 終了状態 | 成功 |

## 分岐の根拠

既存 hooks.json 存在 + 同イベント追加 である。
