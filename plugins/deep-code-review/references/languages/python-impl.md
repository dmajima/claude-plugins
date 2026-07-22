# Python レビュー観点プロファイル — impl details

`python.md`（hub）から分離した観点本文。hub の 3.x スタブから該当観点が参照する。
共通前提（節1 識別・節2 準拠規約）・節4 重要度表・節5 FW・節6 動的検証コマンドは `python.md`（hub）に残置。
本ファイルは観点 3.1 3.2 3.3 3.4 3.5 3.6 3.8 を収録。

### 3.1 正確性・堅牢性【担当: implementation-engineer】

- [ ] **ミュータブルデフォルト引数**（`def f(x=[])` / `def f(x={})`）— 関数定義時に 1 度だけ評価され呼び出し間で共有される。`None` 番兵 + 関数内初期化にすべき
- [ ] コンテキストマネージャ（`with`）でのファイル・ロック・DB 接続・ソケットの解放（手動 `open()` / `close()` の破棄漏れ・例外時リーク）
- [ ] **`open()` の `encoding` 未指定** — Windows 既定 cp932 で日本語が `UnicodeDecodeError` / 文字化け。`encoding="utf-8"` を明示（`subprocess.run` も同様）
- [ ] 辞書アクセスの `KeyError` 未対応（`d[key]` の存在前提 → `d.get(key)` / `setdefault` / `in` 判定）
- [ ] `None` 判定・同一性比較に `is` / `is not` を使用しているか（`== None` / 値比較への `is` 誤用）
- [ ] 金額・厳密計算での `float` 使用（丸め誤差 → `decimal.Decimal`）
- [ ] 整数除算 `//` と真の除算 `/` の混同（Python 3 で `/` は常に `float` を返す）
- [ ] グローバル可変状態への依存（モジュールレベルの可変オブジェクト・`global` 書き換え → テスト困難・並行時レース）
- [ ] 循環 import（相互参照による `ImportError` / 部分初期化）— 依存方向の再設計・関数内遅延 import で解消
- [ ] イテレータ・ジェネレータの多重消費（一度消費した generator の再利用・`len()` 不可）

### 3.2 エラー処理・silent-failure【担当: implementation-engineer】

- [ ] **裸の except**（`except:`）— `KeyboardInterrupt` / `SystemExit` まで捕捉し中断不能・障害隠蔽
- [ ] **`except Exception: pass`**（例外の握りつぶし）— 障害が無言で消える
- [ ] catch して**ログのみ出力し、呼び出し元へ異常を伝えない**まま正常フローを継続
- [ ] 広すぎる捕捉（`except Exception` で特定例外型に絞るべき箇所を一括処理）
- [ ] 例外の代わりに `None` / `-1` / 空文字を返す失敗隠蔽
- [ ] 再スロー時の原因連鎖（`raise NewError(...) from e`）の欠落（トレースバック分断）
- [ ] `finally` 内の `return` / `break`（例外を無言で握りつぶす）
- [ ] `assert` を入力検証・業務ロジックに使用（`python -O` で無効化されるため本番の検証に使わない）
- [ ] 例外ログのスタックトレース欠落（`logger.error(str(e))` のみ → `logger.exception` / `exc_info=True` で原因を残す）

### 3.3 型・null 安全【担当: implementation-engineer】

- [ ] 公開 API のシグネチャの型ヒント欠落（引数・戻り値）
- [ ] `Optional[T]` / `T | None` を返す関数の戻り値を None ガードなしで使用（`AttributeError: 'NoneType'`）
- [ ] None を取り得る**引数・外部入力**（既定値 `None`・API/設定由来の値）を None ガードなしで演算・属性参照に使用（数値演算の `TypeError` / `AttributeError`）
- [ ] `Any` の乱用による型検査の実質無効化
- [ ] 型ヒントとデフォルト値・実装の不整合（`x: int = None`、`list` を返す注釈で `None` を返す等）
- [ ] プリミティブ執着（primitive obsession）: ドメイン概念を `str` / `dict` のまま引き回し（`dataclass` / `Enum` / `NamedTuple` の検討）
- [ ] 可変オブジェクトの共有（引数で受けた `list` / `dict` を破壊的に変更し呼び出し元へ影響）
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

### 3.8 コメント・ドキュメント整合【担当: implementation-engineer】

- [ ] docstring の記述（引数・戻り値・例外・型）とシグネチャ・実装の不一致
- [ ] 型ヒントと docstring の型記述の乖離
- [ ] コメントの記述とコードの実挙動の乖離（変更差分でコードだけ変わりコメントが古いまま）
- [ ] コメントアウトされたコード・デバッグ用 `print` の残留
- [ ] `# TODO` / `# FIXME` と実装状況の乖離（対応済みなのに残留・未対応のまま放置）

