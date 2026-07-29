# skill-router evals

skill-router スキルの動作分岐検証用ケース集。`parse_evals.py` が case_md 形式としてパースし、`build_index.py` のインデックスに取り込まれる。

## ケース一覧

| ID | 種別 | 対象分岐 | カバレッジ |
|---|------|---------|----------|
| `case-01_rebuild` | 正例 | `/router-rebuild` 案内 | 操作系・対話 |
| `case-02_status` | 正例 | `/router-status` 案内 + 統計集計 | 操作系・対話 |
| `case-03_disable` | 正例 | `/router-toggle off` + フラグ作成 | 操作系・対話 |
| `case-04_skip_negative` | 負例 | `skip_phrase_single` / `skip_phrase_combo` 発火 | 自動・スコアリング |
| `case-05_diag_no_recommendation` | 診断 | 推奨が出ない時の切り分け（index 不在 / 閾値超過 / disabled / 候補 0 件）。`route_decisions.jsonl` の `tier: "skip"` と `reason` を根拠に使う | 診断系・対話 |
| `case-06_diag_over_recommendation` | 診断 | 誤推奨が多い時の切り分け（閾値・skip_keywords・重み） | 診断系・対話 |
| `case-07_diag_slow_start` | 診断 | セッション開始遅延の切り分け（スキル数・逆引き・evals） | 診断系・対話 |
| `case-08_toggle_on` | 正例 | `/router-toggle on` + 全階層フラグ削除 | 操作系・対話・べき等 |
| `case-09_non_interactive` | 変形 | `/router-toggle off` 非対話モード | 操作系・非対話 |
| `case-10_fail_open` | 負例 | index 破損時のフェイルオープン挙動 | 自動・エラー系 |
| `case-11_embedding_cache_hit` | 正例 | `embedding.enabled=true` 時の SessionStart キャッシュヒット | 自動・キャッシュ |
| `case-12_embedding_boost_reorder` | 正例 | コサイン類似度ブーストによる上位候補入れ替え | 自動・スコアリング |
| `case-13_embedding_disabled` | 正例 | `embedding.enabled=false` 既定での後方互換 no-op | 自動・後方互換 |
| `case-14_cache_tamper_failopen` | 負例 | vectors.npz 改竄検出時のフェイルオープン | 自動・エラー系 |
| `case-15_max_path_fallback` | 変形 | Windows MAX_PATH 超過時の cache_dir 自動フォールバック | OS 別・運用 |
| `case-16_router_embedding_cache_modes` | 正例 | `/router-embedding-cache` 統計表示モード | 操作系・対話 |
| `case-17_router_embedding_cache_clear_noninteractive` | 変形 | `/router-embedding-cache --clear` 非対話モード | 操作系・非対話 |
| `case-18_router_embedding_cache_show` | 正例 | `/router-embedding-cache --show <qn>` 単一スキル詳細 | 操作系・非対話 |
| `case-19_air_gapped_model_dl_failure` | 負例 | HF モデル DL 失敗時のフェイルオープン（エアギャップ） | 自動・エラー系 |
| `case-20_embedding_model_switch` | 変形 | `embedding.model` 変更時の全キャッシュ無効化 | 運用・モデル切替 |
| `case-21_entries_sha256_tamper` | 負例 | manifest.json `entries_sha256` 不一致時のフェイルオープン | 自動・エラー系 |
| `case-22_ambiguous_intent_interactive` | 正例 | SKILL.md 実行モード判定第 3 分岐 (不明意図 → AskUserQuestion で操作 / 診断確定) | 対話・意図判定 |
| `case-23_status_clean_noninteractive` | 変形 | `/router-status --clean` の 30 日超セッション削除（破壊的副作用） | 操作系・非対話・破壊的 |
| `case-24_diag_prompt_hook_timeout` | 診断 | UserPromptSubmit タイムアウトの切り分け（初回構築 / TTL 超過 / env-error 再構築 / バックオフ / ロック競合 / マーカー未生成 / 撤去の部分失敗 / timeout 値未更新 / index 肥大化 / ソフト予算超過の継続 / 正常範囲）。`prompts.jsonl` と `route_decisions.jsonl` の 1:1 対応と `elapsed_ms` / `over_budget` を根拠に使う | 診断系・対話 |
| `case-25_venv_base_repo_isolation` | 負例 | リポジトリ同梱 `.venv` を実行しない境界（`pyvenv.cfg` 同伴要求 / リポジトリ層の非探索） | 自動・セキュリティ境界 |
| `case-26_embedding_optout_teardown` | 変形 | 埋め込みを無効に戻した際の venv 撤去（TTL 無関係・破壊的） | 自動・破壊的 |
| `case-27_index_name_tamper` | 負例 | リポジトリ供給 `index.json` の名前偽装を `additionalContext` に載せない（実インストール照合） | 自動 |

## カバレッジ達成状況

