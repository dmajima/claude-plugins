# Python レビュー観点プロファイル

Python コードの差分をレビューする際の言語固有観点。プロジェクト独自規約が存在する場合はそちらを優先（`${CLAUDE_PLUGIN_ROOT}/references/conventions-resolution.md` の優先順位に従う）。

## 1. 識別

| 項目 | 値 |
|------|-----|
| 対象拡張子 | `.py` / `.pyi`（型スタブ） |
| マーカーファイル | `pyproject.toml` / `requirements.txt` / `setup.py` / `setup.cfg` / `Pipfile` / `poetry.lock` |
| 世代判別 | `pyproject.toml` の `requires-python` / `.python-version` で対象バージョンを確認（`X \| None` 記法・`match` 文は 3.10+、`tomllib` は 3.11+） |

## 2. 準拠規約（プロジェクト規約が無い場合のデフォルト基準）

- PEP 8 -- Style Guide for Python Code
- PEP 257 -- Docstring Conventions（docstring 規約）
- PEP 484 -- Type Hints（型ヒント）
- 行長・引用符は `pyproject.toml` の `[tool.ruff]` / `[tool.black]` の `line-length` を最優先（既定 88 文字・二重引用符）

## 3. レビュー観点

> 3.x 本文は観点別 details に分離済み。**各 3.x の【担当】に対応する details のみ Read** すること（重要度表(節4)・動的検証(節6)は本 hub に残置）:
> - [`python-impl.md`](python-impl.md) … 3.1 3.2 3.3 3.4 3.5 3.6 3.8
> - [`python-security.md`](python-security.md) … 3.7

### 3.1 正確性・堅牢性【担当: implementation-engineer】

> → 本文は [`python-impl.md`](python-impl.md)（3.1）

### 3.2 エラー処理・silent-failure【担当: implementation-engineer】

> → 本文は [`python-impl.md`](python-impl.md)（3.2）

### 3.3 型・null 安全【担当: implementation-engineer】

> → 本文は [`python-impl.md`](python-impl.md)（3.3）

### 3.4 非同期・並行処理【担当: implementation-engineer / performance-reviewer】

> → 本文は [`python-impl.md`](python-impl.md)（3.4）

### 3.5 命名・スタイル【担当: implementation-engineer / linter-static-analysis】

> → 本文は [`python-impl.md`](python-impl.md)（3.5）

### 3.6 パフォーマンス【担当: performance-reviewer】

> → 本文は [`python-impl.md`](python-impl.md)（3.6）

### 3.7 セキュリティ【担当: security-engineer】

> → 本文は [`python-security.md`](python-security.md)（3.7）

### 3.8 コメント・ドキュメント整合【担当: implementation-engineer】

> → 本文は [`python-impl.md`](python-impl.md)（3.8）

## 4. 典型的な指摘パターン（重要度の目安）

| パターン | 重要度の目安 | 根拠 |
|---------|------------|------|
| SQL 文字列組み立て（f-string/format でユーザー入力） | Critical | SQL インジェクション |
| `eval` / `exec` / `pickle.loads` に信頼できない入力 | Critical | 任意コード実行 |
| `subprocess(shell=True)` + ユーザー入力 | Critical | コマンドインジェクション |
| `async def` 内の同期ブロッキング呼び出し | High | イベントループ全停止 |
| 裸の except / `except Exception: pass` | High | 障害の無言化・調査不能化 |
| None ガード漏れ（Optional 戻り値・None を取り得る引数の未処理） | High | AttributeError / TypeError で機能停止 |
| ミュータブルデフォルト引数 | High〜Medium | 状態リーク（発現が非直感的でデバッグ困難） |
| await 漏れ（コルーチン未実行） | High〜Medium | 処理が実行されない・例外消失 |
| `open()` の encoding 未指定 | Medium〜High | Windows(cp932) で文字化け・UnicodeDecodeError |
| DB 接続・カーソル・ファイルの未クローズ（`with` 不使用） | Medium | リソースリーク（接続枯渇・ハンドル枯渇） |
| ループ内同期 I/O・文字列連結 | Medium〜High | 性能劣化（データ量依存） |
| `random` をトークン生成に使用 | Medium〜High | 予測可能性（用途依存） |
| KeyError 未対応（辞書の直接アクセス） | Medium | 実行時例外 |
| PEP 8 命名違反・import 順序 | Medium〜Low | 可読性・規約整合（ruff で機械検出可） |
| f-string 未使用・内包表記の可否 | Low | 任意改善（既存スタイルとの整合を優先） |

## 5. フレームワーク観点

差分に以下の FW が関与する場合、該当プロファイルを併読する:

| 検出条件 | プロファイル |
|---------|-------------|
| `flask` / `django` / `fastapi`（依存定義・import） | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/python-web.md` |
| `sqlalchemy` / `alembic`（ORM 横断観点） | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/orm.md` |

## 6. 動的検証コマンド【担当: linter-static-analysis / test-runner】

対応する Bash 権限が許可されている場合のみ実行（なければ SKIPPED 記録）。venv が存在する場合はその Python を優先する:

| 検証 | コマンド | 判定 |
|------|---------|------|
| 構文チェック | `python -m py_compile <対象.py>` | エラー = 強制 FAIL（Critical〜High） |
| Lint | `ruff check .` | 違反内容に応じて High〜Low |
| フォーマット | `ruff format --check .`（または `black --check .`） | 差分あり = Medium |
| 型チェック | `mypy .` | エラー内容に応じて High〜Medium |
| テスト | `pytest` | 失敗 1 件ごとに最低 High |
