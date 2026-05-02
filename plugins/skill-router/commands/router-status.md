---
description: skill-router の統計・直近決定・スコア分布表示（--clean で 30 日超セッション削除）
argument-hint: "[--clean]"
---

ユーザの引数: $ARGUMENTS

`skill-router` プラグインの状態を確認します。`--clean` オプションが指定された場合は 30 日以上前のセッションディレクトリを削除します（設計書 v2 セクション 7）。

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

```bash
# 30 日 = 2592000 秒
python -c "import os,time,shutil,sys; from pathlib import Path; \
base=Path(sys.argv[1]); root=base/'sessions'; \
[shutil.rmtree(p, ignore_errors=True) for p in root.glob('*') if p.is_dir() and (time.time() - p.stat().st_mtime) > 2592000]" \
  "<base>"
```

実行後、削除したセッションディレクトリ数を提示する。

## 失敗時

- `<base>` が存在しない場合は「まず `/router-rebuild` を実行してください」と案内する。
- ファイル読取失敗時は当該ファイルをスキップしてログに記載、得られた範囲で提示する。
- `--clean` で削除に失敗した場合はファイル名を提示し、ユーザに手動削除を促す。

## 実行手順

1. base ディレクトリを Bash で解決:
   ```bash
   HOME_DIR="${HOME:-${USERPROFILE:-}}"
   if [[ -n "${CLAUDE_PLUGIN_DATA:-}" && -d "${CLAUDE_PLUGIN_DATA}" ]]; then BASE="${CLAUDE_PLUGIN_DATA}"; \
   elif [[ -d "${PWD}/.claude/.local/plugins/skill-router" ]]; then BASE="${PWD}/.claude/.local/plugins/skill-router"; \
   else BASE="${HOME_DIR}/.claude/.local/plugins/skill-router"; fi; echo "$BASE"
   ```
2. 上記 `$BASE` を使って `index.json` / `inverted_index.json` を Read。
3. `$BASE/sessions/` を Glob で列挙し、最新 10 件の `route_decisions.jsonl` を tail。
4. レポートを整形して提示。
5. `--clean` 指定時は事前に削除を実行。
