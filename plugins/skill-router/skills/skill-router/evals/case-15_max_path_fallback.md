# case-15 Windows MAX_PATH cache_dir fallback

Windows 環境で `<base>/embeddings_cache/models/` のフルパス長が 100 文字を超える場合、`embedding.cache_dir` 未指定時に **`~/AppData/Local/skill-router/models/` に自動フォールバック** することを確認する正例。

## 入力

| 項目 | 内容 |
|-----|------|
| OS | Windows |
| 既存状態 | `embedding.enabled=true`、`embedding.cache_dir` 未指定（`null`）、`<base>` が深いパス（例: `<repo-root>\.claude\.local\work\<session>\workspace\verify-base` のように合算 100 文字超）配下にある |
| モード | 非対話（自動・SessionStart）|

## トリガープロンプト

```text
/router-rebuild
```

## 期待動作

| Phase | 動作 |
|-------|------|
| 1 | `embedding_client._resolve_cache_dir(cfg, base)` が呼ばれる |
| 2 | `cfg.cache_dir is None` のため primary candidate `<base>/embeddings_cache/models` を計算 |
| 3 | `os.name == "nt"` かつ `len(str(primary)) > 100` を検出 |
| 4 | `_fallback_cache_dir` が `~/AppData/Local/skill-router/models` を返す |
| 5 | `<base>/index.log` に WARNING ログ記録（フォールバック理由・推奨対処） |
| 6 | fastembed が短いパスでモデル DL 成功（`[WinError 206] ファイル名が長すぎます` を回避） |

## 期待出力

| 出力 | 内容 |
|-----|------|
| `index.log` | `embedding cache_dir <primary> is too deep for Windows MAX_PATH (len=N > 100); falling back to <home>/AppData/Local/skill-router/models. Set config.embedding.cache_dir explicitly to override.` |
| `<home>/AppData/Local/skill-router/models/` | fastembed の ONNX モデルファイル群が DL される |
| `<base>/embeddings_cache/manifest.json` | 通常通り生成（vectors も同様）|
| `index.json` | `stats.embedding.enabled=true`、`skills_vectorised>0` |

## 分岐の根拠

`references/scripts/lib/embedding_client.py` の `_resolve_cache_dir` における Windows MAX_PATH (260 文字) 自動フォールバック。`<base>` がリポジトリ深層（`.claude/.local/work/...`）配下に置かれる検証用シナリオで `[WinError 206]` を回避するために必須の挙動。

## 関連ケース

- `case-11_embedding_cache_hit` — 通常パス時の挙動
- `case-12_embedding_boost_reorder` — フォールバック後も routing は正常動作

## 備考

- POSIX 環境（Linux / macOS）では `os.name != "nt"` のため自動フォールバックは発動せず、常に `<base>/embeddings_cache/models/` を使用
- ユーザが `embedding.cache_dir` を明示指定した場合は自動フォールバックは行わず、その値を尊重（ログにも警告は出さない）
- フォールバック先パス: `~/AppData/Local/skill-router/models/`（Windows）/ `~/.cache/skill-router/models/`（POSIX）
