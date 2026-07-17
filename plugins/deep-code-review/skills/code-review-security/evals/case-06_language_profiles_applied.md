# case-06 言語プロファイル受領とセキュリティ観点への適用（O10）

オーケストレーターから `language-profiles` 引数を受け取り、検出言語・FW のセキュリティ観点を内部エージェントのプロンプトに反映するケース。O10 の委譲経路を検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `<差分スコープ> <プロジェクト規約サマリ> language-profiles=languages/php.md(主), frameworks/php-web.md mode=standard` |
| 起動形態 | 委譲（code-review オーケストレーターから Skill ツール経由） |
| 差分内容 | PHP / Laravel の変更（`.php` + `composer.json`） |

## 分岐の根拠

references/skill-rules-matrix.md O10、`${CLAUDE_PLUGIN_ROOT}/references/common-references.md` セクション 4.5、SKILL.md 実行フロー手順 1.5。

## 期待動作

- 実行フロー手順 1.5 で `language-profiles` 引数を解釈し、適用プロファイル（`${CLAUDE_PLUGIN_ROOT}/references/languages/php.md`（主）+ `frameworks/php-web.md`）を確定する（O10）
- security-engineer / dependency-safety の各プロンプトに、common-references.md セクション 4.5 のテンプレートに従って言語プロファイル参照指示を含める
- security-engineer は php.md 観点 3.7（SQL インジェクション / XSS / `unserialize`（Object Injection）/ `eval` / コマンド実行 / パスワードハッシュ / オープンリダイレクト / CSRF）と php-web.md の Laravel 観点（mass assignment / Blade エスケープ / 認可ポリシー）を評価に使用する（type juggling は php.md 3.1・`@` エラー抑制は 3.2 で **implementation-engineer 担当**のため security-engineer のスコープ外。O4 で impl へ誘導）
- dependency-safety は php-web.md の依存追加観点と php.md セクション 6 の `composer validate` を参照する
- プロジェクト独自規約が最優先で、プロファイルのデファクトはプロジェクト規約が無い項目のみに適用する

## 関連ケース

- case-01: 委譲・脆弱性スキャン実行あり（language-profiles を含む基本委譲）
- code-review/case-06: オーケストレーター側の言語検出（送出側）
