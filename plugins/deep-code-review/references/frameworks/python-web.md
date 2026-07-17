# Python Web フレームワーク レビュー観点プロファイル

Python Web フレームワーク（Flask / Django / FastAPI）を用いた変更差分をレビューする際の FW 固有観点。言語共通の Python 観点は `${CLAUDE_PLUGIN_ROOT}/references/languages/python.md` に従い、本ファイルは各 FW 固有の追加観点のみを扱う。プロジェクト独自規約が存在する場合はそちらを優先する（`${CLAUDE_PLUGIN_ROOT}/references/conventions-resolution.md` の優先順位に従う）。

Flask 系は API 定義に flask-restx、JWT 認証に Flask-JWT-Extended を用いる構成を想定する。

## 1. 対象と検出条件

差分・リポジトリに以下が含まれる場合、該当 FW の観点を適用する。

| フレームワーク | 検出マーカー |
|--------------|-------------|
| Flask | 依存定義（`pyproject.toml` / `requirements.txt`）に `flask`。`create_app()` / `Flask(__name__)`。API に `flask-restx`、認証に `flask-jwt-extended` が併記されることが多い |
| Django | 依存定義に `django`。ルートに `manage.py`、設定に `settings.py` / `urls.py` / `wsgi.py` / `asgi.py` |
| FastAPI | 依存定義に `fastapi`（多くは `uvicorn` / `pydantic` を同梱）。`FastAPI()` インスタンス、`@app.get` 等のデコレータ |

同一リポジトリに複数 FW が併存する場合（例: 管理系 Django + API 系 FastAPI）は該当セクションを併読する。

## 2. FW ごとのレビュー観点

### 2.1 Flask

- [ ] **debug モードの本番混入**: `app.run(debug=True)` / `FLASK_DEBUG=1` が本番構成に残っていないか（対話デバッガ経由で任意コード実行に至る） 【担当: security-engineer】
- [ ] **SSTI（テンプレートインジェクション）**: `render_template_string()` にユーザー入力を連結して渡していないか（`render_template` + コンテキスト変数で分離しているか） 【担当: security-engineer】
- [ ] **セッション秘密鍵**: `SECRET_KEY` / `JWT_SECRET_KEY` がソースへ直書きされていないか。環境変数等から注入しているか 【担当: security-engineer】
- [ ] **JWT 保護**: 認証が必要なルートに `@jwt_required()`（v4 以降は括弧必須）が付与されているか。デコレータの重ね順が崩れて認可が素通りしていないか 【担当: security-engineer】
- [ ] **app / request コンテキスト**: `current_app` / `g` / `request` をリクエスト外（起動時・バックグラウンド）で参照して `RuntimeError` を招いていないか 【担当: implementation-engineer】
- [ ] **アプリケーションファクトリ**: 拡張は `extensions.py` でインスタンス化し `create_app()` で `init_app()` しているか。モジュールトップで `app = Flask(__name__)` して拡張を即時束縛していないか（多重初期化・テスト困難） 【担当: implementation-engineer】
- [ ] **SQLAlchemy セッション管理**: セッションの commit / rollback / close が漏れていないか。リクエストスコープでセッションが確実に破棄されるか 【担当: implementation-engineer】
- [ ] **入出力スキーマ**: `@ns.expect(model, validate=True)` / `@ns.marshal_with(model)` で入出力を明示し、Swagger と実装のずれ・機密フィールド露出を防いでいるか 【担当: implementation-engineer】
- [ ] **Resource の責務**: Resource メソッドにビジネスロジック・DB アクセスを直書きしていないか（services 層へ分離） 【担当: implementation-engineer】
- [ ] **CORS 設定**: `flask-cors` のオリジン許可が過剰（`*` + 資格情報）になっていないか 【担当: security-engineer】
- [ ] **エラーハンドラの情報漏洩**: `@app.errorhandler` / 例外時にスタックトレース・内部パス等をレスポンスへ出していないか 【担当: security-engineer】

### 2.2 Django

