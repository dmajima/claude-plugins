---
description: skill-router の統計・直近決定・スコア分布を確認（チューニング時 / 異常診断時）
argument-hint: "[--clean]"
---

ユーザの引数: $ARGUMENTS

`skill-router` プラグインの状態を確認します。`--clean` オプションが指定された場合は 30 日以上前のセッションディレクトリを削除します（`commands/router-status.md` 本ファイルの動作モード表参照）。

## 動作モード

| 引数 | モード | 動作 |
|-----|-------|------|
| 空 | 標準 | 統計・直近決定・スコア分布を表示 |
| `--clean` | クリーンアップ | 30 日超のセッション削除後に標準表示 |

## 取得する情報

1. **base ディレクトリ解決**: `${CLAUDE_PLUGIN_DATA}` → `<repo>/.claude/.local/plugins/skill-router/` → `${HOME}/.claude/.local/plugins/skill-router/` の順で最初に存在するパスを採用。
2. **`<base>/index.json`** の `generated_at` / `stats` フィールドを Read で取得。
3. **`<base>/inverted_index.json`** の `stats` フィールドを Read で取得。
4. **`<base>/sessions/*/route_decisions.jsonl`** の最終行を最新から最大 10 件取得し、tier ごとに集計。
5. **disabled フラグ存在判定**: `<base>/disabled` の有無で「現在 ON / OFF」を表示。

## 提示するレポート

```text
[skill-router status]
- generated_at         : <iso8601>
- enabled / installed  : <X> / <Y>
- skills indexed       : <N>  (with evals: <M>)
- inverted keywords    : <K>  (overgeneric skipped: <S>)
- routing toggle       : ON | OFF (disabled flag: <path>)
- recent decisions     : high=<a>  mid=<b>  low=<c>  (last 10)
- score histogram      : (top1 値の 0.5 刻みヒストグラム ASCII bar 表示)
```

## --clean 指定時の追加動作

セッション削除は `references/scripts/commands/clean_old_sessions.py` に切り出しています（ADR-025 / scripts-policy 準拠）。

```bash
python "${CLAUDE_PLUGIN_ROOT}/references/scripts/commands/clean_old_sessions.py" "$BASE"
```

実行後、削除したセッションディレクトリ数を提示する（標準出力 1 行）。

## 失敗時

- `<base>` が存在しない場合は「まず `/router-rebuild` を実行してください」と案内する。
- ファイル読取失敗時は当該ファイルをスキップしてログに記載、得られた範囲で提示する。
- `--clean` で削除に失敗した場合はファイル名を提示し、ユーザに手動削除を促す。

## 実行手順

1. base ディレクトリを共通ヘルパーで解決（ADR-025 準拠、`references/scripts/commands/resolve_base.sh`）:
   ```bash
   BASE="$(bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/commands/resolve_base.sh")"
   ```
2. 上記 `$BASE` を使って `index.json` / `inverted_index.json` を Read。
3. `$BASE/sessions/` を Glob で列挙し、最新 10 件の `route_decisions.jsonl` を tail。
4. レポートを整形して提示。
5. `--clean` 指定時は事前に `clean_old_sessions.py` を実行。
