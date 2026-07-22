# Python 言語プロファイル

## 1. 識別（プロジェクト検出）

| 項目 | 値 |
|------|-----|
| 対象拡張子 | `.py`, `.pyi`（型スタブ） |
| マーカーファイル | `pyproject.toml` / `requirements.txt` / `setup.py` / `setup.cfg` / `Pipfile` / `poetry.lock`（プロジェクトルートでの検出対象） |

- マーカーファイルの依存定義（`pyproject.toml` の `[project.dependencies]` / `requirements.txt` 等）に `flask` / `django` / `fastapi` が含まれる場合は [frameworks/python-web.md](frameworks/python-web.md) を併用する。
- 検出優先順位は [skill-index.md](../../../references/skill-index.md) の「検出優先順位」に従う。

## 2. デファクトスタンダード規約

**準拠規約**: PEP 8 -- Style Guide for Python Code（https://peps.python.org/pep-0008/）
docstring は PEP 257 -- Docstring Conventions（https://peps.python.org/pep-0257/）、型ヒントは PEP 484 -- Type Hints（https://peps.python.org/pep-0484/）に準拠する。

### 2.1 命名規則

出典: PEP 8「Naming Conventions」（https://peps.python.org/pep-0008/#naming-conventions）

| 対象 | 規則 | 例 |
|------|------|-----|
| クラス/型 | CapWords（PascalCase） | `OrderService`, `HttpClient` |
| 例外 | CapWords + `Error` サフィックス | `ValidationError`, `TimeoutError` |
| 関数/メソッド | snake_case | `get_user`, `calculate_total` |
| 変数 | snake_case | `user_name`, `item_count` |
| 定数 | UPPER_SNAKE_CASE | `MAX_RETRIES`, `DEFAULT_TIMEOUT` |
| モジュール | 短い全小文字（必要時アンダースコア） | `user_service.py` |
| パッケージ | 短い全小文字（アンダースコアは非推奨） | `mypackage` |
| 非公開（モジュール/クラス内） | 先頭に単一アンダースコア | `_internal_helper`, `_cache` |
| 名前マングリング（サブクラス衝突回避） | 先頭に二重アンダースコア | `__private` |
| 型変数（TypeVar） | CapWords（短い名前推奨） | `T`, `KT`, `VT` |

### 2.2 インデント・フォーマット

| 項目 | 規定 |
|------|------|
| インデント | スペース 4 個（タブとの混在禁止。スペースを推奨） -- PEP 8「Indentation」 |
| 行長目安 | PEP 8 は最大 **79 文字**（docstring/コメントは 72 文字）。近年のツール既定は **88 文字**（Black / Ruff format のデフォルト） |
| 文字列引用符 | PEP 8 は単一/二重どちらでもよいが一貫性を求める。Black/Ruff format は **二重引用符** に正規化する |
| 末尾セミコロン | 使用しない（1 行 1 文。複数文を `;` で連結しない） |
| 空行 | トップレベルの関数・クラス定義の前後に空行 2 行、クラス内メソッド間は空行 1 行 -- PEP 8「Blank Lines」 |

