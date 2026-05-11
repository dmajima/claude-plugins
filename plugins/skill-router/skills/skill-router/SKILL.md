---
name: skill-router
description: skill-router の `<base>/index.json` / disabled / `embeddings_cache/` / ログを操作・診断するスキル。「router の状態確認」「インデックス再構築」「埋め込みキャッシュ確認」「skill-router を停止」等の依頼で起動し、`/router-rebuild` `/router-status` `/router-toggle` `/router-embedding-cache` の使い分けと、v0.4 で追加されたオフライン埋め込み判定（`embedding.enabled`）を説明する。Use when operating skill-router. SKIP when editing routing logic (use hook-toolkit or edit route.py).
allowed-tools: Read, Grep, Glob, Bash
---

# skill-router

Claude Code に有効化されたスキルを `UserPromptSubmit` フックで自動推奨し、スキル起動率を高めるルーティングプラグインの **操作・診断ガイド** スキル。

ルーティング本体（インデックス生成・スコア計算・additionalContext 注入）はフックと Python スクリプトが担うため、本スキルは利用者向けの操作支援とテスト用 evals 保持を担当する。

## 責務

- `/router-rebuild` / `/router-status` / `/router-toggle` 各コマンドの使い分けを案内する
- ルーティングが期待どおり動作しないときの診断手順（`<base>/index.log` / `route.log` / `error.log` の確認）を案内する
- `<base>/index.json` / `inverted_index.json` / `route_decisions.jsonl` を Read で要約してユーザに状態を共有する
- 動作分岐検証用の evals（`evals/case-XX_*.md`）を保持し、parse_evals.py のゴールデンソースとして機能する

## 責務外（他スキルが担当）

| 業務 | 担当 |
|-----|-----|
| スコア計算ロジックの改修 | `references/scripts/lib/route.py` を直接編集 |
| インデックス生成ロジックの改修 | `references/scripts/lib/build_index.py` を直接編集 |
| フック設定の変更 | `extension-toolkit:hook-toolkit` |
| 新スキル追加時のインデックス更新 | 何もしない（次の `SessionStart` で自動再構築） |
| 公開・PR 作成 | `extension-toolkit:marketplace-publisher` |

## トリガー条件

- 「skill-router の状態を見たい」「ルータの統計が知りたい」
- 「インデックスを再構築して」「router-rebuild したい」
- 「skill-router を一時停止」「ルーティングを切って」
- 「ルータのログを確認したい」「どのスキルが推奨されたか見たい」

## 前提

呼び出し時に以下が満たされていること（不足時はスキル内で案内する）。

1. Python 3.10+ が `python` または `python3` として PATH 上に存在する
2. プラグインが有効化されている（`~/.claude/settings.json` の `enabledPlugins` に登録）
3. 一度でも `SessionStart` フックが発火したか、`/router-rebuild` を手動実行済み（`<base>/index.json` が存在する）

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| 操作意図が明確（rebuild / status / toggle のいずれか） | 直接実行 | 該当コマンドを案内、または Bash で実行 |
| 症状ベースの依頼（「推奨が出ない」等） | 診断 | `<base>` 配下のログ・index を Read で確認し原因を切り分け |
| 不明 | 対話 | `AskUserQuestion` で意図（操作 / 診断）を確認 |

## 実行フロー

### 操作系

1. ユーザの意図を確認（rebuild / status / toggle のいずれか）
2. 適切なコマンドを案内、または直接 Bash で実行
3. 結果（statistics / 直近の決定 / トグル状態）をユーザに要約

### 診断系

1. 症状の切り分け
   - 「推奨が出ない」→ index 存在 / config 閾値 / disabled 有無
   - 「誤推奨が多い」→ skip_keywords 設定 / config 重み / 候補絞込結果
   - 「セッション開始が遅い」→ build_index ログ・スキル数・逆引き索引サイズ
2. 該当する base ディレクトリを特定（下節「base ディレクトリ」参照）
3. `index.log` / `route.log` / `error.log` を Read で確認

## base ディレクトリの解決順位

| 優先 | パス | 備考 |
|-----|------|------|
| 1 | `${CLAUDE_PLUGIN_DATA}` | Claude Code が提供する場合のみ |
| 2 | `<repo-root>/.claude/.local/plugins/skill-router/` | 現在地から `.git` を上方探索（`$HOME` を超えない） |
| 3 | `~/.claude/.local/plugins/skill-router/` | フォールバック |

## 主要ファイル

