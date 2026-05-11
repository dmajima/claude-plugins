---
description: skill-router の LLM enrichment キャッシュを参照・クリアする（v0.3 LLM 機能用）
argument-hint: "[--clear] [--show <qualified_name>]"
---

ユーザの引数: $ARGUMENTS

`skill-router` v0.3 で導入された LLM オフライン拡張（Phase A）の **キャッシュ** （`<base>/llm_cache/enrichment.json`）を確認・操作します。LLM 機能を有効化していない場合（`llm.enabled: false`）は「キャッシュは未生成です」と表示します。

## 動作モード

| 引数 | モード | 動作 |
|-----|-------|------|
| 空 | 統計表示 | エントリ数・モデル別内訳・最終生成時刻・上位スキル別 keyword 件数を提示 |
| `--clear` | クリア | `enrichment.json` を削除（次回 SessionStart で全件再生成される） |
| `--show <qualified_name>` | 詳細表示 | 指定スキルの拡張内容（extra_keywords / paraphrase_prompts / task_label）を表示 |

## base ディレクトリ解決

```text
1. CLAUDE_PLUGIN_DATA （定義され書込可能なら最優先）
2. <repo-root>/.claude/.local/plugins/skill-router/
3. <user-home>/.claude/.local/plugins/skill-router/
```

`<base>/llm_cache/enrichment.json` を対象とします。

## 実行手順

### 統計表示（引数なし）

1. base ディレクトリを Bash で解決:
   ```bash
   HOME_DIR="${HOME:-${USERPROFILE:-}}"
   if [[ -n "${CLAUDE_PLUGIN_DATA:-}" && -d "${CLAUDE_PLUGIN_DATA}" ]]; then BASE="${CLAUDE_PLUGIN_DATA}"; \
   elif [[ -d "${PWD}/.claude/.local/plugins/skill-router" ]]; then BASE="${PWD}/.claude/.local/plugins/skill-router"; \
   else BASE="${HOME_DIR}/.claude/.local/plugins/skill-router"; fi; echo "$BASE"
   ```
2. `$BASE/llm_cache/enrichment.json` を Read で取得し JSON として解析。
3. 以下を整形して提示。

```text
[skill-router LLM cache]
- file path           : <base>/llm_cache/enrichment.json
- generated_at        : <iso8601>
- total entries       : <N>
- by model            : <model> = <count>
- top skills (by extra_keywords count):
    1. <qualified_name> (kw=<N>, paraphrases=<M>, label="<task_label>")
    2. ...
```

### --clear

```bash
rm -f "$BASE/llm_cache/enrichment.json"
echo "skill-router: enrichment cache cleared at $BASE/llm_cache/enrichment.json"
echo "次回 SessionStart で再生成されます（llm.enabled=true 時のみ）。"
```

### --show <qualified_name>

1. `$BASE/llm_cache/enrichment.json` を Read。
2. `entries[<qualified_name>]` を取り出し提示:
   ```text
   [skill-router LLM enrichment for <qualified_name>]
   - model               : <model>
   - generated_at        : <iso8601>
   - content_hash        : <sha256[:12]>...
   - task_label          : <text>
   - extra_keywords      : ["...", "...", ...]
   - paraphrase_prompts  : ["...", "...", ...]
   ```
3. 該当エントリが無い場合は「指定スキルのキャッシュは未生成です（`/router-rebuild` で生成されるか、`llm.enabled` を有効化してください）」と案内。

## 失敗時

- `$BASE/llm_cache/enrichment.json` が存在しない場合は「LLM 機能未利用 or 未生成です」と案内。
- JSON 破損時はファイルパスと末尾 200 文字を提示し、`--clear` を提案。
- 削除に失敗した場合はパスを提示しユーザに手動削除を促す。

## 関連

- LLM 設定: `<base>/config.json` の `llm` セクション（既定無効）
- 再生成: `/router-rebuild` （SessionStart と同等のフローで `enrichment.json` も差分更新）
- 統計確認: `/router-status`（`stats.llm` を含めて表示）
