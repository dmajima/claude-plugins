---
description: skill-router の index を手動再構築（新規スキル追加後や推奨が出ないとき）
---

`skill-router` プラグインのインデックスを再構築します。`build_index.py` を起動し、`index.json` / `inverted_index.json`（および `embedding.enabled=true` 時は `embeddings_cache/vectors.npz` + `manifest.json`）を生成します。

## 動作

1. `${CLAUDE_PLUGIN_ROOT}/references/scripts/routing/build_index.py` を Python で実行する。
2. 実行後、生成された `<base>/index.json` の末尾統計を読み出してユーザに要約提示する。
3. `<base>` の解決順位は `${CLAUDE_PLUGIN_DATA}` → `<repo>/.claude/.local/plugins/skill-router/` → `~/.claude/.local/plugins/skill-router/`。

## 実行手順

`embedding.enabled=true` のときはベクトル化に venv 内の Python が必要です。共通ヘルパーでインタプリタを選択してから実行します（venv が無い場合はシステム Python にフォールバックし、heuristic のみで再構築します）。

```bash
source "${CLAUDE_PLUGIN_ROOT}/references/scripts/commands/resolve_base.sh"
PY="$(skill_router_venv_python 2>/dev/null || command -v python3 || command -v python)"
"$PY" "${CLAUDE_PLUGIN_ROOT}/references/scripts/routing/build_index.py"
```

実行後、以下のいずれかから `index.json` を Read で取得する:

1. `$CLAUDE_PLUGIN_DATA/index.json` が存在すればそれ
2. リポジトリ配下 `.claude/.local/plugins/skill-router/index.json` があればそれ
3. それ以外は `~/.claude/.local/plugins/skill-router/index.json`

## 提示する内容

- `stats.total_skills_indexed`
- `stats.skills_with_evals`
- `stats.skipped_plugins`
- `stats.scan_duration_ms`
- `inverted_index.json` の `stats.skipped_overgeneric_keywords`
- 失敗があれば `<base>/error.log` の末尾を要約

## 失敗時

- `python` が見つからない場合は「Python 3.10+ が PATH 上にあるか確認してください」と案内する。
- `build_index.py` が存在しない場合はプラグインのインストール状態を確認する旨を案内する。
- フェイルオープン原則のため、Python スクリプト自体は失敗しても exit 0 で透過する。`<base>/error.log` を確認する。
