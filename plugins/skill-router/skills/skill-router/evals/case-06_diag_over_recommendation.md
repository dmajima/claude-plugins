# case-06 diag over recommendation

ユーザが「skill-router の誤推奨が多い」と訴える状況に対し、skill-router スキルが診断フローを実行する正例。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "skill-router の誤推奨が多すぎる" |
| 既存状態 | `<base>/route_decisions.jsonl` に high 帯誤推奨記録が複数存在 / `config.json` の閾値が低すぎる可能性 |
| モード | 対話・診断 |

## トリガープロンプト

```text
skill-router の誤推奨が多すぎる
```

## 期待動作

| Phase | 動作 |
|-------|------|
| 1 | skill-router スキルが起動する（high 帯） |
| 2 | `<base>/sessions/*/route_decisions.jsonl` の最終 50 件を tail し high 帯比率を集計 |
| 3 | high 帯の `candidate` ごとに頻度をカウント（過剰推奨されているスキルを特定） |
| 4 | 該当スキルの `<base>/index.json` 内 `skip_keywords_verb` / `skip_keywords_noun` を確認 |
| 5 | `<base>/config.json` の `weights.skip_phrase_combo` / `skip_phrase_single` を確認 |
| 6 | 改善方針をユーザに提示 |

## 期待出力

| ケース | 提示内容 |
|-------|---------|
| 閾値が低すぎる | 「`high_score` を {現在値} → {推奨値} に上げる、または `high_ratio` を 1.25 → 1.5 に強化してください」 |
| skip_keywords 不足 | 「`{誤推奨されているスキル}` の SKIP when 句に `{推奨追加語彙}` を追加し、`/router-rebuild` を実行してください」 |
| 重みバランス不適 | 「`weights.skip_phrase_combo` を -5.0 → -7.0 に強化、または `keyword_overlap` を 1.0 → 0.5 に弱化してください」 |
| 候補絞込が広すぎる | 「`candidate_filter.max_candidates_per_route` を 50 → 30 に絞ってください（候補絞込みで誤推奨候補が多く混入）」 |

## 分岐の根拠

`references/scripts/routing/route.py` の `_skip_phrase_signals` / `score_skill` の `skip_phrase_combo` / `skip_phrase_single` と `thresholds.high_ratio`（相対比閾値）。誤推奨が多い症状は閾値・skip_keywords・重みの 3 軸のいずれかで対処可能なため、各軸の現在値を確認した上で改善案を絞り込む。

## 関連ケース

- `case-04_skip_negative` — skip_phrase 動作確認の正例
- `case-05_diag_no_recommendation` — 逆方向（推奨が出ない）の診断

## 備考

- 同義表現として「skill-router がうるさい」「ルータが過剰推奨してくる」「変なスキルを推奨される」等もカバー
- `--clean` で古いセッションを削除すると比率集計が正常化することがある
