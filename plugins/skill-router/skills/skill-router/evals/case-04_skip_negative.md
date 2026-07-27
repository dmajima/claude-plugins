# case-04 skip negative

ルーティング判定の **負例** ケース。`HTML にして` という曖昧な依頼に対し、`convert-pptx` が誤って high 帯に推奨されないこと（`skip_phrase_combo` または `skip_phrase_single` が発火）を確認する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "HTML にして" |
| 既存状態 | `<base>/index.json` 生成済 / インデックス内に `convert-doc:convert-pptx` と `convert-doc:convert-html` が共存 |
| モード | 自動（UserPromptSubmit フック発火） |

## トリガープロンプト

```text
HTML にして
```

## 期待動作

| Phase | 動作 |
|-------|------|
| 1 | `route.py` の `extract_5w1h` がトークン `html`（および `file_ext`）を抽出 |
| 2 | 逆引き索引で候補に `convert-doc:convert-html` と `convert-doc:convert-pptx` が挙がる |
| 3 | `convert-pptx` の `skip_keywords_noun = [HTML]` がプロンプトトークンと一致し `skip_phrase_single` 発火（重み -1.0） |
| 4 | （`skip_keywords_verb = [変換, 出力]` がプロンプトに動詞として共起する場合は `skip_phrase_combo` 発火、重み -5.0） |
| 5 | スコア順位で `convert-html` が top1、`convert-pptx` が大幅減点で下位 |

## 期待出力

| 出力 | 内容 |
|-----|------|
| ルータ tier | `convert-html` のスコアが閾値到達なら high、そうでなければ mid |
| 推奨スキル | `convert-doc:convert-html`（または mid 帯候補トップ） |
| 抑制対象 | `convert-doc:convert-pptx` は推奨されない |
| `route_decisions.jsonl` | `tier`, `top1`, `top2`, `ratio`, `candidate`, `alternatives` の各フィールドが記録される |

## 分岐の根拠

`references/scripts/routing/route.py` の `_skip_phrase_signals` および `score_skill` の `weights.skip_phrase_combo` / `skip_phrase_single`。動詞 + 名詞共起と単独発火の両分岐をテストする負例抑制機構の代表ケース。

## 関連ケース

- `case-01_rebuild` / `case-02_status` — 正例ケース群
- `case-10_fail_open` — index 破損時の挙動

## 備考

- 同種の負例: 「PDF にして」で `convert-pptx` を抑止、「画像にして」で `convert-html` を抑止 等
- ゴールデンテスト（`tests/test_parse_evals.py`）と組み合わせ、評価ハーネスで自動チェック可能
- 「HTML にして」単独では動詞が含まれないため `skip_phrase_single` が発火する。「HTML に変換して」では combo が発火する
