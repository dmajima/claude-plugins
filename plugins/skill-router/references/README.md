# プラグイン共通 references（人間向けインデックス）

`skill-router` プラグインの実行コード・調査記録・設定テンプレートを格納するディレクトリです。

本ファイルは **人間（利用者・開発者）向けのリファレンス** であり、Claude のスキル動作では参照されません。スキル動作時のナビゲーションには `references/CLAUDE.md` が使われます。

## ディレクトリ構成

| パス | 内容 |
|-----|------|
| `CLAUDE.md` | Claude エージェント向けのナビゲーション・原則（AI が最初に読む） |
| `scripts/hooks/` | `SessionStart` / `UserPromptSubmit` フックのエントリポイント（Bash） |
| `scripts/routing/` | インデックス生成・スコアリング・埋め込み・セッション状態・venv ライフサイクルの実装（Python） |
| `scripts/commands/` | スラッシュコマンド（`/router-toggle` 等）の実体と `<base>` 解決の Bash 実装 |
| `scripts/setup/` | 開発・テスト用の venv 構築・撤去スクリプトと依存定義（`requirements.txt`） |
| `scripts/run/` | 手動実行用のラッパー（タイムアウト付き・UTF-8 強制）。フック経路は経由しません |
| `scripts/tests/` | 標準ライブラリ `unittest` による回帰テスト |
| `research/` | 設計時に Claude Code の実挙動を実測した調査スクリプト（手動実行用） |
| `templates/` | `config.json` の既定値テンプレート |

各サブディレクトリの詳細なファイル一覧は、それぞれの `CLAUDE.md` に記載しています。

## 開発時の要点

- フック経路はフェイルオープンです。異常時も `exit 0` で透過し、プロンプト送信やセッション開始を妨げません
- `<base>` の解決順（`CLAUDE_PLUGIN_DATA` → リポジトリルート → ホーム）は Python 版（`scripts/routing/config_io.py`）と Bash 版（`scripts/commands/resolve_base.sh`）の 2 実装があります。片方だけを変更すると解決結果が食い違うため、`scripts/tests/test_resolve_base.py` が同一環境での出力を突き合わせています
- 実行時の venv は `scripts/routing/venv_lifecycle.py` が `<venv-base>/.venv` に管理します。`<venv-base>` は `${CLAUDE_PLUGIN_DATA}`、無ければホーム配下で、**リポジトリ配下は使いません**（clone したリポジトリが同梱するインタプリタをフックが実行しないための境界）。index / config / セッションを置く `<base>` はリポジトリ相対を含むため、両者は解決順が異なります
- `scripts/setup/setup_venv.sh` は開発・テスト時に作業領域へ venv を用意するための補助スクリプトで、実行時の venv 管理とは役割が異なります
- 埋め込み機能（`fastembed`）は既定で無効です。テストは `fastembed` 不在環境でもスキップにより完走します

## テストの実行方法

リポジトリルートから次を実行します。

```bash
python -m unittest discover -s plugins/skill-router/references/scripts/tests -t plugins/skill-router/references/scripts/tests -p "test_*.py"
```

## 編集時の注意

- ファイルを追加・改名した場合は、本ファイルと該当ディレクトリの `CLAUDE.md` のファイル一覧を更新してください
- `scripts/routing/` を変更した場合は `scripts/tests/` の該当テストも更新してください
- `research/` は調査記録です。実行経路（フック・コマンド・テスト）から参照しないでください
