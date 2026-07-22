# TypeScript レビュー観点プロファイル

TypeScript コードの変更差分をレビューする際の言語固有観点。プロジェクト独自規約が存在する場合はそちらを優先する（`${CLAUDE_PLUGIN_ROOT}/references/conventions-resolution.md` の優先順位に従う）。

TypeScript は JavaScript のスーパーセットである。命名・フォーマット・イディオム・非同期・パフォーマンス・セキュリティの基礎観点は **JavaScript プロファイル（`${CLAUDE_PLUGIN_ROOT}/references/languages/javascript.md`）を継承** し、本ファイルは型システムに固有の追加観点を上乗せする。JS プロファイルと重複する観点は本ファイルで再掲せず、型固有の強化点のみを記す。

## 1. 識別

| 項目 | 値 |
|------|-----|
| 対象拡張子 | `.ts` / `.tsx`（JSX を含む TS） |
| マーカーファイル | `tsconfig.json` / `package.json`（`typescript` 依存）/ `eslint.config.js` / `.eslintrc*` |
| 世代判別 | `tsconfig.json` の `strict` = true（厳格・null 安全前提のモダン構成）/ false・未設定（暗黙 any・null 混入を許容する緩和構成でレガシー寄り） |

## 2. 準拠規約（プロジェクト規約が無い場合のデフォルト基準）

- TypeScript 公式 Do's and Don'ts（TypeScript Handbook）
- typescript-eslint recommended / recommended-type-checked 設定
- TypeScript チーム Coding guidelines（インターフェースに `I` プレフィクスを付けない根拠）
- フォーマットは JavaScript プロファイルと同一（Prettier デフォルト・`.prettierrc` / `.editorconfig` があればそちらに従う）

## 3. レビュー観点

> 3.x 本文は観点別 details に分離済み。**各 3.x の【担当】に対応する details のみ Read** すること（重要度表(節4)・動的検証(節6)は本 hub に残置）:
> - [`typescript-impl.md`](typescript-impl.md) … 3.1 3.2 3.3 3.4 3.5 3.6 3.8
> - [`typescript-security.md`](typescript-security.md) … 3.7

### 3.1 正確性・堅牢性【担当: implementation-engineer】

> → 本文は [`typescript-impl.md`](typescript-impl.md)（3.1）

### 3.2 エラー処理・silent-failure【担当: implementation-engineer】

> → 本文は [`typescript-impl.md`](typescript-impl.md)（3.2）

### 3.3 型設計・型安全【担当: implementation-engineer】

> → 本文は [`typescript-impl.md`](typescript-impl.md)（3.3）

### 3.4 非同期・並行処理【担当: implementation-engineer / performance-reviewer】

> → 本文は [`typescript-impl.md`](typescript-impl.md)（3.4）

### 3.5 命名・スタイル【担当: implementation-engineer / linter-static-analysis】

> → 本文は [`typescript-impl.md`](typescript-impl.md)（3.5）

### 3.6 パフォーマンス【担当: performance-reviewer】

> → 本文は [`typescript-impl.md`](typescript-impl.md)（3.6）

### 3.7 セキュリティ【担当: security-engineer】

> → 本文は [`typescript-security.md`](typescript-security.md)（3.7）

### 3.8 コメント・ドキュメント整合【担当: implementation-engineer】

> → 本文は [`typescript-impl.md`](typescript-impl.md)（3.8）

## 4. 典型的な指摘パターン（重要度の目安）

| パターン | 重要度の目安 | 根拠 |
|---------|------------|------|
| 外部入力のランタイム検証欠落（型アサーションのみ） | High〜Critical | 不正データが型安全領域へ流入・インジェクション起点 |
| 二重アサーション `as unknown as X` | High | 型システムの完全な迂回・実行時型不整合 |
| await 漏れ（floating promise） | High | 例外消失・処理順序不定（JS 継承） |
| non-null assertion `!` の誤用 | High〜Medium | 実行時 `undefined` 参照で例外 |
| `any` の濫用・暗黙 any | High〜Medium | 型安全性の放棄・エラー検出不能 |
| `@ts-ignore` による型エラー握りつぶし | Medium〜High | 潜在バグの隠蔽・原因の非局所化 |
| 判別可能ユニオンの網羅漏れ（default / never なし） | Medium〜High | ケース追加時の検出漏れ |
| `strict` の個別無効化 | Medium〜High | プロジェクト全体の型保証低下 |
| `as` 型アサーションの多用 | Medium | 型の迂回・リファクタ耐性低下 |
| `interface` / `type` 不統一・命名規則違反 | Medium〜Low | 可読性・規約整合 |
| 値と型の `import` 混在（`import type` 未使用） | Low〜Medium | 不要な実行時 import・`verbatimModuleSyntax` でビルド不成立 |
| インターフェース `I` プレフィクス | Low | 規約整合（C# と逆の慣習） |
| `satisfies` 未使用（`as` で代替） | Low | 任意改善（型推論の質・既存スタイル優先） |

### NG / OK 例（外部入力の型安全）

```typescript
// NG: 外部入力を型アサーションだけで信頼（実行時の形は保証されない）
async function getUser(id: string): Promise<User> {
  const res = await fetch(`/api/users/${id}`);
  return (await res.json()) as User;  // 実データが User と異なっても検出されない
}

// OK: ランタイムスキーマ検証で型と実データを一致させる
const UserSchema = z.object({ id: z.string(), name: z.string() });
type User = z.infer<typeof UserSchema>;

async function getUser(id: string): Promise<User> {
  const res = await fetch(`/api/users/${id}`);
  return UserSchema.parse(await res.json());  // 不正な形なら実行時に例外化
}
```

## 5. フレームワーク観点

差分に以下の FW が関与する場合、該当プロファイルを併読する（JavaScript プロファイルと共通の参照先）:

| 検出条件 | プロファイル |
|---------|-------------|
| `express` / `@nestjs/*`（Node.js サーバー） | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/node.md` |
| `react` / `next`（React / Next.js） | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/react.md` |
| `vue` / `nuxt`（Vue / Nuxt） | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/vue.md` |
| `vite` / `tailwindcss` / `vitest` / `jest` / `@playwright/test`（フロントエンドツール） | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/frontend-tooling.md` |
| `@prisma/client` / `prisma`（ORM 横断観点） | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/orm.md` |

## 6. 動的検証コマンド【担当: linter-static-analysis / test-runner】

対応する Bash 権限が許可されている場合のみ実行（なければ SKIPPED 記録）:

| 検証 | コマンド | 判定 |
|------|---------|------|
| 型チェック | `tsc --noEmit` | 型エラー = 強制 FAIL（Critical〜High） |
| Lint | `eslint .`（`typescript-eslint`。型情報 Lint は `parserOptions.project` 指定） | エラー = Medium〜High / 警告 = Low〜Medium |
| フォーマット | `prettier --check .` | 差分あり = Medium |
| テスト | `vitest run` / `jest` | 失敗 1 件ごとに最低 High |
| ビルド | `vite build` 等バンドラ（`tsc` 単体ビルドは構成依存） | 失敗 = High |