- [ ] **ORM の N+1**: 関連オブジェクトをループ内で辿っていないか。正方向 FK は `select_related`、逆方向・多対多は `prefetch_related` で解消しているか 【担当: performance-reviewer】
- [ ] **QuerySet の遅延・多重評価**: 同一 QuerySet を複数回評価して同じクエリを繰り返していないか。ループ前に `list()` で確定すべき箇所はないか 【担当: performance-reviewer】
- [ ] **DEBUG の本番混入**: 本番設定で `DEBUG = True` になっていないか（例外ページで設定・スタックトレースが露出する） 【担当: security-engineer】
- [ ] **CSRF**: CSRF ミドルウェアが有効か。`@csrf_exempt` を状態変更ビューに安易に付けていないか 【担当: security-engineer】
- [ ] **raw() / extra() のパラメタライズ**: `raw()` / `extra()` / `RawSQL` に文字列連結でユーザー入力を渡していないか。パラメータ（`params=[...]`）を使っているか 【担当: security-engineer】
- [ ] **mark_safe（XSS）**: `mark_safe()` / `format_html` 未使用の `|safe` に未信頼データを渡していないか 【担当: security-engineer】
- [ ] **SECRET_KEY / 設定の環境分離**: `SECRET_KEY` / DB 認証情報が `settings.py` へ直書きされていないか。環境ごとに設定が分離されているか 【担当: security-engineer】
- [ ] **マイグレーションの後方互換・ロック**: 列削除・NOT NULL 追加・大テーブルへの索引追加がデプロイ中の旧コードを壊さないか、長時間ロックを招かないか。マイグレーションがレビュー・コミットされているか 【担当: implementation-engineer】
- [ ] **シグナルの暗黙副作用**: `post_save` 等のシグナルレシーバに重い処理・追加の DB 書き込みが隠れていないか（呼び出し側から見えない副作用） 【担当: implementation-engineer】
- [ ] **fat model, thin view**: ビジネスロジックがビューに集中していないか（モデル / マネージャへ寄せる） 【担当: implementation-engineer】
- [ ] **管理サイト・セキュリティミドルウェア**: 本番で Django admin が弱い URL で到達可能になっていないか。`SecurityMiddleware` / `CsrfViewMiddleware` が有効・適切な順序か 【担当: security-engineer】
- [ ] **ALLOWED_HOSTS / セキュア Cookie**: 本番で `ALLOWED_HOSTS` が適切に絞られ、`SESSION_COOKIE_SECURE` / `CSRF_COOKIE_SECURE` が有効か 【担当: security-engineer】

### 2.3 FastAPI

- [ ] **async 内の同期ブロッキング I/O**: `async def` 内で同期 DB ドライバ / `requests` / `time.sleep` を呼んでイベントループを塞いでいないか（`httpx` / `asyncio.sleep` / 非同期ドライバへ置換、または同期処理は `def` に） 【担当: performance-reviewer】
- [ ] **Pydantic による入力検証**: リクエスト / レスポンススキーマを Pydantic モデル（v2）で定義し、型ヒント駆動で検証しているか。手動パースで検証を回避していないか 【担当: implementation-engineer】
- [ ] **response_model の指定**: `response_model=` を指定して出力スキーマを固定しているか。内部モデルをそのまま返して機密フィールドを漏らしていないか 【担当: security-engineer】
- [ ] **Depends のスコープ・オーバーライド**: `Depends()` の依存が適切なスコープで解決されるか。`dependency_overrides` がテスト外で残っていないか 【担当: implementation-engineer】
- [ ] **BackgroundTasks の誤用**: レスポンス後に確実な完了が必要な処理を `BackgroundTasks` に載せていないか（失敗が握りつぶされる。永続キューが適切な場面ではないか） 【担当: implementation-engineer】
- [ ] **OAuth2 / JWT の検証**: トークンの署名・有効期限・スコープを検証しているか。`Depends` の認証依存を保護対象ルートに付け忘れていないか 【担当: security-engineer】
- [ ] **CORS 設定**: `allow_origins=["*"]` + `allow_credentials=True` の危険な組み合わせや、過剰なオリジン許可になっていないか 【担当: security-engineer】
- [ ] **エンドポイントのテスト**: 認証あり / なし・バリデーション不正のケースが `TestClient` / `httpx` でカバーされているか 【担当: test-engineer】

### 2.4 検出のヒント（grep 例）

差分の該当箇所を素早く特定するための検索パターン。ヒットした周辺で上記チェックリストを確認する。