| 軸 | 達成 | ケース |
|---|------|-------|
| コマンド分岐（rebuild / status / toggle on/off） | ✓ | case-01, 02, 03, 08 |
| スコアリング正例 / 負例 | ✓ | case-12 (boost による再ソート), case-04 (skip 発火) |
| 診断 4 分岐 | ✓ | case-05, 06, 07, 24 |
| 対話モード / 非対話モード | ✓ | 対話: case-01〜03, 05〜08, 22 ／ 非対話（利用者がコマンドで起動）: case-09, 17, 18, 23 ／ 非対話（フックが自動起動）: case-04, 10〜15, 19〜21, 25〜27 |
| 実行モード判定 (明確 / 症状 / 不明) | ✓ | case-01〜03 (明確), case-05〜07, 24 (症状), case-22 (不明 → AskUserQuestion) |
| 破壊的副作用を伴う非対話モード | ✓ | case-17 (`--clear`), case-23 (`--clean`) |
| エラー系（フェイルオープン） | ✓ | case-10, case-14, case-19, case-21 |
| 埋め込み有効化フロー | ✓ | case-11 (キャッシュヒット), case-12 (boost), case-13 (no-op) |
| `/router-embedding-cache` | ✓ | case-16 (統計), case-17 (--clear 非対話), case-18 (--show) |
| 改竄検出フェイルオープン | ✓ | case-14 (vectors.npz), case-21 (manifest.json) |
| Windows MAX_PATH フォールバック | ✓ | case-15 |
| エアギャップ / モデル DL 失敗 | ✓ | case-19 |
| モデル切替時の全無効化 | ✓ | case-20 |
| venv ライフサイクル（既定非構築 / TTL / 再構築 / バックオフ / ロック競合） | ✓ | case-13（既定非構築）, case-24（プロンプト経路の切り分け）, case-07（SessionStart 経路）, case-26（opt-out 時の撤去） |
| 未来 mtime / TTL 下限 / weight クランプ | unit test で担保 | `test_venv_lifecycle.py` / `test_embedding_client.py` |
| venv の配置境界（リポジトリ同梱インタプリタの排除） | ✓ | case-25 |
| リポジトリ供給 index の名前偽装遮断（additionalContext への注入） | ✓ | case-27 |

## 実行確認方法

### 手動確認（対話）

各ケースの「トリガープロンプト」を Claude Code に入力し、「期待動作」「期待出力」と一致するかを観察する。

### 自動確認（ゴールデンテスト）

リポジトリルートから実行する。

```bash
# parse_evals.py の動作確認
python plugins/skill-router/references/scripts/routing/parse_evals.py \
  plugins/skill-router/skills/skill-router
```

期待される共通スキーマ（`{id, prompt, expectations, kind}` の配列）を返すことを確認する。`expectations` は case_md 形式では常に空配列になる（抽出器は `## 期待` 単独見出しのみを対象とし、本ケース集は `## 期待動作` / `## 期待出力` を使う）。これは意図した仕様で、`test_parse_evals.py` が固定している。

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
# プロンプト送信後に <base>/sessions/<sid>/route_decisions.jsonl を確認
/router-rebuild   # 復旧
```

不正 JSON は `load_index()` が `json.JSONDecodeError` を捕捉して `{}` を返すため、例外は外へ伝播しない。したがって **`error.log` は更新されない**。確認すべきは `route_decisions.jsonl` に `tier: "skip"` / `reason: "index_empty"` が記録され、通常応答が継続することである。`error.log` が書かれるのは `main()` の外側まで例外が抜けた致命的経路のみで、`case-10_fail_open` の期待出力表はこの 2 経路を区別している。

`route.py` は `index.json` のみをロードする（pickle 経路を持たない）。

### venv TTL 撤去の確認

`case-24_diag_prompt_hook_timeout` の中核分岐（TTL 超過による撤去）を再現する。`<venv-base>` は `${CLAUDE_PLUGIN_DATA}`、無ければ `~/.claude/.local/plugins/skill-router/`。

TTL 判定は最終利用時刻と構築時刻の両方を見る（マーカーだけを遡らせても撤去されない。`test_backdated_marker_alone_does_not_remove_fresh_venv` が保証する仕様）。したがって両方を遡らせる。

```bash
touch -d '8 days ago' "<venv-base>/.venv-last-used" "<venv-base>/.venv/pyvenv.cfg"
python "$CLAUDE_PLUGIN_ROOT/references/scripts/routing/venv_lifecycle.py" cleanup-if-stale --plugin-root "$CLAUDE_PLUGIN_ROOT"
test -d "<venv-base>/.venv" && echo "NG: 残存" || echo "OK: 撤去された"
```

`--plugin-root` は必須。省略すると requirements が見つからず「判定不能」として何もせずに返る。また `<venv-base>/config.json` の `embedding.enabled` が true でないと TTL 以前に「不要」と判定されて撤去されるため、TTL 分岐の検証にはならない。

判定は `cleanup-if-stale` を単体で実行して確認する。SessionStart フック全体を実行すると、`embedding.enabled=true` の場合は後続の `ensure` が同一フック内で再構築するため、撤去の成否を `.venv` の有無で判別できない。

マーカーを即時に復旧する場合は次を実行する。

```bash
python "$CLAUDE_PLUGIN_ROOT/references/scripts/routing/venv_lifecycle.py" touch-last-used
```

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
