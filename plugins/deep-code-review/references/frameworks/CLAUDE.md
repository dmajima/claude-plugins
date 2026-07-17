# references/frameworks/ 読み込みガイド

## 目的と範囲

フレームワーク別レビュー観点プロファイルの SSOT。言語コアの観点（`${CLAUDE_PLUGIN_ROOT}/references/languages/`）に対し、本ディレクトリは FW 固有の観点（FW の誤用パターン・設定ミス・FW 特有のセキュリティ/性能問題）を提供する。
適用判断（どの FW プロファイルを使うか）は `${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` セクション 2.2 の検出条件に従う。

## 原則

1. **検出してから適用**: プロファイルの適用は `${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` の検出結果（依存定義の確認）に基づく。拡張子だけで FW を断定しない
2. **言語プロファイルとの併読**: FW プロファイルは言語プロファイルを置き換えない。言語コア観点（`${CLAUDE_PLUGIN_ROOT}/references/languages/<言語>.md`）+ FW 観点の両方を適用する
3. **プロジェクト規約優先**: FW のベストプラクティスは「プロジェクト独自規約が存在しない場合のデフォルト基準」（`${CLAUDE_PLUGIN_ROOT}/references/conventions-resolution.md` の優先度 5）
4. **意図的二重配置の正典管理**: EF Core は `dotnet.md` 節 2.2 が正典（`orm.md` 節 2.3 は横断比較の追加分のみ）。Eloquent は `php-web.md` が Laravel 統合面、`orm.md` が ORM 横断面を分担する。重複トピックには必ず正典を 1 つ定め、他方からは片方向参照する
5. **重要度は目安**: 「典型的な指摘パターン」の重要度は目安であり、最終付与・統合は `${CLAUDE_PLUGIN_ROOT}/references/severity-ranking.md` に従う

## ファイル一覧

| ファイル | 対象 FW | 主担当エージェント |
|---------|--------|------------------|
| [dotnet.md](dotnet.md) | ASP.NET Core（MVC / Web API / Minimal API）/ EF Core（**正典**）/ Blazor / ASP.NET WebForms | implementation-engineer / performance-reviewer / security-engineer |
| [php-web.md](php-web.md) | Laravel / Symfony / WordPress | 同上 + web-designer（テンプレート） |
| [python-web.md](python-web.md) | Flask / Django / FastAPI | implementation-engineer / performance-reviewer / security-engineer |
| [node.md](node.md) | Express 5 / NestJS | 同上 |
| [react.md](react.md) | React / Next.js | implementation-engineer / web-designer / security-engineer |
| [vue.md](vue.md) | Vue 3 / Nuxt | 同上 |
| [frontend-tooling.md](frontend-tooling.md) | Vite / Tailwind CSS / Vitest / Playwright / Jest / Sass / Bootstrap | web-designer / test-engineer |
| [orm.md](orm.md) | Prisma / EF Core（追加分）/ SQLAlchemy / Eloquent（横断面） | implementation-engineer / performance-reviewer / dba |

## 章構成（全プロファイル統一）

| 章 | 内容 |
|----|------|
| 1. 対象と検出条件 | 依存定義（package.json / *.csproj / composer.json 等）→ FW 判定の表 |
| 2. FW ごとのレビュー観点 | チェックリスト形式（【担当: エージェント】付き） |
| 3. 典型的な指摘パターン | 重要度の目安表（Critical / High / Medium / Low） |
| 4. 動的検証コマンド（任意） | FW 固有コマンドがある場合のみ（汎用ビルド・テストは言語プロファイル側が正典） |
| 最終章. 関連プロファイル参照 | 言語プロファイル・関連 FW への参照 |

新しい FW プロファイルを追加する場合は本章構成に完全準拠し、`${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` セクション 2.2 の対応表と本ファイルのファイル一覧を同時に更新する。

## 禁止事項

- 検出されなかった FW のプロファイルを評価に使うこと
- 言語プロファイルを読まずに FW プロファイルだけで評価すること（言語コア観点の欠落）
- 重複トピックの正典を定めずに両ファイルへ観点を追加すること（原則 4 違反）
- `README.md`（人間向け）をエージェント動作で参照すること
