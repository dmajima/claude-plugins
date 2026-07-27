---
description: skill-router のローカル埋め込みキャッシュを参照・クリアする（fastembed ベクトル）
argument-hint: "[--clear] [--show <qualified_name>]"
---

ユーザの引数: $ARGUMENTS

`skill-router` の **埋め込みベース判定** の **キャッシュ** （`<base>/embeddings_cache/`）を確認・操作します。`embedding.enabled: false` の場合は「キャッシュは未生成です」と表示します。

## 動作モード

| 引数 | モード | 動作 |
|-----|-------|------|
| 空 | 統計表示 | キャッシュ統計（エントリ数・行列サイズ・モデル一覧）を提示 |
| `--clear` | クリア | `vectors.npz` と `manifest.json` を削除（次回 SessionStart で全件再生成） |
| `--show <qualified_name>` | 詳細表示 | 指定スキルのキャッシュ情報（content_hash・model・idx・generated_at）を表示 |

## キャッシュファイル

| ファイル | 内容 |
|---|---|
| `<base>/embeddings_cache/vectors.npz` | NumPy 配列（shape: N×D、float32）。各行が 1 スキルのベクトル |
| `<base>/embeddings_cache/manifest.json` | `{qualified_name -> {content_hash, model, idx, generated_at}}` |
| `<venv-base>/embeddings_cache/models/` | fastembed のモデルキャッシュ（ONNX ファイル等。手動配置可）。ベクトルと違い `<venv-base>` 側に置く（onnxruntime が実行するファイルであり、リポジトリ相対に解決されうる `<base>` からは受け取らない） |

## base ディレクトリ解決

```text
1. CLAUDE_PLUGIN_DATA （定義され書込可能なら最優先）
2. <repo-root>/.claude/.local/plugins/skill-router/
3. <user-home>/.claude/.local/plugins/skill-router/
```

## 実行手順

### 統計表示（引数なし）

1. base ディレクトリを共通ヘルパーで解決（ADR-025 準拠、`references/scripts/commands/resolve_base.sh`）:
   ```bash
   BASE="$(bash "$CLAUDE_PLUGIN_ROOT/references/scripts/commands/resolve_base.sh")"
   ```

2. `$BASE/embeddings_cache/manifest.json` を Read。
3. `$BASE/embeddings_cache/vectors.npz` のサイズを確認。
4. 以下を整形して提示:

```text
[skill-router embedding cache]
- manifest path        : <base>/embeddings_cache/manifest.json
- vectors path         : <base>/embeddings_cache/vectors.npz  (<size> bytes)
- generated_at         : <iso8601>
- total entries        : <N>
- vector dimension     : <D>
- by model             : <model> = <count>
- top skills (newest first):
    1. <qualified_name>  hash=<hash[:8]>...  model=<model>
    2. ...
```

### --clear

クリア処理は `references/scripts/commands/clear_embedding_cache.sh` に切り出しています（ADR-025 準拠）。

```bash
bash "$CLAUDE_PLUGIN_ROOT/references/scripts/commands/clear_embedding_cache.sh" "$BASE"
```

注: `models/` 配下の ONNX モデルファイルは削除しません（再ダウンロードコスト回避）。

### --show <qualified_name>

1. `$BASE/embeddings_cache/manifest.json` を Read。
2. `entries[<qualified_name>]` を取得し提示:
   ```text
   [skill-router embedding entry for <qualified_name>]
   - content_hash       : <hash>
   - model              : <model>
   - vector index       : <idx>
   - generated_at       : <iso8601>
   ```
3. 該当エントリが無い場合は「指定スキルのキャッシュは未生成です（`/router-rebuild` で生成されるか、`embedding.enabled` を有効化してください）」と案内。

## 失敗時

- `manifest.json` が存在しない場合は「埋め込み機能未利用 or 未生成です」と案内。
- JSON 破損時はファイルパスと末尾 200 文字を提示し、`--clear` を提案。
- 削除に失敗した場合はパスを提示しユーザに手動削除を促す。

## オフライン環境向け

`embeddings_cache/models/` には fastembed が初回 DL したモデル ONNX が格納されます。エアギャップ環境では:

1. オンライン環境で `--clear` 後 `/router-rebuild` を実行してモデルを取得
2. `embeddings_cache/models/` 配下を丸ごとオフライン環境にコピー
3. `<venv-base>/config.json` の `embedding.cache_dir` を該当パスに指定

## 関連

- `<venv-base>/config.json` の `embedding` セクション（既定無効）
- `/router-rebuild` （SessionStart と同等のフローで `vectors.npz` も差分更新）
- `/router-status`（`stats.embedding` を含めて表示）
