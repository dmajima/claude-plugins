# JavaScript レビュー観点プロファイル

JavaScript コードの変更差分をレビューする際の言語固有観点。プロジェクト独自規約が存在する場合はそちらを優先する（`${CLAUDE_PLUGIN_ROOT}/references/conventions-resolution.md` の優先順位に従う）。

## 1. 識別

| 項目 | 値 |
|------|-----|
| 対象拡張子 | `.js` / `.mjs`（ESM 明示）/ `.cjs`（CommonJS 明示）/ `.jsx`（JSX 構文） |
| マーカーファイル | `package.json` / `package-lock.json` / `pnpm-lock.yaml` / `yarn.lock` / `eslint.config.js` / `.eslintrc*` / `.prettierrc*` |
| 世代判別 | `package.json` の `"type": "module"` = ESM 既定 / 無し or `"commonjs"` = CommonJS 既定 |

> `tsconfig.json` が存在する場合は TypeScript プロファイル（`${CLAUDE_PLUGIN_ROOT}/references/languages/typescript.md`）を優先する。JavaScript と TypeScript が混在するプロジェクトでは両プロファイルを併用する。

## 2. 準拠規約（プロジェクト規約が無い場合のデフォルト基準）

JavaScript には言語公式の単一標準スタイルガイドが存在しない。プロジェクトの `.prettierrc` / `eslint.config.js` があればそれが最終的な正となり、以下は無い場合のデフォルト基準。

- Prettier デフォルト設定（フォーマット基準 / https://prettier.io/docs/options ）
- Airbnb JavaScript Style Guide（命名・慣習の代表例。Prettier デフォルトと一部差異あり）
- MDN JavaScript（言語仕様リファレンス）

## 3. レビュー観点

> 3.x 本文は観点別 details に分離済み。**各 3.x の【担当】に対応する details のみ Read** すること（重要度表(節4)・動的検証(節6)は本 hub に残置）:
> - [`javascript-impl.md`](javascript-impl.md) … 3.1 3.2 3.3 3.4 3.5 3.6 3.8
> - [`javascript-security.md`](javascript-security.md) … 3.7

### 3.1 正確性・堅牢性【担当: implementation-engineer】

> → 本文は [`javascript-impl.md`](javascript-impl.md)（3.1）

### 3.2 エラー処理・silent-failure【担当: implementation-engineer】

> → 本文は [`javascript-impl.md`](javascript-impl.md)（3.2）

### 3.3 型・null 安全【担当: implementation-engineer】

> → 本文は [`javascript-impl.md`](javascript-impl.md)（3.3）

### 3.4 非同期・並行処理【担当: implementation-engineer / performance-reviewer】

> → 本文は [`javascript-impl.md`](javascript-impl.md)（3.4）

### 3.5 命名・スタイル【担当: implementation-engineer / linter-static-analysis】

> → 本文は [`javascript-impl.md`](javascript-impl.md)（3.5）

### 3.6 パフォーマンス【担当: performance-reviewer】

> → 本文は [`javascript-impl.md`](javascript-impl.md)（3.6）

### 3.7 セキュリティ【担当: security-engineer】

> → 本文は [`javascript-security.md`](javascript-security.md)（3.7）

### 3.8 コメント・ドキュメント整合【担当: implementation-engineer】

> → 本文は [`javascript-impl.md`](javascript-impl.md)（3.8）

## 4. 典型的な指摘パターン（重要度の目安）

| パターン | 重要度の目安 | 根拠 |
|---------|------------|------|
| `innerHTML` 等へのユーザー入力代入 | Critical | XSS |
| `eval` / `new Function` へのユーザー入力 | Critical | コードインジェクション |
| SQL / コマンド文字列連結（ユーザー入力含む） | Critical | インジェクション |
| プロトタイプ汚染（信頼できない入力のマージ） | High〜Critical | 改ざん・権限昇格 |
| floating promise（await / .catch 漏れ） | High | 例外消失・順序不定・プロセス停止 |
| 空 catch / `.catch(() => {})` による握りつぶし | High | 障害の無言化・調査不能化 |
| コールバックの `err` 無視 | High | 失敗の見逃し |
| null / undefined ガード漏れ（外部入力） | High | `TypeError` で機能停止 |
| `forEach` 内 await（待たれない） | Medium〜High | 完了前に後続実行・データ不整合 |
| 金額 / 大整数を `Number` で計算 | Medium〜High | 精度欠落・桁落ち |
| イベントリスナー解除漏れ | Medium〜High | メモリリーク（長時間稼働で顕在化） |
| ループ内同期 I/O・直列 await | Medium〜High | 性能劣化（データ量依存） |
| 正規表現の ReDoS（脆弱なパターン＋ユーザー入力） | Medium〜High | サービス停止 |
| `==` 抽象等価による型強制 | Medium | 予期しない比較結果 |
| `Date` / タイムゾーン・パース依存 | Medium | 日付ずれ・境界バグ |
| `reduce` 内スプレッド（O(n^2)） | Medium | 大量データで性能劣化 |
| `var` 使用・命名規則違反 | Medium〜Low | 巻き上げバグ誘発・可読性・規約整合 |
| Prettier 未整形・未使用変数 | Low | スタイル整合 |

### NG / OK 例（floating promise + silent-failure）

```javascript
// NG: Promise を await/return せず、失敗も握りつぶす（floating promise + silent-failure）
function saveOrder(order) {
  repo.save(order).catch(() => {}); // 失敗が無言で消え、呼び出し元は成功と誤認
}

// OK: 呼び出し元へ完了と失敗を伝える
async function saveOrder(order) {
  try {
    await repo.save(order);
  } catch (err) {
    throw new OrderSaveError(`注文 ${order.id} の保存に失敗`, { cause: err });
  }
}
```

## 5. フレームワーク観点

差分に以下の FW が関与する場合、該当プロファイルを併読する:

| 検出条件 | プロファイル |
|---------|-------------|
| `express` / `@nestjs/*` / Node.js サーバーコード | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/node.md` |
| `react` / `next` | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/react.md` |
| `vue` / `nuxt` | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/vue.md` |
| `vite` / `jest` / `vitest` / `@playwright/*` 等（フロントエンドツール） | `${CLAUDE_PLUGIN_ROOT}/references/frameworks/frontend-tooling.md` |

## 6. 動的検証コマンド【担当: linter-static-analysis / test-runner】

対応する Bash 権限が許可されている場合のみ実行（なければ SKIPPED 記録）:

| 検証 | コマンド | 判定 |
|------|---------|------|
| 構文チェック | `node --check <file>` | エラー = 強制 FAIL（Critical〜High） |
| Lint | `npx eslint <path>` | error = High〜Medium / warning = Medium〜Low |
| フォーマット | `npx prettier --check <path>` | 差分あり = Low〜Medium |
| テスト（Vitest） | `npx vitest run` | 失敗 1 件ごとに最低 High |
| テスト（Jest） | `npx jest` | 同上 |
| テスト（Node 標準） | `node --test` | 同上 |
