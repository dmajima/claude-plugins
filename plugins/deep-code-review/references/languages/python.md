# Python レビュー観点プロファイル

Python コードの変更差分をレビューする際の言語固有観点。プロジェクト独自規約が存在する場合はそちらを優先する（`${CLAUDE_PLUGIN_ROOT}/references/conventions-resolution.md` の優先順位に従う）。

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

### 3.1 正確性・堅牢性【担当: implementation-engineer】

- [ ] **ミュータブルデフォルト引数**（`def f(x=[])` / `def f(x={})`）— 関数定義時に 1 度だけ評価され呼び出し間で共有される。`None` 番兵 + 関数内初期化にすべき
- [ ] コンテキストマネージャ（`with`）でファイル・ロック・DB 接続・ソケットを確実に解放しているか（手動 `open()` / `close()` の破棄漏れ・例外時リーク）
- [ ] **`open()` の `encoding` 未指定** — Windows 既定 cp932 で日本語が `UnicodeDecodeError` / 文字化け。`encoding="utf-8"` を明示（`subprocess.run` も同様）
- [ ] 辞書アクセスの `KeyError` 未対応（`d[key]` の存在前提 → `d.get(key)` / `setdefault` / `in` 判定）
- [ ] `None` 判定・同一性比較に `is` / `is not` を使用しているか（`== None` / 値比較への `is` 誤用）
- [ ] 金額・厳密計算に `float` を使っていないか（丸め誤差 → `decimal.Decimal`）
- [ ] 整数除算 `//` と真の除算 `/` の混同（Python 3 で `/` は常に `float` を返す）
- [ ] グローバル可変状態への依存（モジュールレベルの可変オブジェクト・`global` 書き換え → テスト困難・並行時レース）
- [ ] 循環 import（相互参照による `ImportError` / 部分初期化）— 依存方向の再設計・関数内遅延 import で解消
- [ ] イテレータ・ジェネレータの多重消費（一度消費した generator の再利用・`len()` 不可）

### 3.2 エラー処理・silent-failure【担当: implementation-engineer】

- [ ] **裸の except**（`except:`）— `KeyboardInterrupt` / `SystemExit` まで捕捉し中断不能・障害隠蔽
- [ ] **`except Exception: pass`**（例外の握りつぶし）— 障害が無言で消える
- [ ] catch して**ログのみ出力し、呼び出し元へ異常を伝えない**まま正常フローを継続していないか
- [ ] 広すぎる捕捉（`except Exception` で特定例外型に絞るべき箇所を一括処理）
- [ ] 例外の代わりに `None` / `-1` / 空文字を返して失敗を隠蔽していないか
- [ ] 再スロー時の原因連鎖（`raise NewError(...) from e`）を欠いていないか（トレースバック分断）
- [ ] `finally` 内の `return` / `break`（例外を無言で握りつぶす）
- [ ] `assert` を入力検証・業務ロジックに使用（`python -O` で無効化されるため本番の検証に使わない）
- [ ] 例外ログのスタックトレース欠落（`logger.error(str(e))` のみ → `logger.exception` / `exc_info=True` で原因を残す）

### 3.3 型・null 安全【担当: implementation-engineer】

- [ ] 公開 API のシグネチャに型ヒントが付与されているか（引数・戻り値の欠落）
- [ ] `Optional[T]` / `T | None` を返す関数の戻り値を None ガードなしで使用していないか（`AttributeError: 'NoneType'`）
- [ ] `Any` の乱用で型検査が実質無効化されていないか
- [ ] 型ヒントとデフォルト値・実装の不整合（`x: int = None`、`list` を返す注釈で `None` を返す等）
- [ ] プリミティブ執着（primitive obsession）: ドメイン概念が `str` / `dict` のまま引き回されていないか（`dataclass` / `Enum` / `NamedTuple` の検討）
- [ ] 可変オブジェクトの共有（引数で受けた `list` / `dict` を破壊的に変更して呼び出し元へ影響していないか）
- [ ] `# type: ignore` / `cast()` による型検査の抑制が正当か（根本原因の回避になっていないか）
- [ ] 前方参照・循環回避のための `from __future__ import annotations` / `if TYPE_CHECKING:` の適切な運用（実行時に評価されない注釈への依存に注意）