| ファイル | 役割 |
|---------|------|
| `<base>/config.json` | 重み・閾値・埋め込み設定の外部化 |
| `<base>/index.json` | インデックス本体（schema_version=3 から `stats.embedding` 含む） |
| `<base>/inverted_index.json` | 逆引き索引 |
| `<base>/embeddings_cache/vectors.npz` | 各スキルの埋め込みベクトル（NumPy 配列） |
| `<base>/embeddings_cache/manifest.json` | スキル名 → ベクトル行番号・content_hash・model の対応 |
| `<base>/embeddings_cache/models/` | fastembed の ONNX モデルキャッシュ |
| `<base>/disabled` | トグル無効化フラグ |
| `<base>/sessions/<id>/prompts.jsonl` | プロンプト履歴 |
| `<base>/sessions/<id>/route_decisions.jsonl` | ルーティング決定履歴（`embedding_used` を含む） |

## 関連スキル / コマンド

| 種別 | 名前 | 用途 |
|-----|------|------|
| コマンド | `/router-rebuild` | index 手動再構築（embedding 有効時はベクトルも差分更新） |
| コマンド | `/router-status` | 統計・直近決定・スコア分布表示（`--clean` で 30 日超セッション削除）。`stats.embedding` も含めて表示 |
| コマンド | `/router-toggle` | `on` / `off` 切り替え |
| コマンド | `/router-embedding-cache` | 埋め込みキャッシュ参照・クリア（v0.4） |

## 埋め込み判定（v0.4+）

`<base>/config.json` の `embedding` セクションで **完全ローカル** の意味的類似度判定を有効化できる。外部 API には一切接続しない。デフォルトは無効（`embedding.enabled: false`）で、有効化前後の挙動・初回モデル DL・ディスク占有・トラブルシュート方法をユーザに案内すること。

| キー | 既定 | 説明 |
|-----|------|------|
| `embedding.enabled` | `false` | 親スイッチ |
| `embedding.model` | `paraphrase-multilingual-MiniLM-L12-v2` | fastembed が対応する多言語埋め込みモデル |
| `embedding.cache_dir` | `null` | モデル ONNX キャッシュ先（null は `<base>/embeddings_cache/models/`） |
| `embedding.weight` | `3.0` | コサイン類似度に乗じる係数 |
| `embedding.min_similarity` | `0.3` | この値未満はスコア加算しない（ノイズ抑制） |
| `embedding.max_skills_per_run` | `200` | 1 SessionStart で再ベクトル化するスキル数の上限 |

動作:
- **SessionStart**: 各スキルの description / use_when / skip_when / trigger_phrases / evals.prompt を結合して fastembed で 384 次元ベクトルに変換し `<base>/embeddings_cache/vectors.npz` に保存（content hash で差分のみ再計算）
- **UserPromptSubmit**: プロンプトをベクトル化し、heuristic 候補との **コサイン類似度** を計算。`boosted = heuristic + weight * max(0, sim - min_similarity)` でスコアを補正

外部通信は **初回モデル DL のみ**（HuggingFace ハブから）。エアギャップ環境では事前に `embeddings_cache/models/` を配置してください。

埋め込み機能の状態は `/router-status` の `stats.embedding` で確認できる。キャッシュ参照は `/router-embedding-cache` を案内すること。

## evals

`evals/case-01_rebuild.md` 〜 `evals/case-10_fail_open.md` の 10 ケースで、コマンド誘導・ルーティング判定の負例・診断フロー・非対話モード・フェイルオープン挙動をカバーする。詳細は `evals/README.md` を参照。

## 重要な制約

- スコアリング・インデクサのロジック改修は本スキルからは行わない（`references/scripts/lib/route.py` / `build_index.py` を直接編集する）
- `session_id` 解決の最終フォールバックは `sha256(host + cwd + sec + pid)` で衝突確率は実用上 0
- フェイルオープン原則のため、エラー時も `exit 0` で透過する
- `<base>/disabled` フラグは 3 段階の優先順位で参照されるため、再有効化時は全層で削除を試みる必要がある

## 参照

| 用途 | パス |
|-----|------|
| ルーティング本体 | `${CLAUDE_PLUGIN_ROOT}/references/scripts/lib/route.py` |
| インデクサ | `${CLAUDE_PLUGIN_ROOT}/references/scripts/lib/build_index.py` |
| evals パーサ | `${CLAUDE_PLUGIN_ROOT}/references/scripts/lib/parse_evals.py` |
| セッション状態 | `${CLAUDE_PLUGIN_ROOT}/references/scripts/lib/session_state.py` |
| 埋め込みクライアント (v0.4) | `${CLAUDE_PLUGIN_ROOT}/references/scripts/lib/embedding_client.py` |
| スキルベクトル化 (v0.4) | `${CLAUDE_PLUGIN_ROOT}/references/scripts/lib/embedding_enrich.py` |
| 類似度補助スコア (v0.4) | `${CLAUDE_PLUGIN_ROOT}/references/scripts/lib/embedding_route.py` |
| spike 一覧 | `${CLAUDE_PLUGIN_ROOT}/references/spike/` |
| 設定既定値 | `${CLAUDE_PLUGIN_ROOT}/references/templates/config.default.json` |
