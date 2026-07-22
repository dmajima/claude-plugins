# references/frameworks/

言語横断フレームワークプロファイル（SSOT）。複数言語から共有される FW・ツールの規約を集約する。

## 原則

1. **配置基準**: 複数言語で共有される FW（React / Vue は JS・TS、ORM は TS・C#・Python・PHP）のみを置く。単一言語専用 FW（.NET / Python Web / PHP Web）は該当言語スキル内の `references/frameworks/` に置く（[../skill-index.md](../skill-index.md) 節 2 が配置の正典）
2. **言語規約は言語スキル側**: 本ディレクトリのプロファイルは FW 固有規約のみを扱い、言語自体の規約は各ファイル冒頭にリンクされた言語スキルの `conventions.md` に従う
3. **章構成**: [../language-skill-template.md](../language-skill-template.md) 節 4 のフレームワークプロファイル構成に従う

## ファイル一覧

| ファイル | 対象 | 主な利用言語 |
|---------|------|-------------|
| [node.md](node.md) | Express / NestJS | JavaScript / TypeScript |
| [react.md](react.md) | React / Next.js | JavaScript / TypeScript |
| [vue.md](vue.md) | Vue / Nuxt | JavaScript / TypeScript |
| [frontend-tooling.md](frontend-tooling.md) | Vite / Tailwind / Sass / Vitest / Playwright / Jest | JavaScript / TypeScript / CSS |
| [orm.md](orm.md) | Prisma / EF Core / SQLAlchemy / Eloquent | TypeScript / C# / Python / PHP |