| リスク | 検索パターン（例） | 確認事項 |
|-------|------------------|---------|
| SSTI | `render_template_string(` | ユーザー入力を連結していないか |
| debug の本番混入 | `debug=True` / `DEBUG = True` | 本番構成に残っていないか |
| 生 SQL | `.raw(` / `.extra(` / `RawSQL(` / `cursor.execute(` | パラメータ化しているか |
| 秘密鍵のハードコード | `SECRET_KEY` / `JWT_SECRET_KEY` | 直書きでなく環境変数からか |
| CSRF 無効化 | `csrf_exempt` | 状態変更ビューに付けていないか |
| XSS | `mark_safe(` / `\|safe` | 未信頼データを渡していないか |
| async ブロッキング | `async def` の近傍で `requests.` / `time.sleep(` | 非同期 API に置換すべきか |
| CORS 過剰許可 | `allow_origins` / `CORSMiddleware` | `*` + credentials の併用がないか |

## 3. 典型的な指摘パターン（重要度の目安）

| パターン | 重要度の目安 | 根拠 |
|---------|------------|------|
| `render_template_string()` へのユーザー入力（SSTI） | Critical | サーバサイドテンプレートインジェクション → RCE |
| `raw()` / `extra()` / `RawSQL` への文字列連結（ユーザー入力含む） | Critical | SQL インジェクション |
| `debug=True`（Flask） / `DEBUG=True`（Django）の本番混入 | Critical | デバッガ経由 RCE・設定/スタック露出 |
| `SECRET_KEY` / `JWT_SECRET_KEY` のハードコード | Critical〜High | トークン偽造・セッション改ざん |
| `response_model` 未指定で内部モデル返却・`mark_safe` へ未信頼データ | High | 機密漏洩 / XSS |
| JWT / OAuth2 検証の欠落・`@jwt_required()` 付け忘れ | High | 認証バイパス |
| `@csrf_exempt` の濫用 | High | CSRF |
| CORS の `*` + credentials 併用 | High | クロスオリジンでの資格情報漏洩 |
| `ALLOWED_HOSTS` 未設定 / セキュア Cookie 無効 / admin 弱 URL 公開（Django 本番） | High〜Medium | ホストヘッダ攻撃・セッション盗聴・管理画面到達 |
| エラーハンドラ / 例外レスポンスでの内部情報露出 | Medium | 情報漏洩（攻撃の足がかり） |
| `async def` 内の同期ブロッキング I/O | High | イベントループ停止・スループット崩壊 |
| Django ORM の N+1 / QuerySet 多重評価 | High〜Medium | 性能劣化（データ量依存） |
| 後方互換を壊す / 大テーブルをロックするマイグレーション | High〜Medium | デプロイ中の障害・長時間ロック |
| シグナルの隠れた副作用・BackgroundTasks の誤用 | Medium | 追跡困難な副作用・処理欠落 |
| app/request コンテキスト外参照（Flask） | Medium | `RuntimeError` で機能停止 |
| Resource / View へのロジック集中 | Medium〜Low | 保守性低下・テスト困難 |

### NG / OK 例（FastAPI の async ブロッキング）

```python
# NG: async 関数内で同期 HTTP クライアントを呼びイベントループを塞ぐ
@app.get("/price")
async def price():
    r = requests.get("https://api.example.com/price")  # ブロッキング
    return r.json()

# OK: 非同期クライアントを使う（または同期処理なら def にしてスレッドプール実行）
@app.get("/price")
async def price():
    async with httpx.AsyncClient() as client:
        r = await client.get("https://api.example.com/price")
    return r.json()
```

### NG / OK 例（Django の N+1）

```python
# NG: ループ内で FK を辿り、記事数 + 1 回のクエリが発生
for article in Article.objects.all():
    print(article.author.name)   # 各反復で author を都度クエリ

# OK: select_related で JOIN し 1 クエリに集約（多対多・逆参照は prefetch_related）
for article in Article.objects.select_related("author"):
    print(article.author.name)
```

## 4. 関連プロファイル参照

差分の内容に応じて以下を併読する。

| 対象 | プロファイル |
|------|-------------|
| Python 言語共通の観点（命名・例外処理・型ヒント・silent-failure） | `${CLAUDE_PLUGIN_ROOT}/references/languages/python.md` |
| ORM 横断観点（SQLAlchemy / Django ORM のクエリ・マイグレーション安全性） | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/orm.md` |
| フロントエンド（テンプレートが生成する HTML / CSS の品質） | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/frontend-tooling.md` |
| 指摘の重要度付与・重複統合 | `${CLAUDE_PLUGIN_ROOT}/references/severity-ranking.md` |
