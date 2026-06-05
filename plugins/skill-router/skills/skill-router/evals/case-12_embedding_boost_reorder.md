# case-12 embedding boost reorder

`embedding.enabled=true` の状態で UserPromptSubmit 時にコサイン類似度がヒューリスティックスコアに加算され、上位候補の順位が **意味的に妥当な方向に入れ替わる** ことを確認する正例。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | 「Markdown を PDF に変換したい」 |
| 既存状態 | `embedding.enabled=true`、`vectors.npz` 構築済、`/plugin install convert-doc@dmajima-claude-plugins` 済 |
| モード | 自動（フック発火） |

## トリガープロンプト

```text
Markdown を PDF に変換したい
```

## 期待動作

| Phase | 動作 |
|-------|------|
| 1 | `route.route` がヒューリスティックで候補スキルをスコアリング |
| 2 | `convert-doc:convert-pdf` / `convert-doc:convert-html` / `convert-doc:convert-pptx` のスコアが近接（mid 帯境界） |
| 3 | `embedding.enabled=true` のため `embedding_enrich.load_manifest` + `load_vectors` を `expected_sha256` 付きで読み込み |
| 4 | `embedding_route.boost_rows` がプロンプトをベクトル化し、各候補とのコサイン類似度を `weight * max(0, sim - min_similarity)` で加算 |
| 5 | 再ソート後、`convert-doc:convert-pdf` が `top1` として固定（意味的に最近接のため） |

## 期待出力

| 出力 | 内容 |
|-----|------|
| `route_decisions.jsonl` の最終行 | `{"tier": "high" or "mid", "embedding_used": true, "candidate": "convert-doc:convert-pdf", ...}` |
| `route.log` | `tier=... embedding=on` の行 |
| reasons 列 | 各候補の `reasons` に `embedding_sim=+0.XX (+Y.YY)` または `embedding_sim=+0.XX (gated)` が含まれる |

## 分岐の根拠

`references/scripts/lib/embedding_route.py` の `boost_rows` および `route.py` の `embedding_used` フラグ管理。表層一致では拾えない言い換え・同義語に対し意味的類似度で補正する v0.4 の中核機能を担保する分岐。

## 関連ケース

- `case-02_status` — `route_decisions.jsonl` の参照
- `case-11_embedding_cache_hit` — ベクトルキャッシュの読込
- `case-13_embedding_disabled` — `embedding.enabled=false` 時に boost が動作しないことの裏返し

## 備考

- 同義表現: 「md を pdf にして」「PDF 化したい」「マークダウンから PDF 出力」など、表層一致だけでは convert-pptx と区別しづらい入力で boost の効果が顕著
- `min_similarity` 未満の類似度は noise gate で 0 加算となり `(gated)` と記録される
