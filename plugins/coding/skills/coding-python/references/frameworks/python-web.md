# Python Web フレームワークプロファイル

対象言語プロファイル: [../conventions.md](../conventions.md)（言語規約はそちらに従う。本ファイルは FW 固有規約のみ）

対象フレームワーク: Flask（flask-restx / Flask-JWT-Extended 含む）、Django、FastAPI。

## 1. 検出

| フレームワーク | 検出マーカー |
|--------------|-------------|
| Flask | 依存定義（`pyproject.toml` / `requirements.txt` 等）に `flask` / `Flask`。API 層に `flask-restx`、認証に `flask-jwt-extended` が併記されることが多い。エントリに `create_app()` や `Flask(__name__)` |
| Django | 依存定義に `django` / `Django`。ルートに `manage.py`、設定パッケージに `settings.py` / `urls.py` / `wsgi.py` / `asgi.py` |
| FastAPI | 依存定義に `fastapi`（多くは `uvicorn` / `pydantic` を同梱）。エントリに `FastAPI()` インスタンス、`@app.get` 等のデコレータ |

同一リポジトリに複数 FW が併存する場合（例: 管理系 Django + API 系 FastAPI）は該当セクションを併用する。

## 2. Flask

公式: https://flask.palletsprojects.com/en/stable/
本環境の主力スタックであり、API 定義に **flask-restx**、JWT 認証に **Flask-JWT-Extended** を用いる構成を標準とする。

### 2.1 プロジェクト構造・配置規則

**アプリケーションファクトリパターン**（公式推奨: https://flask.palletsprojects.com/en/stable/patterns/appfactories/ ）と **Blueprint / Namespace 分割** を基本とする。

```
app/
├── __init__.py          # create_app() ファクトリ
├── extensions.py        # 拡張のインスタンス化（Api / JWTManager 等）
├── config.py            # 環境別 Config クラス
├── models/              # データモデル（ORM エンティティ等）
├── api/                 # flask-restx Namespace 単位で分割
│   ├── __init__.py
│   ├── auth.py          # 認証エンドポイント（login 等）
│   └── user.py          # ユーザー系エンドポイント
└── services/            # ビジネスロジック（ルーティングから分離）
```

- 拡張（`Api`・`JWTManager` 等）は `extensions.py` でインスタンスだけ生成し、`create_app()` 内で `init_app(app)` する（循環 import と多重初期化を避ける公式パターン）。
- ルーティング（Resource）とビジネスロジック（services）を分離し、Resource は入出力の整形に徹する。

アプリケーションファクトリの例:

```python
# app/__init__.py
from flask import Flask
from .extensions import api, jwt

def create_app(config_object="app.config.Config"):
    app = Flask(__name__)
    app.config.from_object(config_object)

    jwt.init_app(app)          # Flask-JWT-Extended
    api.init_app(app)          # flask-restx（Namespace は api 側で登録済み）
    return app
```

```python
# app/extensions.py
from flask_restx import Api
from flask_jwt_extended import JWTManager

api = Api(title="Sample API", version="1.0", doc="/docs")  # Swagger UI を /docs に配信
jwt = JWTManager()
```

### 2.2 FW 固有の命名・実装規約

**flask-restx**（公式: https://flask-restx.readthedocs.io/en/latest/ ）による API 定義と Swagger 自動生成:

- `Namespace` はリソースをグルーピングする単位（flask-restx における Blueprint 相当）。`Api.add_namespace()` で登録する。
- `api.model()` / `ns.model()` でデータ構造（入出力スキーマ）を定義すると、Swagger 仕様へ自動的にドキュメント化される（https://flask-restx.readthedocs.io/en/latest/swagger.html ）。
- `@ns.marshal_with(model)` / `@ns.marshal_list_with(model)` で出力をシリアライズし、同時に Swagger のレスポンス定義を付与する（`code=` で HTTP ステータス指定可）。
- `@ns.expect(model, validate=True)` で入力ペイロードの期待スキーマとバリデーションを宣言する。
- Swagger UI は `Api` の `doc=` に指定したパス（既定はルート `/`）へ自動配信される。

```python
# app/api/user.py
from flask import request
from flask_restx import Namespace, Resource, fields
from flask_jwt_extended import jwt_required, get_jwt_identity

user_ns = Namespace("users", description="ユーザー関連の操作")

user_model = user_ns.model("User", {
    "id": fields.Integer(readonly=True, description="ユーザーID"),
    "name": fields.String(required=True, description="氏名"),
})

@user_ns.route("/")
class UserList(Resource):
    @jwt_required()
    @user_ns.marshal_list_with(user_model)
    def get(self):
        """ユーザー一覧を取得"""
        return list_users()

    @user_ns.expect(user_model, validate=True)
    @user_ns.marshal_with(user_model, code=201)
    def post(self):
        """ユーザーを新規作成"""
        return create_user(request.get_json()), 201
```

