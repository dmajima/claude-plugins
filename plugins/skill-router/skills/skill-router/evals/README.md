# skill-router evals

skill-router スキルの動作分岐検証用ケース集。`parse_evals.py` が case_md 形式としてパースし、`build_index.py` のインデックスに取り込まれる。

## ケース一覧

| ID | 種別 | 対象分岐 | カバレッジ |
|---|------|---------|----------|
| `case-01_rebuild` | 正例 | `/router-rebuild` 案内 | 操作系・対話 |
| `case-02_status` | 正例 | `/router-status` 案内 + 統計集計 | 操作系・対話 |
| `case-03_disable` | 正例 | `/router-toggle off` + フラグ作成 | 操作系・対話 |
| `case-04_skip_negative` | 負例 | `skip_phrase_single` / `skip_phrase_combo` 発火 | 自動・スコアリング |
| `case-05_diag_no_recommendation` | 診断 | 推奨が出ない時の切り分け（index 不在 / 閾値超過 / disabled） | 診断系・対話 |
| `case-06_diag_over_recommendation` | 診断 | 誤推奨が多い時の切り分け（閾値・skip_keywords・重み） | 診断系・対話 |
| `case-07_diag_slow_start` | 診断 | セッション開始遅延の切り分け（スキル数・逆引き・evals） | 診断系・対話 |
| `case-08_toggle_on` | 正例 | `/router-toggle on` + 全階層フラグ削除 | 操作系・対話・べき等 |
| `case-09_non_interactive` | 変形 | `/router-toggle off` 非対話モード | 操作系・非対話 |
| `case-10_fail_open` | 負例 | index 破損時のフェイルオープン挙動 | 自動・エラー系 |

## カバレッジ達成状況

| 軸 | 達成 | ケース |
|---|------|-------|
| コマンド分岐（rebuild / status / toggle on/off） | ✓ | case-01, 02, 03, 08 |
| スコアリング正例 / 負例 | ✓ | case-02 (実値の正常範囲), case-04 (skip 発火) |
| 診断 3 分岐 | ✓ | case-05, 06, 07 |
| 対話モード / 非対話モード | ✓ | case-01〜08 (対話), case-09 (非対話) |
| エラー系（フェイルオープン） | ✓ | case-10 |
| v0.4 埋め込み有効化フロー | 未 | 追加予定（case-11 以降） |
| v0.4 `/router-embedding-cache` | 未 | 追加予定（case-11 以降） |
| v0.4 改竄検出フェイルオープン | 未 | 追加予定（case-11 以降） |

## 実行確認方法

### 手動確認（対話）

各ケースの「トリガープロンプト」を Claude Code に入力し、「期待動作」「期待出力」と一致するかを観察する。

### 自動確認（ゴールデンテスト）

```bash
# parse_evals.py の動作確認
python references/scripts/lib/parse_evals.py \
  plugins/skill-router/skills/skill-router
```

期待される共通スキーマ（`{id, prompt, expectations, kind}` の配列）を返すことを確認する。

### スコアリング確認（負例ケース）

`case-04_skip_negative` は実インデックスを使った動作確認が必要。手順:

1. `/router-rebuild` で `<base>/index.json` を生成
2. プロンプト「HTML にして」を送信
3. `<base>/sessions/<id>/route_decisions.jsonl` を tail し、`candidate` が `convert-doc:convert-html` であること（`convert-pptx` ではないこと）を確認

### フェイルオープン確認

`case-10_fail_open` は意図的に `<base>/index.json` を不正 JSON に書き換えて確認する。

```bash
# 検証用（注意: 実環境では復旧が必要）
printf 'broken' > <base>/index.json
# プロンプト送信後に <base>/error.log を確認、通常応答が継続することを確認
/router-rebuild   # 復旧
```

旧 `<base>/index.pkl` は pickle ロードの RCE リスクのため廃止済み。`route.py` は `index.json` のみをロードする。

## ケースフォーマット

各 `case-XX_*.md` は以下のセクションを必須とする:

| セクション | 必須 | 内容 |
|-----------|-----|------|
| 入力 | 必須 | 起動フレーズ・既存状態・モード |
| トリガープロンプト | 必須 | 実際の発話文字列（`text` フェンス内） |
| 期待動作 | 必須 | Phase ごとの動作テーブル |
| 期待出力 | 必須 | 標準出力・副作用・失敗時挙動 |
| 分岐の根拠 | 必須 | 設計書セクション参照 + この分岐を持つ理由 |
| 関連ケース | 必須 | 連動するテストケース ID |
| 備考 | 任意 | 同義表現・実装上の注意点 |