### 3.4 非同期・並行処理【担当: implementation-engineer / performance-reviewer】

- [ ] **`async def` 内での同期ブロッキング呼び出し**（`time.sleep` / `requests` / 同期 DB ドライバ / ブロッキング I/O）→ イベントループ全体を停止。`await asyncio.sleep` / `httpx.AsyncClient` / 非同期ドライバへ
- [ ] **await されていないコルーチン**（`coro()` を呼んだだけで `await` していない → 実行されず `RuntimeWarning` のみ）
- [ ] `asyncio.create_task` の戻り値を保持せず GC される（fire-and-forget が意図的か・例外が失われないか）
- [ ] CPU バウンド処理を `async` / 単一スレッドで実行（`run_in_executor` / `ProcessPoolExecutor` の要否。GIL の影響）
- [ ] スレッド共有状態への未保護アクセス（`threading.Lock` / `queue.Queue` の要否。GIL に依存した暗黙の安全性）
- [ ] `asyncio.gather` での例外伝搬（`return_exceptions` の扱い・片方失敗時の残タスク挙動）
- [ ] `async` 関数内でのブロッキングファイル I/O（同期 `open()` / `read()` → `aiofiles` 等の非同期 I/O を検討）

### 3.5 命名・スタイル【担当: implementation-engineer / linter-static-analysis】

- [ ] 命名規則: クラス/例外 = PascalCase（例外は `Error` サフィックス）、関数/変数/メソッド = snake_case、定数 = UPPER_SNAKE_CASE、非公開 = `_leading_underscore`、モジュール/パッケージ = 短い全小文字
- [ ] import: 1 行 1 モジュール、標準ライブラリ → サードパーティ → ローカルの 3 グループ分け、ワイルドカード import（`from x import *`）の回避
- [ ] インデント = スペース 4（タブ混在なし）、行長は `pyproject.toml` 設定（既定 88）に従う
- [ ] docstring: 公開モジュール・クラス・関数に三重ダブルクォート `"""..."""`、1 行目は要約行（PEP 257）
- [ ] f-string を優先（`%` / `str.format()` の新規多用は避ける。既存コードのスタイルを尊重）

### 3.6 パフォーマンス【担当: performance-reviewer】

- [ ] ループ内での文字列連結（`+=` の反復 → `"".join(...)` / リスト蓄積後に結合）
- [ ] ループ内での同期 I/O・DB 呼び出し（N+1。ORM は frameworks/orm.md 参照）
- [ ] 大量データの全件メモリ展開（`list(...)` / `.readlines()` → ジェネレータ・`yield` によるストリーミング）
- [ ] 内包表記 vs ループ vs `map`/`filter` の適切さ（単純変換は内包表記、副作用を伴う反復は通常の for）
- [ ] 不要な中間リスト生成（`sum([...])` → `sum(...)`、即時消費される `list(comprehension)`）
- [ ] 高頻度パスでのメンバーシップ判定に `list` を使用（`in list` は O(n) → `set` / `dict` の O(1)）
- [ ] ホットループ内でのグローバル・属性参照の反復解決（ループ外でのローカル束縛による削減余地）
- [ ] 不要な `copy.deepcopy` / 大きなオブジェクトの防御的コピー
- [ ] `pandas` / `numpy` での行単位 `apply` / `iterrows`（ベクトル化の検討）

### 3.7 セキュリティ【担当: security-engineer】

> **埋め込み SQL の横断適用**: `cursor.execute(...)` / `pyodbc` / `sqlite3` / SQLAlchemy の `text()` 等でコードに埋め込まれた SQL 文字列には、インジェクション以外にも `${CLAUDE_PLUGIN_ROOT}/references/languages/sql.md` の観点（`SELECT *`・列非明示・NULL 三値論理・方言固有）を併用適用する（`.sql` ファイルが差分に無くても適用。language-detection.md Step 4）。

