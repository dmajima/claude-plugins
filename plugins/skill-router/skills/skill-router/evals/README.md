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
| `case-11_embedding_cache_hit` | 正例 | v0.4 `embedding.enabled=true` 時の SessionStart キャッシュヒット | 自動・キャッシュ |
| `case-12_embedding_boost_reorder` | 正例 | v0.4 コサイン類似度ブーストによる上位候補入れ替え | 自動・スコアリング |
| `case-13_embedding_disabled` | 正例 | v0.4 `embedding.enabled=false` 既定での後方互換 no-op | 自動・後方互換 |
| `case-14_cache_tamper_failopen` | 負例 | v0.4 vectors.npz 改竄検出時のフェイルオープン | 自動・エラー系 |
| `case-15_max_path_fallback` | 変形 | v0.4 Windows MAX_PATH 超過時の cache_dir 自動フォールバック | OS 別・運用 |
| `case-16_router_embedding_cache_modes` | 正例 | v0.4 `/router-embedding-cache` 統計表示モード | 操作系・対話 |
| `case-17_router_embedding_cache_clear_noninteractive` | 変形 | v0.4 `/router-embedding-cache --clear` 非対話モード | 操作系・非対話 |
| `case-18_router_embedding_cache_show` | 正例 | v0.4 `/router-embedding-cache --show <qn>` 単一スキル詳細 | 操作系・非対話 |
| `case-19_air_gapped_model_dl_failure` | 負例 | v0.4 HF モデル DL 失敗時のフェイルオープン（エアギャップ） | 自動・エラー系 |
| `case-20_embedding_model_switch` | 変形 | v0.4 `embedding.model` 変更時の全キャッシュ無効化 | 運用・モデル切替 |
| `case-21_entries_sha256_tamper` | 負例 | v0.4 manifest.json `entries_sha256` 不一致時のフェイルオープン | 自動・エラー系 |
| `case-22_ambiguous_intent_interactive` | 正例 | SKILL.md 実行モード判定第 3 分岐 (不明意図 → AskUserQuestion で操作 / 診断確定) | 対話・意図判定 |
| `case-23_status_clean_noninteractive` | 変形 | `/router-status --clean` の 30 日超セッション削除（破壊的副作用） | 操作系・非対話・破壊的 |

## カバレッジ達成状況

| 軸 | 達成 | ケース |
|---|------|-------|
| コマンド分岐（rebuild / status / toggle on/off） | ✓ | case-01, 02, 03, 08 |
| スコアリング正例 / 負例 | ✓ | case-02 (実値の正常範囲), case-04 (skip 発火) |
| 診断 3 分岐 | ✓ | case-05, 06, 07 |
| 対話モード / 非対話モード | ✓ | case-01〜08, 22 (対話), case-09, 17, 23 (非対話) |
| 実行モード判定 (明確 / 症状 / 不明) | ✓ | case-01〜03 (明確), case-05〜07 (症状), case-22 (不明 → AskUserQuestion) |
| 破壊的副作用を伴う非対話モード | ✓ | case-17 (`--clear`), case-23 (`--clean`) |
| エラー系（フェイルオープン） | ✓ | case-10, case-14, case-19, case-21 |
| v0.4 埋め込み有効化フロー | ✓ | case-11 (キャッシュヒット), case-12 (boost), case-13 (no-op) |
| v0.4 `/router-embedding-cache` | ✓ | case-16 (統計), case-17 (--clear 非対話), case-18 (--show) |
| v0.4 改竄検出フェイルオープン | ✓ | case-14 (vectors.npz), case-21 (manifest.json) |
| v0.4 Windows MAX_PATH フォールバック | ✓ | case-15 |
| v0.4 エアギャップ / モデル DL 失敗 | ✓ | case-19 |
| v0.4 モデル切替時の全無効化 | ✓ | case-20 |

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
