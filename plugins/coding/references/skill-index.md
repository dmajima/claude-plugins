# スキルインデックス（言語・フレームワーク検出マップ）

対象プロジェクトの言語・フレームワークを検出し、委譲すべき言語スキルと参照プロファイルを決定するための単一情報源（SSOT）。
検出手順の実行方法は [language-detection.md](language-detection.md) を参照。

## 1. 言語スキル一覧

| 言語 | スキル | 規約リファレンス | 主な検出マーカー |
|------|-------|----------------|----------------|
| C# | `coding-csharp` | `skills/coding-csharp/references/conventions.md` | `*.csproj` / `*.sln` / `*.cs` |
| Python | `coding-python` | `skills/coding-python/references/conventions.md` | `pyproject.toml` / `requirements.txt` / `setup.py` / `*.py` |
| JavaScript | `coding-javascript` | `skills/coding-javascript/references/conventions.md` | `package.json`（`tsconfig.json` なし）/ `*.js` / `*.mjs` / `*.cjs` |
| TypeScript | `coding-typescript` | `skills/coding-typescript/references/conventions.md` | `tsconfig.json` / `*.ts` / `*.tsx` |
| HTML | `coding-html` | `skills/coding-html/references/conventions.md` | `*.html` / `*.htm` |
| CSS | `coding-css` | `skills/coding-css/references/conventions.md` | `*.css` / `*.scss` / `*.sass` |
| PHP | `coding-php` | `skills/coding-php/references/conventions.md` | `composer.json` / `*.php` |
| SQL | `coding-sql` | `skills/coding-sql/references/conventions.md` + 方言別（下表） | `*.sql` / `migrations/` / ORM スキーマファイル |

### SQL 方言リファレンス（coding-sql スキル内）

| 方言 | リファレンス | 主な検出マーカー |
|------|-------------|----------------|
| MySQL | `skills/coding-sql/references/mysql.md` | 接続設定 `mysql:` / ポート 3306 / `mysql`・`mariadb` イメージ |
| SQL Server | `skills/coding-sql/references/sqlserver.md` | 接続文字列 `Server=` + `Trusted_Connection` / ポート 1433 / `mssql` イメージ |
| PostgreSQL | `skills/coding-sql/references/postgresql.md` | 接続設定 `postgres:` / ポート 5432 / `postgres` イメージ |

## 2. フレームワークプロファイル一覧

FW プロファイルの配置は「単一言語専用 = 言語スキル内 / 言語横断 = SSOT [frameworks/](frameworks/)」で分ける。

### 言語スキル内（単一言語専用）

| フレームワーク | 対象言語 | プロファイル | 主な検出マーカー |
|--------------|---------|-------------|----------------|
| ASP.NET Core / EF Core / Blazor / WebForms | C# | `skills/coding-csharp/references/frameworks/dotnet.md` | `Microsoft.AspNetCore.*` / `Microsoft.EntityFrameworkCore.*` 参照、`*.aspx` |
| Flask / Django / FastAPI | Python | `skills/coding-python/references/frameworks/python-web.md` | 依存定義に `flask` / `django` / `fastapi` |
| Laravel / Symfony / WordPress | PHP | `skills/coding-php/references/frameworks/php-web.md` | require に `laravel/framework` / `symfony/*`、`wp-config.php` |

### SSOT frameworks/（言語横断）

| フレームワーク | 対象言語 | プロファイル | 主な検出マーカー |
|--------------|---------|-------------|----------------|
| Express / NestJS | JS/TS | [frameworks/node.md](frameworks/node.md) | dependencies に `express` / `@nestjs/core` |
| React / Next.js | JS/TS | [frameworks/react.md](frameworks/react.md) | dependencies に `react` / `next` |
| Vue / Nuxt | JS/TS | [frameworks/vue.md](frameworks/vue.md) | dependencies に `vue` / `nuxt` |
| Vite / Tailwind / Sass / Vitest / Playwright / Jest | JS/TS/CSS | [frameworks/frontend-tooling.md](frameworks/frontend-tooling.md) | devDependencies に `vite` / `tailwindcss` / `vitest` / `@playwright/test` / `jest` |
| Prisma / EF Core / SQLAlchemy / Eloquent | SQL/ORM（TS・C#・Python・PHP） | [frameworks/orm.md](frameworks/orm.md) | `prisma/schema.prisma`、`Microsoft.EntityFrameworkCore`、依存定義に `sqlalchemy`、Laravel 標準 |

## 3. 検出優先順位

1. **マーカーファイル**（`package.json` / `*.csproj` / `pyproject.toml` / `composer.json` 等）を最優先
2. マーカーファイルの **依存定義**（dependencies / require / PackageReference）でフレームワークを特定
3. マーカーが無い場合のみ **拡張子の出現数** で言語を推定
4. 複数言語が共存する場合（例: Nuxt + Flask のモノレポ）は **検出されたすべての言語スキルを併用** する
5. SQL 方言が特定できない場合は `conventions.md`（共通）のみ適用し、方言固有構文の使用時にユーザへ確認する

## 4. 未対応言語の検出時

本インデックスに存在しない言語を検出した場合:

1. 言語スキル不在をユーザに明示する（勝手に推測した規約で進めない）
2. プロジェクト独自規約（`CLAUDE.md` / `.editorconfig` 等）が存在すればそれのみを根拠に作業する
3. 言語スキルの追加を提案する（[language-skill-template.md](language-skill-template.md) の構造に従う）
