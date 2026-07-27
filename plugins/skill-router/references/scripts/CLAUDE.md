# scripts/ 利用ガイド

## 目的

`skill-router` の実行可能コード一式。フックのエントリポイント（`hooks/`）、ルーティングとインデックスの実装（`routing/`）、スラッシュコマンドの実体（`commands/`）、venv 構築・撤去（`setup/`）、回帰テスト（`tests/`）を業務単位で分割して配置する。

## ファイル一覧

### hooks/ — フックのエントリポイント（Bash）

| ファイル | 説明 |
|---------|------|
| `hooks/build_index_on_start.sh` | `SessionStart` フック本体。`prepare`（`session-reset` → `cleanup-if-stale` → `ensure` → インタプリタ解決を 1 プロセスで実行）→ `build_index.py`。失敗時は env-error 判定 → `rebuild` → 再実行 |
| `hooks/route_prompt.sh` | `UserPromptSubmit` フック本体。トグル無効化フラグの確認 → インタプリタ選択（`resolve_base.sh` の `skill_router_venv_python`）→ `route.py` に stdin をそのまま渡す。stdin の JSON は Bash で解析せず Python に委譲する。常に `exit 0` |

### routing/ — ルーティング本体（Python）

| ファイル | 説明 |
|---------|------|
| `routing/build_index.py` | インストール済みスキルを走査して `index.json` / `inverted_index.json` を生成する |
| `routing/route.py` | プロンプトのスコアリングと `additionalContext` 生成。high / mid / low の帯判定を行う |
| `routing/config_io.py` | `config.json` のローダと `<base>` / `<venv-base>` の解決（`resolve_base_dir()` / `resolve_venv_base()` の定義元）。`build_index` と `route` が共用 |
| `routing/text_tokens.py` | キーワード抽出。索引構築（`build_index`）と照合（`route`）が同一規則を使うための単一の出典 |
| `routing/installed.py` | index が自称する `qualified_name` を実インストール（`~/.claude/plugins/`）と照合する。`additionalContext` に載る名前の検証元 |
| `routing/parse_evals.py` | 各スキルの `evals/case-*.md` を共通スキーマ（`{id, prompt, expectations, kind}`）へパースする |
| `routing/session_state.py` | セッション履歴（`prompts.jsonl` / `route_decisions.jsonl`）の記録 |
| `routing/embedding_client.py` | ローカル埋め込みクライアント（fastembed ラッパー。インポート失敗時は no-op へフォールバック） |
| `routing/embedding_enrich.py` | SessionStart 側のスキルベクトル化（content hash による差分再計算） |
| `routing/embedding_route.py` | UserPromptSubmit 側のコサイン類似度によるスコア補正 |
| `routing/venv_lifecycle.py` | venv の構築・再構築・TTL 撤去・インタプリタ解決。`<venv-base>` の決定と `.venv-last-used` の管理元 |

### commands/ — スラッシュコマンドの実体

| ファイル | 説明 |
|---------|------|
| `commands/resolve_base.sh` | `<base>` / `<venv-base>` 解決と venv インタプリタ選択の Bash 実装。両フックから source される実行時必須ファイル |
| `commands/toggle.sh` | `/router-toggle` の実体。`disabled` フラグを 3 階層で作成・削除する |
| `commands/clear_embedding_cache.sh` | `/router-embedding-cache --clear` の実体 |
| `commands/clean_old_sessions.py` | `/router-status --clean` の実体。30 日超のセッションディレクトリを削除する |

### setup/ — venv 構築・撤去（開発・テスト用）

| ファイル | 説明 |
|---------|------|
| `setup/requirements.txt` | 埋め込み機能の依存定義（`fastembed` / `numpy` / `onnxruntime`）。`requirements.lock` を置くとハッシュ検証付きインストールに切り替わる |
| `setup/setup_venv.sh` | 作業領域に venv を構築する汎用スクリプト |
| `setup/teardown_venv.sh` | 同 venv を削除する |

### run/ — 手動実行用ラッパー（任意利用）

| ファイル | 説明 |
|---------|------|
| `run/run_via_job.sh` | Python スクリプトをタイムアウト付き・UTF-8 強制で実行する。利用者が手動でスクリプトを起動する場合の入口。フック経路は経由しない（プロセス起動を増やさないため） |

### tests/ — 回帰テスト（標準ライブラリの `unittest`）

