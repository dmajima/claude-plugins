# code-review-security スキル

コード変更を **セキュリティ観点**（脅威モデル・OWASP/STRIDE・依存安全性）からレビューする観点別スキル。
内部で security-engineer / dependency-safety の 2 エージェントを並列起動し、結果を観点別中間レポートとして返却する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。
スキルが実行時に参照するのは `SKILL.md` と `references/` 配下です。

## 評価観点

| 観点 | 担当エージェント | 責務 |
|------|----------------|------|
| セキュリティ（OWASP/STRIDE） | security-engineer | 脅威モデリング・脆弱性評価・攻撃面分析・認証/認可・入力検証・XSS/SQLi/CSRF 等 |
| 依存・デプロイ安全性 | dependency-safety | 依存関係・破壊的変更・マイグレーション・設定階層整合・脆弱性スキャン実行 |

補足:

- 脆弱性スキャン（`dotnet list package --vulnerable` / `npm audit` / `pip-audit` / `osv-scanner` / `trivy` 等）は
  対応する Bash 権限が許可されている場合のみ実行し、権限がなければ SKIPPED として記録する
- 入力として技術スタック・公開範囲（社内/インターネット）・個人情報の有無・依存定義ファイル差分を受け取る

## 使い方

### トリガーフレーズ例

```
セキュリティをレビューして
OWASP / STRIDE で確認して
依存関係の脆弱性を見て
破壊的変更の影響を確認して
```

認証・認可・データ保護・外部公開機能の変更時に特に有効。

### 起動経路

| 経路 | 説明 |
|------|------|
| code-review オーケストレーター経由 | 標準・簡易モード両方の必須スキルとして Skill ツール経由で委譲される |
| 単独起動 | 上記トリガーフレーズで本スキルのみを直接実行する |

## 出力

`SKILL.md` の「出力フォーマット」に従い、OWASP/STRIDE 分類の脅威・脆弱性指摘と、
CVE / 既知脆弱性・破壊的変更/マイグレーションリスクを **観点別中間レポート** として返却する。
統合サマリの最終フォーマット・Verdict 判定はオーケストレーター（`code-review`）の責務。

## ファイル構成

```
plugins/deep-code-review/skills/code-review-security/
├── SKILL.md                              # Claude が実行時に読むスキル定義
├── README.md                             # 本ファイル（人間向け）
├── evals/                                # 動作分岐検証ケース（case-01〜10 + README）
└── references/
    └── checklist.md                      # 中間レポート返却前の達成チェックリスト
```

## スコープ外

- レビュー対象ソースコードの変更（指摘提示のみ）
- 実装品質・テスト・アーキテクチャ等の他観点（対応する観点別スキルが担当）
- 統合サマリ生成・Verdict 判定（code-review オーケストレーターが担当）

## 関連スキル

- `code-review` — オーケストレーター（モード選択・観点別スキル統合）
- `code-review-implementation` / `code-review-testing` / `code-review-architecture` / `code-review-frontend` — 他の観点別レビュー
