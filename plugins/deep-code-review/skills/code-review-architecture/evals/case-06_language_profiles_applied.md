# case-06 言語プロファイル受領と FW 構造観点への適用（O10）

オーケストレーターから `language-profiles` 引数を受け取り、検出言語・FW の観点を内部エージェントのプロンプトに反映するケース。O10 の委譲経路を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `<差分スコープ> <プロジェクト規約サマリ> language-profiles=languages/sql.md(主, PostgreSQL), frameworks/orm.md mode=standard` |
| 起動形態 | 委譲（code-review オーケストレーターから Skill ツール経由） |
| 差分内容 | SQL マイグレーション + Prisma スキーマの変更（`migrations/*.sql` + `schema.prisma`） |

## 分岐の根拠

references/skill-rules-matrix.md O10、`${CLAUDE_PLUGIN_ROOT}/references/common-references.md` セクション 4.5、SKILL.md 実行フロー手順 1.5。

## 期待動作

- 実行フロー手順 1.5 で `language-profiles` 引数を解釈し、適用プロファイル（`${CLAUDE_PLUGIN_ROOT}/references/languages/sql.md`（主・PostgreSQL 方言）+ `frameworks/orm.md`）を確定する（O10）
- architect / dba の各プロンプトに、common-references.md セクション 4.5 のテンプレートに従って言語プロファイル参照指示を含める
- dba は sql.md 観点（マイグレーション安全性・後方互換・ロック・インデックス設計・PostgreSQL 方言固有）と orm.md の Prisma 観点（select/include 過剰取得・$queryRaw パラメタライズ）を評価に使用する
- SQL 方言が PostgreSQL と確定しているため、PostgreSQL 固有観点（SERIAL vs IDENTITY / VACUUM 影響 / トランザクショナル DDL）を適用する
- プロジェクト独自規約が最優先で、プロファイルのデファクトはプロジェクト規約が無い項目のみに適用する

## 関連ケース

- case-01: DB 変更あり・dba 起動（language-profiles を含む基本委譲）
- code-review/case-06: オーケストレーター側の言語検出（送出側）