- [ ] **SQL 文字列組み立て**（f-string / `%` / `.format()` / `+` 連結でユーザー入力を SQL に埋め込み → SQL インジェクション。パラメタライズドクエリ / ORM へ）
- [ ] **`eval` / `exec` / `compile`** へのユーザー入力受け渡し（任意コード実行）
- [ ] **`pickle.loads` / `yaml.load`（Loader 未指定）/ `marshal`** で信頼できないデータをデシリアライズ（`yaml.safe_load` へ）
- [ ] **`subprocess` の `shell=True`** + ユーザー入力（コマンドインジェクション → 引数配列 + `shell=False`）
- [ ] パス結合の検証漏れ（`os.path.join` / `Path` + ユーザー入力 → path traversal。`tarfile.extractall` の zip/tar 展開先検証）
- [ ] 乱数の用途（トークン・パスワード・秘密鍵に `random` → `secrets` モジュール）
- [ ] 機密情報（API キー・接続文字列・パスワード）のハードコード・ログ出力
- [ ] `requests` / TLS での `verify=False`（証明書検証の無効化）
- [ ] XML パース（`xml.etree` / `lxml`）での外部エンティティ・DTD 展開（XXE → `defusedxml`）
- [ ] 一時ファイルの安全な生成（`tempfile.mktemp` の TOCTOU レース → `NamedTemporaryFile` / `mkstemp`）
- [ ] Web フレームワークの `debug` 有効化・ハードコード `SECRET_KEY` の本番残留（詳細は frameworks/python-web.md 参照）

### 3.8 コメント・ドキュメント整合【担当: implementation-engineer】

- [ ] docstring の記述（引数・戻り値・例外・型）とシグネチャ・実装の不一致
- [ ] 型ヒントと docstring の型記述の乖離
- [ ] コメントの記述とコードの実挙動の乖離（変更差分でコードだけ変わりコメントが古いまま）
- [ ] コメントアウトされたコード・デバッグ用 `print` の残留
- [ ] `# TODO` / `# FIXME` と実装状況の乖離（対応済みなのに残留・未対応のまま放置）

## 4. 典型的な指摘パターン（重要度の目安）

| パターン | 重要度の目安 | 根拠 |
|---------|------------|------|
| SQL 文字列組み立て（f-string/format でユーザー入力） | Critical | SQL インジェクション |
| `eval` / `exec` / `pickle.loads` に信頼できない入力 | Critical | 任意コード実行 |
| `subprocess(shell=True)` + ユーザー入力 | Critical | コマンドインジェクション |
| `async def` 内の同期ブロッキング呼び出し | High | イベントループ全停止 |
| 裸の except / `except Exception: pass` | High | 障害の無言化・調査不能化 |
| None ガード漏れ（Optional 戻り値の未処理） | High | AttributeError で機能停止 |
| ミュータブルデフォルト引数 | High〜Medium | 状態リーク（発現が非直感的でデバッグ困難） |
| await 漏れ（コルーチン未実行） | High〜Medium | 処理が実行されない・例外消失 |
| `open()` の encoding 未指定 | Medium〜High | Windows(cp932) で文字化け・UnicodeDecodeError |
| DB 接続・カーソル・ファイルの未クローズ（`with` 不使用） | Medium | リソースリーク（接続枯渇・ハンドル枯渇） |
| ループ内同期 I/O・文字列連結 | Medium〜High | 性能劣化（データ量依存） |
| `random` をトークン生成に使用 | Medium〜High | 予測可能性（用途依存） |
| KeyError 未対応（辞書の直接アクセス） | Medium | 実行時例外 |
| PEP 8 命名違反・import 順序 | Medium〜Low | 可読性・規約整合（ruff で機械検出可） |
| f-string 未使用・内包表記の可否 | Low | 任意改善（既存スタイルとの整合を優先） |

### NG / OK 例（silent-failure）

```python
# NG: 裸の except で例外を握りつぶし、失敗を None で隠蔽
def get_order(order_id: int) -> Order | None:
    try:
        return repo.find(order_id)
    except:              # KeyboardInterrupt まで飲み込む
        return None      # 障害が無言で消える

# OK: 捕捉する例外型を絞り、原因連鎖を付けて再スロー
def get_order(order_id: int) -> Order:
    try:
        return repo.find(order_id)
    except DatabaseError as e:
        raise OrderRetrievalError(f"注文 {order_id} の取得に失敗") from e
```

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
