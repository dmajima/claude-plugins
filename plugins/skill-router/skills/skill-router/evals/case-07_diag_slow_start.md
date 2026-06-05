# case-07 diag slow start

ユーザが「skill-router 関連で SessionStart が遅い」と訴える状況に対し、skill-router スキルが診断フローを実行する正例。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "セッション開始が遅い気がする" |
| 既存状態 | `<base>/index.log` に直近の `scan_duration_ms` 記録あり / インデックス対象スキル数が想定より多いケースが存在 |
| モード | 対話・診断 |

## トリガープロンプト

```text
セッション開始が遅い気がする
```

## 期待動作

| Phase | 動作 |
|-------|------|
| 1 | skill-router スキルが起動する（high または mid 帯） |
| 2 | `<base>/index.log` の末尾 10 行を Read し直近の `scan_duration_ms` を取得 |
| 3 | `<base>/index.json` の `stats` を Read し `total_skills_indexed` / `skills_with_evals` を取得 |
| 4 | `<base>/inverted_index.json` の `stats.total_keywords` を Read し逆引き索引サイズを確認 |
| 5 | レイテンシ予算（200 スキル: 2 秒、1000 スキル: 5 秒）と比較（`SKILL.md` 「重要な制約」参照）|
| 6 | `embedding.enabled=true` の場合、`stats.embedding.build_duration_ms` を確認しベクトル化コストを別軸として測定 |
| 7 | ボトルネックを切り分けて改善案を提示 |

## 期待出力

| ケース | 提示内容 |
|-------|---------|
| スキル数が大きすぎる | 「インデックス対象 {N} スキル / 予算 5 秒は 1000 スキル想定。不要なプラグインを `enabledPlugins` から除外してください」 |
| 逆引き索引が膨大 | 「`inverted_index` のキーワード数 {K} が異常。`overgeneric` 閾値（`max_postings_per_keyword`）を 50 → 30 に下げてください」 |
| evals が重い | 「`skills_with_evals={M}` で evals パースに時間消費。`parse_evals.py` のゴールデンテストでパフォーマンス回帰を確認してください」 |
| **embedding 初回 DL** | 「`stats.embedding.build_duration_ms={B}ms` が大。初回モデル DL（HF ハブから 120MB）が原因の場合は 2 回目以降キャッシュヒットで縮小（case-11）。次回起動で再測定を推奨」 |
| **embedding 全件再ベクトル化** | 「モデル変更（case-20）または `vectors.npz` 改竄（case-14）でキャッシュ全無効化された可能性。`/router-embedding-cache` で状態確認」 |
| 予算内で正常 | 「現在 {scan_duration_ms}ms で予算内。体感の遅さは別要因（Python 起動・他フック干渉）の可能性。`references/research/s5_python_startup_latency.py` を実行して切り分けてください」 |

## 分岐の根拠

`references/scripts/lib/build_index.py` の `build` で記録される `stats.scan_duration_ms` と `references/research/s5_python_startup_latency.py`（Python 起動 cold/warm レイテンシ実測）。SessionStart 起動遅延は `build_index.py` の処理時間か Python 起動コストか他フック干渉のいずれかで、各原因を切り分ける必要がある。

## 関連ケース

- `case-01_rebuild` — 手動再構築での `scan_duration_ms` 観測
- `references/research/s5_python_startup_latency.py` — Python 起動レイテンシ実測

## 備考

- 同義表現として「SessionStart が重い」「Claude Code 起動が遅い」「セッション開始時間が長い」等もカバー
- 1000 スキルを超える環境ではスケーラビリティ設計（H4 逆引き索引）の限界に達する可能性あり
