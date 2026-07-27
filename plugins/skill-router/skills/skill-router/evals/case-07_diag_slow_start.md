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
| 5 | `index.json` の `stats.scan_duration_ms` を `hooks.json` の `SessionStart.timeout`（360 秒）と比較する。予算に対する実測値はここでしか得られないため、体感の遅さではなくこの値で判定する |
| 6 | `embedding.enabled=true` の場合、`stats.embedding.build_duration_ms` を確認しベクトル化コストを別軸として測定 |
| 7 | `<venv-base>/.venv-last-used` と `<venv-base>/.venv/pyvenv.cfg` の mtime、`<venv-base>/venv-construct.log` を確認し、当該セッションで venv 構築が走ったかを判定 |
| 8 | ボトルネックを切り分けて改善案を提示 |

## 期待出力

| ケース | 提示内容 |
|-------|---------|
| スキル数が大きすぎる | 「インデックス対象 {N} スキル / 予算 5 秒は 1000 スキル想定。不要なプラグインを `enabledPlugins` から除外してください」 |
| 逆引き索引が膨大 | 「`inverted_index` のキーワード数 {K} が異常。`overgeneric` 閾値（`max_postings_per_keyword`）を 50 → 30 に下げてください」 |
| evals が重い | 「`skills_with_evals={M}` で evals パースに時間消費。`parse_evals.py` のゴールデンテストでパフォーマンス回帰を確認してください」 |
| **embedding 初回 DL** | 「`stats.embedding.build_duration_ms={B}ms` が大。初回モデル DL（HF ハブから 120MB）が原因の場合は 2 回目以降キャッシュヒットで縮小（case-11）。次回起動で再測定を推奨」 |
| **embedding 全件再ベクトル化** | 「モデル変更（case-20）または `vectors.npz` 改竄（case-14）でキャッシュ全無効化された可能性。`/router-embedding-cache` で状態確認」 |
| **venv 構築が走った** | 「`embedding.enabled=true` で venv が未構築、または TTL（最終利用から 168h）超過で撤去されたため、同一セッションの `ensure` が構築（作成 60 秒 + pip install 180 秒 = 最大 240 秒）を実行しました。完了後のセッションでは発生しません。`embedding` を使わない場合は `embedding.enabled=false`（既定）にすると構築自体が走りません」 |
| 予算内で正常 | 「現在 {scan_duration_ms}ms で予算内。体感の遅さは別要因（Python 起動・他フック干渉）の可能性。`references/research/s5_python_startup_latency.py` を実行して切り分けてください」 |

## 分岐の根拠

`references/scripts/routing/build_index.py` の `build` で記録される `stats.scan_duration_ms` と `references/research/s5_python_startup_latency.py`（Python 起動 cold/warm レイテンシ実測）。SessionStart 起動遅延は `build_index.py` の処理時間か Python 起動コストか他フック干渉のいずれかで、各原因を切り分ける必要がある。

## 関連ケース

- `case-01_rebuild` — 手動再構築での `scan_duration_ms` 観測
- `case-24_diag_prompt_hook_timeout` — プロンプト経路側のタイムアウト診断（venv 構築との競合）
- `references/research/s5_python_startup_latency.py` — Python 起動レイテンシ実測

## 備考

- 同義表現として「SessionStart が重い」「Claude Code 起動が遅い」「セッション開始時間が長い」等もカバー
- スキル数が増えると逆引き索引（`inverted_index.json`）の走査コストが支配的になる。`candidate_filter.max_postings_per_keyword` の引き下げ、または `enabledPlugins` の削減で緩和する