**Flask-JWT-Extended**（公式: https://flask-jwt-extended.readthedocs.io/en/stable/ ）による JWT 認証:

- `create_access_token(identity=...)` でアクセストークンを発行する（`identity` は JSON シリアライズ可能な値。ユーザー ID 等は文字列化して渡す）。
- `@jwt_required()` でルートを保護する。**v4 以降は末尾に括弧 `()` が必須**（v3 の `@jwt_required` から変更）。
- `get_jwt_identity()` で保護ルート内から `identity` を取得する。追加クレームは `get_jwt()` で取得する（https://flask-jwt-extended.readthedocs.io/en/stable/basic_usage.html ）。
- 秘密鍵は `app.config["JWT_SECRET_KEY"]` に設定する（ソースへ直書きせず環境変数等から注入）。

```python
# app/api/auth.py
from flask_restx import Namespace, Resource
from flask_jwt_extended import create_access_token

auth_ns = Namespace("auth", description="認証")

@auth_ns.route("/login")
class Login(Resource):
    def post(self):
        """ログインしてアクセストークンを取得"""
        user = authenticate(...)              # 認証処理
        access_token = create_access_token(identity=str(user.id))
        return {"access_token": access_token}, 200
```

### 2.3 ツールチェーン

| 用途 | コマンド |
|------|---------|
| 開発サーバ起動 | `flask --app app run --debug`（`create_app` ファクトリ利用時は `FLASK_APP` にファクトリを指定） |
| 本番起動（WSGI） | `gunicorn "app:create_app()"` 等（Windows 開発時は `waitress-serve` も可） |
| テスト | `pytest`（`app.test_client()` でリクエストを検証） |
| Swagger UI | 開発サーバ起動後、`Api(doc=...)` に指定したパス（既定 `/`）で確認 |

### 2.4 ベストプラクティス・アンチパターン

- 拡張は `extensions.py` でインスタンス生成 → `create_app()` で `init_app()` する（グローバルにアプリを直接束縛しない）。
- 設定は環境別 `Config` クラスに分離し、`JWT_SECRET_KEY` や DB 接続情報は環境変数から注入する（ソースへ直書きしない）。
- API スキーマ（`api.model`）を定義し、`@ns.marshal_with` / `@ns.expect` で入出力を明示する（Swagger と実装のずれを防ぐ）。
- 認証が必要なルートには `@jwt_required()`（括弧付き）を必ず付与する。デコレータの重ね順に注意する（`@jwt_required()` は marshalling デコレータと併用可）。
- アンチパターン: Resource メソッド内にビジネスロジック・DB アクセスを直書きする（services 層へ分離する）。`create_app` を使わずモジュールトップで `app = Flask(__name__)` して拡張を即時束縛する（テスト・多重初期化で問題化）。

## 3. Django

公式: https://docs.djangoproject.com/en/stable/
コーディングスタイル: https://docs.djangoproject.com/en/stable/internals/contributing/writing-code/coding-style/

### 3.1 プロジェクト構造・配置規則

`django-admin startproject` / `manage.py startapp` が生成する標準構造に従う。

```
myproject/
├── manage.py                # 管理コマンドのエントリポイント
├── myproject/               # プロジェクト設定パッケージ
│   ├── __init__.py
│   ├── settings.py          # 設定
│   ├── urls.py              # ルート URLconf
│   ├── asgi.py
│   └── wsgi.py
└── myapp/                   # アプリケーション（機能単位）
    ├── __init__.py
    ├── admin.py
    ├── apps.py
    ├── models.py            # モデル定義
    ├── views.py             # ビュー
    ├── urls.py              # アプリ内 URLconf
    ├── migrations/          # マイグレーションファイル
    └── tests.py
```

- 機能ごとに「アプリ」を分割し、プロジェクト設定パッケージと区別する。
- ルート `urls.py` から各アプリの `urls.py` を `include()` で束ねる。

### 3.2 FW 固有の命名・実装規約

出典: Django coding style（https://docs.djangoproject.com/en/stable/internals/contributing/writing-code/coding-style/ ）

- Django 本体のコードスタイルは **Black（行長 88）** で整形され、インデントは 4 スペース。変数・関数・メソッド名は snake_case（camelCase を使わない）。
- import は isort で並べ替える。グループ順は future → 標準ライブラリ → サードパーティ → Django → ローカルアプリ。
- モデルは `django.db.models.Model` を継承し、クラス名は単数形の CapWords（`class Article(models.Model)`）。フィールド名は snake_case。
- URL パターンの `name=` は識別しやすい名前を付け、`{% url %}` / `reverse()` から参照する。

```python
# myapp/models.py
from django.db import models

class Article(models.Model):
    title = models.CharField(max_length=200)
    published_at = models.DateTimeField(auto_now_add=True)

    def __str__(self):
        return self.title
```

**マイグレーション**（公式: https://docs.djangoproject.com/en/stable/topics/migrations/ ）:

