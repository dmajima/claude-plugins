# case-01 rebuild

skill-router スキルが `router のインデックスを再構築して` 系の依頼に対し、`/router-rebuild` を案内する正例。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "router のインデックスを再構築して" |
| 既存状態 | プラグイン有効化済 / `<base>/` ディレクトリは存在しても空でもよい / `disabled` フラグ不在 |
| モード | 対話 |

## トリガープロンプト

```text
router のインデックスを再構築して
```

## 期待動作

| Phase | 動作 |
|-------|------|
| 1 | skill-router スキルが起動する（high 帯） |
| 2 | `${CLAUDE_PLUGIN_ROOT}/references/scripts/lib/build_index.py` を Bash で実行する |
| 3 | 実行後、生成された `<base>/index.json` を Read で取得し統計を要約する |

## 期待出力

| 出力 | 内容 |
|-----|------|
| 標準出力 | `index.json` 末尾の `stats` フィールドの抜粋（`total_skills_indexed` / `skills_with_evals` / `scan_duration_ms`） |
| 副作用 | `<base>/index.json` / `inverted_index.json` の `generated_at` 更新（`embedding.enabled=true` 時は `embeddings_cache/vectors.npz` + `manifest.json` も差分更新） |
| 失敗時 | `<base>/error.log` の末尾を要約し、フェイルオープン挙動（exit 0）の事実を伝える |

## 分岐の根拠

`commands/router-rebuild.md` と `references/scripts/lib/build_index.py` の `build()` 関数。`/router-rebuild` は index 手動再構築の唯一のエントリポイントであり、SessionStart 自動再構築では足りないシナリオ（プラグイン追加直後・evals 編集後）を救済する分岐。

## 関連ケース

- `case-02_status` — 再構築結果の確認（generated_at が新しいことを `/router-status` で観測）
- `case-10_fail_open` — `build_index.py` がエラーで exit 0 した場合の動作

## 備考

- 同義表現として「router-rebuild したい」「index を再構築」「インデックス再生成」等もカバー
