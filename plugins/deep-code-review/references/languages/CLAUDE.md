# references/languages/ 読み込みガイド

## 目的と範囲

言語別レビュー観点プロファイルの SSOT。本プラグインが対応する 8 言語すべてをカバーし、各言語の「差分から検出すべき問題パターン」「典型指摘の重要度目安」「動的検証コマンド」を定義する。
FW 固有の観点は `${CLAUDE_PLUGIN_ROOT}/references/frameworks/` が保有する（本ディレクトリは言語コアのみ）。

## 原則

1. **検出してから適用**: プロファイルの適用は `${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` の検出結果に基づく。検出されなかった言語のプロファイルを適用しない
2. **プロジェクト規約優先**: プロファイルの規約観点は「プロジェクト独自規約が存在しない場合のデフォルト基準」。優先順位は `${CLAUDE_PLUGIN_ROOT}/references/conventions-resolution.md` に必ず従う
3. **担当エージェントの分担**: 各観点の【担当】表記に従い、エージェントは自分の担当観点を中心に読む（implementation-engineer は 3.1〜3.5 と 3.8、performance-reviewer は 3.6、security-engineer は 3.7、dba は sql.md 全般、web-designer は html.md / css.md 全般、linter-static-analysis / test-runner は各プロファイルの動的検証コマンド）
4. **重要度は目安**: 「典型的な指摘パターン」の重要度は目安であり、最終的な重要度付与・統合は `${CLAUDE_PLUGIN_ROOT}/references/severity-ranking.md` の基準に従う
5. **未対応言語は明示**: 本ディレクトリに無い言語は `${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` セクション 4 の手順で扱う（推測規約で黙って評価しない）

## ファイル一覧

| ファイル | 言語 | 主担当エージェント |
|---------|------|------------------|
| [csharp.md](csharp.md) | C#（.NET / .NET Framework） | implementation-engineer 他 |
| [python.md](python.md) | Python | implementation-engineer 他 |
| [javascript.md](javascript.md) | JavaScript（Node.js / ブラウザ） | implementation-engineer 他 |
| [typescript.md](typescript.md) | TypeScript（javascript.md を継承） | implementation-engineer 他 |
| [html.md](html.md) | HTML + テンプレートエンジン | web-designer |
| [css.md](css.md) | CSS / Sass / SCSS | web-designer |
| [php.md](php.md) | PHP | implementation-engineer 他 |
| [sql.md](sql.md) | SQL（MySQL / SQL Server / PostgreSQL 方言対応） | dba |

## hub + 観点別 details 構成

各観点が「hub（共通部）＋自観点の details だけ」をロードするよう、節3本文を観点別 details に分離した（内容は移動のみで欠落なし）。hub は識別・準拠規約・重要度表(節4)・FW(節5)・動的検証(節6)と、節3の**スタブ見出し（節番号温存）＋ポインタ**を保持する。外部参照（agents O10 の「観点 3.1〜3.5・3.8」等）は hub のスタブ経由で 2 ホップ解決する。

| hub | 観点別 details | 収録節 |
|-----|---------------|-------|
| `python.md` / `javascript.md` / `typescript.md` / `csharp.md` / `php.md` | `<言語>-impl.md` | 3.1〜3.6, 3.8（implementation-engineer / performance-reviewer / linter） |
| （同上） | `<言語>-security.md` | 3.7（security-engineer） |
| `sql.md` | `sql-core.md` | 3.1, 3.4〜3.8（dba ほか） |
| `sql.md` | `sql-security.md` | 3.2 インジェクション（security-engineer）/ 3.3 マイグレーション（dependency-safety） |
| `html.md` | `html-core.md` | 3.1〜3.3, 3.5, 3.6, 3.8（web-designer ほか） |
| `html.md` | `html-security.md` | 3.4 セキュリティ / 3.7 テンプレートエンジン（web-designer / security-engineer） |
| `css.md` | （未分割） | 全観点 web-designer 単一・security 節無しのため分割せず全体を維持 |

各エージェントは hub を Read 後、hub のスタブから **自担当（【担当】）の節に対応する details のみ** を Read する（他観点 details は読まない）。詳細は `${CLAUDE_PLUGIN_ROOT}/references/common-references.md` セクション 4.5。

## 章構成（全プロファイル統一）

hub（`<言語>.md`）が保持する章構成。分割プロファイルでは節3本文のみ観点別 details へ移動する（後述）。

| 章 | 内容 | 分割時の所在 |
|----|------|------------|
| 1. 識別 | 対象拡張子・マーカーファイル | hub |
| 2. 準拠規約 | プロジェクト規約が無い場合のデファクト基準 | hub |
| 3. レビュー観点 | 観点別チェックリスト（【担当: エージェント】付き） | hub に節番号スタブ＋ポインタのみ／本文は観点別 details（`-impl` / `-core` / `-security`） |
| 4. 典型的な指摘パターン | 重要度の目安表（一部プロファイルは NG/OK コード例を併記）。全観点が finding 突合に共用 | hub |
| 5. フレームワーク観点 | 検出 FW → `${CLAUDE_PLUGIN_ROOT}/references/frameworks/*.md` への参照 | hub |
| 6. 動的検証コマンド | ビルド / Linter / テストのコマンド（権限がある場合のみ実行、なければ SKIPPED） | hub |

## 利用方法（エージェントプロンプトへの組み込み）

観点別スキルはエージェント起動時、検出済み言語のプロファイルパスをプロンプトに含める:

```
## 言語別レビュー観点
検出言語: TypeScript（主）, CSS（副）
各言語プロファイルは hub＋観点別 details の 2 層（css は未分割）。以下の手順で Read せよ:
1. hub を Read: ${CLAUDE_PLUGIN_ROOT}/references/languages/typescript.md（javascript.md も継承元として参照） / ${CLAUDE_PLUGIN_ROOT}/references/languages/css.md
2. hub のスタブから、あなたの担当（【担当】）に該当する節のポインタ先 details のみ Read（例: security-engineer → typescript-security.md。impl 系 → typescript-impl.md。css は未分割で全体を使用）
3. ${CLAUDE_PLUGIN_ROOT}/references/frameworks/react.md
あなたの担当観点は【担当】表記を参照。プロジェクト独自規約（適用規約サマリ参照)が最優先。
```

## 禁止事項

- 検出されなかった言語のプロファイルを評価に使うこと
- プロファイルのデファクト規約をプロジェクト独自規約より優先すること
- プロファイルに無い言語を、プロファイルがあるかのように扱うこと（未対応の明示は `${CLAUDE_PLUGIN_ROOT}/references/language-detection.md` セクション 4）
- `README.md`（人間向け）をエージェント動作で参照すること