行長についての補足: PEP 8 本文（[#maximum-line-length](https://peps.python.org/pep-0008/#maximum-line-length)）は 79 文字を規定し、チーム合意により最大 99 文字まで許容してよい。Black・Ruff formatter は既定 88 文字（詳細は下記「ツールチェーン」）。プロジェクトに `pyproject.toml` の `line-length` 設定があればそれを最優先する。

### 2.3 主要スタイル規則

（PEP 8 のうち、コード生成時に判断へ影響する主要規則）

- **import**: 1 行 1 モジュール。ファイル冒頭にまとめ、次の 3 グループに分け各グループ間を空行 1 行で区切る -- 標準ライブラリ → サードパーティ → ローカル（自プロジェクト）。相対 import よりも絶対 import を推奨（https://peps.python.org/pep-0008/#imports ）。
- **docstring**: 三重ダブルクォート `"""..."""` を使う。モジュール・公開クラス・公開関数/メソッドに記述し、1 行目は要約行とする（PEP 257）。
- **型ヒント**: 公開 API のシグネチャに付与する。注釈のコロンは変数直後（`x: int`）、デフォルト値を伴う注釈付き引数は `=` の前後に空白を置く（`def f(x: int = 0)`）。注釈が無い引数のデフォルトは空白なし（`def f(x=0)`）(https://peps.python.org/pep-0008/#other-recommendations )。
- **空白**: 二項演算子・カンマの後にスペース、括弧やインデックスの内側にはスペースを入れない（`f(x[1], y)`）。
- **比較**: `None` との比較は `is` / `is not` を用いる（`if x is None`）。真偽判定は `if not seq`（空シーケンス）等を用い、`== None` や `== True` は使わない。
- **例外処理**: `except:`（裸の except）を避け、捕捉する例外型を明示する。

## 3. ツールチェーン

| 用途 | コマンド | 備考 |
|------|---------|------|
| 仮想環境作成 | `python -m venv .venv` | 標準ライブラリ venv（https://docs.python.org/3/library/venv.html ）。**venv 内での実行を推奨**（後述） |
| 依存インストール | `pip install -r requirements.txt` | venv 有効化後に実行 |
| テスト | `pytest` | https://docs.pytest.org/ |
| Lint | `ruff check .` | 近年のデファクト（高速リンター、https://docs.astral.sh/ruff/ ）。従来は `flake8` / `pylint` |
| フォーマット | `ruff format .` または `black .` | いずれも既定 88 文字・二重引用符。Ruff format は Black 互換（https://docs.astral.sh/ruff/formatter/ ） |
| 型チェック | `mypy .` | PEP 484 準拠の静的型検査（https://mypy.readthedocs.io/ ） |

補足: Ruff は `ruff check`（旧 flake8/isort/pyupgrade 等を統合）と `ruff format`（Black 互換）で構成される。import 並び替えは Ruff の `I` ルール（isort 互換）または `isort` 単体で行える。

### プロジェクト規約ファイル（存在時は本プロファイルより優先）

| ファイル | 内容 |
|---------|------|
| `pyproject.toml` | ビルド設定・プロジェクトメタデータ（PEP 518 / PEP 621）。`[tool.ruff]` / `[tool.black]` / `[tool.mypy]` にフォーマッタ・リンター・型チェッカ設定を記載 |
| `setup.cfg` | `pyproject.toml` 移行前のプロジェクトで flake8 / mypy 等の設定を保持 |
| `.editorconfig` | インデント・改行コード・文字コード |
| `requirements.txt` / `Pipfile` / `poetry.lock` | 依存定義（バージョン固定の実体） |
| `.python-version` | pyenv 等が参照する対象 Python バージョン |

出典: PEP 518（https://peps.python.org/pep-0518/ ）、PEP 621（https://peps.python.org/pep-0621/ ）。

## 4. イディオム・ベストプラクティス

- **内包表記**（list/dict/set comprehension）を単純な `map`/`filter` + ループの代替として使う。ネストが深く可読性を損なう場合は通常の for に戻す。
- **コンテキストマネージャ**（`with`）でファイル・ロック・DB 接続などのリソースを確実に解放する。
- **型ヒント**（PEP 484）を公開関数のシグネチャに付与し、`mypy` で検証する。`Optional[T]` / `T | None`（Python 3.10+）で None 許容を明示する。
- **f-string**（Python 3.6+）で文字列整形する（`%` 演算子・`str.format()` より可読性が高い）。
- **EAFP**（Easier to Ask for Forgiveness than Permission）: 事前チェック（LBYL）より `try/except` を優先する Python らしいスタイル。
- **dataclass**（`from dataclasses import dataclass`、https://docs.python.org/3/library/dataclasses.html ）で値オブジェクトの定型コード（`__init__` / `__repr__` / `__eq__`）を削減する。
- **pathlib.Path** をパス操作に用いる（`os.path` の文字列結合より安全）。
- **enumerate() / zip()** を range インデックスループの代わりに使う。
- ミュータブルなデフォルト引数を使わない（`def f(x=[])` はアンチパターン。`def f(x=None)` として関数内で初期化する）。

## 5. 典型エラーパターンと対処

| エラー | 原因 | 対処 |
|-------|------|------|
| `ModuleNotFoundError` | venv 未有効化 / 依存未インストール / import パスの誤り | venv を有効化して `pip install`。パッケージ名・相対 import・`PYTHONPATH` を確認 |
| `IndentationError` / `TabError` | インデントのスペース・タブ混在、レベル不整合 | 4 スペースに統一（`ruff format` / `black` で自動修正） |
| `UnicodeEncodeError` / `UnicodeDecodeError` | Windows の既定エンコーディング **cp932** でのファイル入出力・`print` | `open(..., encoding='utf-8')` を明示（後述の必須ルール）。環境変数 `PYTHONUTF8=1` の設定も併用 |
| `ImportError`（circular import） | モジュール間の循環参照 | import を関数内へ遅延させる / 依存方向を再設計する |
| `TypeError: 'NoneType' object ...` | `None` を返す関数の戻り値を未チェックで使用 | 型ヒント + `mypy`、`Optional` の明示と早期 return |
| `AttributeError` | 属性名の誤り / 期待と異なる型のオブジェクト | 型ヒントで対象型を明確化、`hasattr` ではなく型設計で回避 |

### Windows 環境の注意

- `open()` でファイルを読み書きする際は **必ず `encoding='utf-8'` を明示** する。Windows の既定エンコーディングは cp932 のため、明示しないと日本語で `UnicodeEncodeError` / 文字化けが発生する。

  ```python
  # 推奨
  with open(filepath, "r", encoding="utf-8") as f:
      data = f.read()

  # 禁止（環境依存で cp932 になり文字化けする）
  with open(filepath) as f:
      data = f.read()
  ```

- Python は **venv 内で実行** する（システム/グローバル環境への直接インストールを避ける。プロジェクトのポリシーがある場合はそれに従う）。`subprocess.run(...)` で外部コマンドを呼ぶ場合も `encoding="utf-8"` / `errors="replace"` を明示する。

## 6. フレームワーク

| フレームワーク | プロファイル |
|--------------|-------------|
| Flask（flask-restx / Flask-JWT-Extended 含む） | [frameworks/python-web.md](frameworks/python-web.md) |
| Django | [frameworks/python-web.md](frameworks/python-web.md) |
| FastAPI | [frameworks/python-web.md](frameworks/python-web.md) |