- モデル変更後は `python manage.py makemigrations` でマイグレーションファイルを生成し、`python manage.py migrate` で DB へ適用する。
- 特定アプリのみ対象にする場合は `python manage.py makemigrations <app_label>`。
- 生成されたマイグレーションはレビューしてからコミットする（自動生成任せにしない）。

### 3.3 ツールチェーン

| 用途 | コマンド |
|------|---------|
| プロジェクト生成 | `django-admin startproject <name>` |
| アプリ生成 | `python manage.py startapp <name>` |
| 開発サーバ起動 | `python manage.py runserver` |
| マイグレーション生成 | `python manage.py makemigrations` |
| マイグレーション適用 | `python manage.py migrate` |
| テスト | `python manage.py test` |

### 3.4 ベストプラクティス・アンチパターン

- モデル変更は必ずマイグレーションを生成・適用し、マイグレーションファイルもバージョン管理に含める。
- `SECRET_KEY` や DB 認証情報は `settings.py` に直書きせず環境変数から読み込む。本番では `DEBUG = False`。
- クエリ最適化: 関連オブジェクト取得時は `select_related`（正方向 FK）/ `prefetch_related`（逆方向・多対多）で N+1 を回避する。
- ビジネスロジックはモデル/マネージャに寄せ、ビューは薄く保つ（fat model, thin view）。
- アンチパターン: マイグレーション未生成のままモデルとスキーマが乖離する、`migrate` を本番反映前にステージングで検証しない。

## 4. FastAPI

公式: https://fastapi.tiangolo.com/
ASGI 層に Starlette、データ検証に Pydantic v2 を利用する型ヒント駆動フレームワーク。

### 4.1 プロジェクト構造・配置規則

FastAPI は構造を強制しないが、`APIRouter` によるルート分割を基本とする（公式: https://fastapi.tiangolo.com/tutorial/bigger-applications/ ）。

```
app/
├── main.py              # FastAPI() インスタンス、include_router
├── routers/             # APIRouter 単位で機能分割
│   └── users.py
├── schemas/             # Pydantic モデル（リクエスト/レスポンス）
├── dependencies.py      # Depends 対象（DB セッション・認証等）
└── services/            # ビジネスロジック
```

### 4.2 FW 固有の命名・実装規約

- **型ヒント駆動**: パスオペレーション関数の引数を型注釈すると、リクエストの検証・変換・OpenAPI ドキュメント生成が自動化される。
- **Pydantic モデル**（`BaseModel`、公式: https://docs.pydantic.dev/latest/ ）でリクエスト/レスポンススキーマを定義し、`response_model=` で出力スキーマを固定する。**Pydantic v2** を用いる（v1 からの移行で検証性能が向上する）。
- **依存性注入**: 共有ロジック（DB セッション・認証・ページング等）は `Depends()` で注入する（公式: https://fastapi.tiangolo.com/tutorial/dependencies/ ）。依存は同期/非同期どちらでもよく、依存の依存（グラフ）も自動解決される。
- **async 対応**: I/O バウンドな処理は `async def` で定義する。同期の `def` はスレッドプールで実行される。
- **ルート分割**: `APIRouter` で機能ごとに分け、`app.include_router()` で束ねる。

```python
# app/main.py
from fastapi import FastAPI, Depends, HTTPException
from pydantic import BaseModel

app = FastAPI(title="Sample API")

class UserIn(BaseModel):
    name: str
    email: str

class UserOut(BaseModel):
    id: int
    name: str

async def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.post("/users/", response_model=UserOut, status_code=201)
async def create_user(user: UserIn, db=Depends(get_db)):
    return await save_user(db, user)
```

### 4.3 ツールチェーン

| 用途 | コマンド |
|------|---------|
| 開発サーバ起動 | `uvicorn app.main:app --reload`（ASGI サーバ、https://www.uvicorn.org/ ） |
| テスト | `pytest`（`fastapi.testclient.TestClient` または `httpx` でエンドポイントを検証） |
| API ドキュメント | 起動後、Swagger UI は `/docs`、ReDoc は `/redoc` に自動生成 |

### 4.4 ベストプラクティス・アンチパターン

- `response_model=` を指定し、出力スキーマと OpenAPI ドキュメントを一致させる（機密フィールドの漏洩防止にもなる）。
- Pydantic v2 を用い、バリデーションを Pydantic モデルへ集約する（手書きの検証を減らす）。
- 認証・DB セッションなどの横断関心は `Depends()` に切り出して再利用する。
- `async def` 内でブロッキング I/O（同期 DB ドライバ・`requests` 等）を呼ばない（イベントループを塞ぐ）。非同期対応ライブラリを使うか、同期処理は `def`（スレッドプール実行）に置く。
- アンチパターン: 型ヒントを省略して手動でリクエストをパースする（FastAPI の検証・ドキュメント生成の利点を失う）、`response_model` 未指定で内部モデルをそのまま返す。
