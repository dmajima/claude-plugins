# templates/ 利用ガイド

## 目的

`<base>/config.json` の初期値テンプレートを保持する。利用者環境に `config.json` が存在しない場合の既定値の出典であり、重み・閾値・候補絞込・トークナイザの初期定義（`<base>` 用）と、venv TTL・埋め込み設定の初期定義（`<venv-base>` 用）を、所有者ごとに別ファイルで保持する。

## ファイル一覧

| ファイル | 配置先（利用者環境） | 説明 |
|---------|-------------------|------|
| `config.venv-base.default.json` | `<venv-base>/config.json` | `venv.ttl_hours` / `embedding` の全キーと既定値。依存導入を誘発する設定はこちらが所有する |
| `config.default.json` | `<base>/config.json` | `schema_version` / `weights` / `thresholds` / `candidate_filter` / `tokenizer` の全キーと既定値 |

## 配置先の解決順

2 つのテンプレートは **別ファイルへ** 配置する。同じ `config.json` という名前だが、解決順が異なるため同一ディレクトリになるとは限らない。

| 記号 | 解決順 |
|------|-------|
| `<base>` | `${CLAUDE_PLUGIN_DATA}` → リポジトリルート `/.claude/.local/plugins/skill-router/` → `~/.claude/.local/plugins/skill-router/` |
| `<venv-base>` | `${CLAUDE_PLUGIN_DATA}` → `~/.claude/.local/plugins/skill-router/`（**リポジトリ相対の階層を持たない**） |

- `<base>/config.json` は不在時に `route.py` が `config.default.json` 相当の内容で自動生成する
- `<venv-base>/config.json` は **自動生成しない**。埋め込みを有効化する利用者が、`config.venv-base.default.json` をコピーして `embedding.enabled` を `true` にする。自動生成すると、依存導入のスイッチをプラグイン側が勝手に配ることになる
- `${CLAUDE_PLUGIN_DATA}` が設定された環境では両者が同一ディレクトリに解決される。その場合は 1 つの `config.json` に両テンプレートのキーをマージして配置する

## 利用ルール

- `<base>` 用の既定値は `config.default.json` と `../scripts/routing/route.py` の `DEFAULT_CONFIG` の **2 箇所** に存在する。テンプレートは利用者へ配る初期値、`DEFAULT_CONFIG` は `config.json` 不在時のフェイルオープン経路で使う値であり、どちらも必要。`../scripts/tests/test_route.py` の `DefaultConfigTemplateTests` が両者の一致を固定するため、**必ず同時に更新する**（片方だけの変更は不可）
- `<venv-base>` 用（`config.venv-base.default.json`）にはコード側の複製が無い。値は `venv_lifecycle` / `embedding_client` の既定引数が持つため、変更時は該当モジュールと突き合わせる
- 上記 2 箇所以外に既定値をリテラルで複製しない
- **テンプレートに置くキーは、実装のどこかが必ず読むこと**。読まれないキーを配ると、利用者は自分の `config.json` にそれを見つけて編集し、何も起きない（`tokenizer` ブロックが実際にそうなっていたため schema_version 3 で削除した）
- キーを追加・削除・改名した場合は `schema_version` の更新要否を判断し、`../scripts/routing/config_io.py` の読み込み処理と `../scripts/tests/` の該当テストを同時に更新する
- 本ファイルは **テンプレート** であり、利用者の `<base>/config.json` を上書きする処理を追加してはならない（`/router-rebuild` 等のコマンドから既存設定を破壊しない）
- 埋め込み設定（`embedding`）の既定は無効（`enabled: false`）を維持する。有効化は利用者のオプトインに限る

## 関連フォルダ

| フォルダ | 関係 |
|---------|------|
| `../scripts/routing/` | `config_io.py` が本テンプレートの値を読み込み、`route.py` / `build_index.py` へ供給する |
