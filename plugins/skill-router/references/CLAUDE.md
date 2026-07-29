# references/ 読み込みガイド（プラグイン共通）

## 目的と範囲

`skill-router` プラグインのフック実装本体（`scripts/hooks/`）・ルーティングロジック（`scripts/routing/`）・コマンド実装（`scripts/commands/`）・venv 管理（`scripts/setup/`）・回帰テスト（`scripts/tests/`）・設計時調査記録（`research/`）・設定テンプレート（`templates/`）を格納する。

`skills/skill-router/SKILL.md` が担うのは利用者向けの操作・診断案内であり、本ディレクトリは **実行される実体** を担う。

## 原則

- **フェイルオープンを最優先する**。フック経路（`scripts/hooks/` と、そこから呼ばれる `scripts/routing/route.py` / `build_index.py`）はいかなる異常でも `exit 0` で透過し、ユーザのプロンプト送信・セッション開始を妨げない
- **時間予算を守る**。`UserPromptSubmit` は `hooks/hooks.json` の timeout 30 秒、`SessionStart` は 360 秒。プロンプト経路の平常値は約 0.6 秒（Windows 実測）であり、30 秒は異常時の上限であって運用値ではない。この幅は `embedding.enabled: true` の環境で `SessionStart` の依存インストール（最大 240 秒）とプロンプト送信が競合した場合を吸収するために取っている（競合下では index 構築が通常の約 60 倍に悪化した実測がある）。プロンプト経路に Python プロセス起動を追加する変更は 1 回あたり約 0.45 秒を消費する前提で判断し、起動は 1 回（`route.py`）に保つ
- **`<base>` / `<venv-base>` の解決順は 2 実装で同一に保つ**。Python 側は `scripts/routing/config_io.py` の `resolve_base_dir()` / `resolve_venv_base()`、Bash 側は `scripts/commands/resolve_base.sh` の `skill_router_base` / `skill_router_venv_base`。両者の差（リポジトリ層を含むか否か）がセキュリティ境界そのものであるため、2 つを別レイヤに分けず、片側だけを変更しない。`scripts/tests/test_resolve_base.py` の `BaseResolutionLockStepTests` が同一環境での出力を突き合わせて固定する
- **venv はリポジトリ配下に作らない**。配置先は `${CLAUDE_PLUGIN_DATA}`、無ければ `~/.claude/.local/plugins/skill-router/` の `.venv`（`<venv-base>`）。clone したリポジトリが同梱するインタプリタをフックが実行しないための境界であり、`<base>`（index / config / セッション）とは解決順が異なる
- **埋め込みモジュールはモジュール先頭で import しない**。`embedding_client` / `embedding_enrich` / `embedding_route` は `_load_embedding_stack()` による遅延ロードに限る。先頭に置くと numpy / fastembed の import 費用が既定構成（埋め込み無効）にも乗り、プロンプト経路ではソフト予算（1.5 秒）の判定が「費用を払い終えてから測る」ものになって無意味化する
- **プロンプト経路はインデクサに依存させない**。`route.py` が必要とするのは `<base>` 解決（`config_io`）とトークナイザ（`text_tokens`）だけであり、`build_index.py` を import してはならない
- **`<base>` 配下への書き込みは `config_io.open_append()` / `open_write()` に一本化する**。追記は前者、切り詰めを伴う書き込みは後者。箇所ごとに symlink ガードを手書きすると必ずどこかが抜ける（`build_index` の `error.log` と `embedding_enrich.save_cache` が実際に抜けていた）。リンク非追従（`drop_symlink` + `O_NOFOLLOW`）と作成時 0600 は両関数が担う。ディレクトリを丸ごとリンクにされる経路もあるため、書き込み先ディレクトリ自体の実体確認も行う
- **`additionalContext` に出す名前は実インストールと照合する**。`index.json` はリポジトリ相対の `<base>` から来うるため、`qualified_name` の自己申告を信用しない（文字種の制限だけではハイフン区切りの英文が通る）。照合は `installed.is_installed()` が行い、`install_path` はホーム所有の `installed_plugins.json` が **当該プラグインに対して** 記録した値と一致することを要求する。`skill_path` は `..` 成分を成分単位で拒否したうえで実パスへ解決して封じ込めを再確認する（`Path.relative_to` は `..` を正規化せず語彙的前方一致しかしないため、単独では検査にならない）
- **モデル ONNX のキャッシュは `<venv-base>` に置く**。ベクトル（`vectors.npz` / `manifest.json`）は `<base>` でよいが、onnxruntime が実行する `.onnx` はリポジトリ相対に解決されうる `<base>` から受け取らない
- **`prompts.jsonl` と `route_decisions.jsonl` は 1 行ずつ対応させる**。推奨に至らないターンも `tier: "skip"` で決定側に記録する。`skill-router` スキルの診断フロー（`SKILL.md` の「診断系」と eval `case-24` の Phase 7）は行の欠落をフックの打ち切りと判定するため、無記録にすると全て誤検知になる
- **venv を構築するのは `embedding.enabled: true` のときだけ**。ライフサイクル（構築・再構築上限・TTL 撤去・失敗バックオフ）は `scripts/routing/venv_lifecycle.py` が単独で所有する。TTL は `<venv-base>/.venv-last-used` の mtime（最終利用時刻）を基準とする
- **`python-bin` は副作用のない問い合わせとして保つ**。最終利用時刻の更新は venv 内で動くプロセス（`route.py` / `build_index.py`）が `touch_last_used_if_active()` で行う。フックの手順を並べ替えても TTL が壊れないようにするため
- **Python 実行時は UTF-8 を明示する**。スクリプト先頭で `sys.stdout.reconfigure(encoding='utf-8')`、`open()` では `encoding='utf-8'` を明示する
- **`scripts/routing/` を変更したら `scripts/tests/` の該当テストを更新する**。テストは標準ライブラリの `unittest` のみで動作し、`fastembed` 不在環境ではスキップされる設計を維持する
- **`research/` は履歴であり実行経路ではない**。フック・コマンドから参照してはならない
- 本ディレクトリのファイルを追加・改名した場合は、本ファイルのナビゲーション表と各サブフォルダの `CLAUDE.md` を同期する

