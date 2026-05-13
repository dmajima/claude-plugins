# case-05 diag no recommendation

ユーザが「skill-router の推奨が出ない」と訴える状況に対し、skill-router スキルが診断フローを実行する正例。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "skill-router の推奨が全然出ない" |
| 既存状態 | プラグイン有効化済 / 状況により index.json 不在 / config.json で閾値が高すぎる / disabled フラグ存在のいずれか |
| モード | 対話・診断 |

## トリガープロンプト

```text
skill-router の推奨が全然出ない
```

## 期待動作

| Phase | 動作 |
|-------|------|
| 1 | skill-router スキルが起動する（high 帯） |
| 2 | base ディレクトリを解決し、`<base>/index.json` の存在 / `stats.total_skills_indexed` / `stats.skipped_plugins` を Bash で確認 |
| 3 | `<base>/disabled` フラグの有無を確認 |
| 4 | `<base>/config.json` を Read し `thresholds.mid_score` / `high_score` の現在値を取得 |
| 5 | `<base>/route.log` の末尾 30 行を Read し直近の tier=low 比率を観測 |
| 6 | 切り分け結果を提示（不在 / 空 / 閾値超過 / 無効化のいずれか） |

## 期待出力

| ケース | 提示内容 |
|-------|---------|
| index 不在 | 「インデックスが未生成です。`/router-rebuild` を実行してください」 |
| index 空（`total_skills_indexed=0` かつ `skipped_plugins>0`） | 「`installed_plugins.json` のスキーマ変動等で全プラグインが skip されています。`<base>/index.log` を確認し、必要なら skill-router を更新してください」 |
| disabled フラグあり | 「現在 OFF。`/router-toggle on` で有効化してください（フラグ位置: <path>）」 |
| 閾値超過（top1 低調） | 「mid_score 閾値が高すぎる可能性があります。`<base>/config.json` の `thresholds.mid_score` を {現在値} → {推奨値} に下げてください」 |
| 候補絞込で 0 件 | 「逆引き索引で候補が見つかっていません。`overgeneric` キーワードリストを確認するか、対象スキルの description に固有語彙を追加してください」 |

## 分岐の根拠

`references/scripts/lib/route.py` の `determine_tier` および `config.json` の `thresholds` セクション + フェイルオープン原則のクロス参照。低帯比率が高い場合は閾値・skip_keywords・index 鮮度のいずれかが原因となるため、診断の最初の入口として配置。

## 関連ケース

- `case-01_rebuild` — index 再構築（不在解消）
- `case-06_diag_over_recommendation` — 逆方向（誤推奨が多い）の診断
- `case-08_toggle_on` — disabled 解除

## 備考

- 同義表現として「ルータが反応しない」「skill-router 動いてない」「推奨が表示されない」等もカバー
- `route.log` の tier 別集計には `/router-status` が便利