| ファイル | 説明 |
|---------|------|
| `tests/test_build_index.py` | インデックス生成の検証 |
| `tests/test_route.py` | スコアリング・帯判定の検証 |
| `tests/test_parse_evals.py` | evals パースのゴールデンテスト |
| `tests/test_session_state.py` | セッション履歴記録の検証 |
| `tests/test_venv_lifecycle.py` | venv ライフサイクル（構築・再構築上限・TTL 撤去・マーカー更新・フック結線）の検証 |
| `tests/test_resolve_base.py` | `commands/resolve_base.sh` の不変条件（venv-base がリポジトリを含まない / `pyvenv.cfg` 必須 / POSIX symlink 許容 / disabled 3 階層 / `/router-toggle` の往復）と、Bash 実装・Python 実装の出力一致（lock-step 差分テスト）を検証 |
| `tests/test_config_io.py` | `<base>` / `<venv-base>` 解決（Python 側）と `open_append`（リンク非追従・作成時 0600）の検証 |
| `tests/test_text_tokens.py` | トークナイザ規則（漢字 2 文字・カタカナ 4 文字・英語ストップワード・重複排除）の固定 |
| `tests/test_installed.py` | `qualified_name` の実インストール照合と、その各拒否経路の検証 |
| `tests/test_embedding_client.py` / `test_embedding_enrich.py` / `test_embedding_route.py` | 埋め込み機能の検証（`fastembed` 不在環境ではスキップ） |

## 利用ルール

- フック経路（`hooks/` と、そこから呼ばれる `routing/route.py` / `routing/build_index.py`）は例外を送出せず `exit 0` で透過する
- `<base>` の解決は `routing/config_io.py` の `resolve_base_dir()` と `commands/resolve_base.sh` の `skill_router_base` を同一の順序（`CLAUDE_PLUGIN_DATA` → リポジトリルート → ホーム）に保つ。一方だけを変更してはならない（`tests/test_resolve_base.py` の `BaseResolutionLockStepTests` が両実装の出力を突き合わせる）
- `<venv-base>` の解決も `routing/config_io.py` の `resolve_venv_base()`（`venv_lifecycle` は再エクスポート）と `commands/resolve_base.sh` の `skill_router_venv_base` で同一に保つ。**リポジトリ相対の階層を含めてはならない**（clone したリポジトリ同梱のインタプリタを実行しないための境界）
- venv のライフサイクル判断（構築・再構築上限・TTL 撤去・失敗バックオフ）は `routing/venv_lifecycle.py` に集約する。フックスクリプト側で個別に venv を作成・削除しない
- 実行時の venv 管理は `routing/venv_lifecycle.py` が正典であり、`setup/setup_venv.sh` は開発・テスト時に作業領域へ venv を用意するための補助スクリプトとして使い分ける
- `routing/embedding_*.py` は `routing/route.py` / `routing/build_index.py` のモジュール先頭で import しない。両者が持つ `_load_embedding_stack()` 経由の遅延ロードに限る（既定構成では 1 度も読み込まれないことを維持する）
- `routing/route.py` から `routing/build_index.py` を import しない。プロンプト経路が必要とするのは `config_io`（`<base>` 解決）と `text_tokens`（トークナイザ）だけであり、インデクサへの依存は遅延ロード制約をプロンプト経路の外へ広げる
- モデル ONNX のキャッシュ解決には `<venv-base>` を渡す（`embedding_client.get_model` の第 2 引数）。`<base>` を渡してはならない
- `<base>` 配下への書き込みは必ず `config_io.open_append()`（追記）または `config_io.open_write()`（切り詰め）を通す。素の `open()` はリンクを追従し、作成時のモード指定も効かない（`build_index` の `error.log` と `embedding_enrich.save_cache` が実際にこれで漏れていた）
- `additionalContext` に載せる `qualified_name` は `installed.is_installed()` で実インストールと照合してから出力する。index.json はリポジトリ相対の `<base>` から来うるため、自己申告の名前を信用しない
- Python スクリプトは先頭で `sys.stdout.reconfigure(encoding='utf-8')` を実施し、`open()` では `encoding='utf-8'` を明示する
- `routing/` を変更したら `tests/` の該当テストを更新する。`tests/` は標準ライブラリのみで完走できる状態を保つ
- venv ライフサイクルの手順順序は `prepare` サブコマンド内に閉じる。フックスクリプト側に順序制約を露出させない
- `python-bin` は副作用のない問い合わせとして保つ。最終利用時刻の更新は venv 内で実行されるプロセス（`route.py` / `build_index.py`）が `touch_last_used_if_active()` で行う

## テスト実行

リポジトリルートから venv 内 Python で実行する。

```bash
python -m unittest discover -s plugins/skill-router/references/scripts/tests -t plugins/skill-router/references/scripts/tests -p "test_*.py"
```

## 関連フォルダ

| フォルダ | 関係 |
|---------|------|
| `../templates/` | `config.default.json` が `routing/config_io.py` の既定値の出典 |
| `../research/` | 設計判断の裏付け記録（実行経路からは参照しない） |