## ナビゲーション（どの場面でどれを読むか）

| 場面 / タスク | 参照先 |
|-------------|-------|
| references 全体の構成・原則を確認する | 本ファイル（`CLAUDE.md`） |
| フックの実行順序・起動形態を確認する | `scripts/CLAUDE.md` → `scripts/hooks/build_index_on_start.sh` / `route_prompt.sh` |
| インデックス生成（走査対象・スキーマ）を確認する | `scripts/routing/build_index.py` の docstring |
| `<base>` / `<venv-base>` の解決順を確認する | `scripts/routing/config_io.py` の `resolve_base_dir()` / `resolve_venv_base()` と `scripts/commands/resolve_base.sh` |
| キーワード抽出（索引側と照合側で共有する規則）を確認する | `scripts/routing/text_tokens.py` の docstring |
| 出力する名前の実インストール照合を確認する | `scripts/routing/installed.py` の docstring |
| スコア計算・帯判定（high / mid / low）・`additionalContext` 生成を確認する | `scripts/routing/route.py` の docstring |
| 埋め込み判定（ベクトル化・キャッシュ・類似度加算）を確認する | `scripts/routing/embedding_client.py` / `embedding_enrich.py` / `embedding_route.py` の docstring |
| venv の構築・再構築上限・TTL 撤去の仕様を確認する | `scripts/routing/venv_lifecycle.py` の docstring と `scripts/setup/requirements.txt` のヘッダ |
| `config.json` の既定値・キー構成を確認する | `templates/CLAUDE.md` → `templates/config.default.json`（`<base>` 用）/ `templates/config.venv-base.default.json`（`<venv-base>` 用）|
| evals のパース仕様を確認する | `scripts/routing/parse_evals.py` の docstring |
| セッション履歴（`prompts.jsonl` / `route_decisions.jsonl`）の形式を確認する | `scripts/routing/session_state.py` の docstring |
| コマンド（`/router-toggle` 等）の実体を確認する | `scripts/CLAUDE.md` → `scripts/commands/` |
| 手動実行用のラッパー（タイムアウト付き・UTF-8 強制）を確認する | `scripts/CLAUDE.md` → `scripts/run/run_via_job.sh` |
| 変更後の回帰確認を行う | `scripts/CLAUDE.md` の「テスト実行」節 |
| 設計判断の経緯（session_id 解決・hook 連結・起動レイテンシ等）を調べる | `research/CLAUDE.md` |

## 禁止事項

- フック経路で例外を送出したまま終了すること（フェイルオープン違反）
- `scripts/routing/` のモジュールに、`<base>` 配下以外へ書き込む処理を追加すること
- `research/` 配下のスクリプトをフック・コマンド・テストから import すること
- `scripts/tests/` に標準ライブラリ以外への依存を必須として追加すること（`fastembed` 等はスキップ可能な任意依存として扱う）
- 本ファイルのナビゲーション表を更新せずに `references/` 配下のファイルを追加・改名すること
