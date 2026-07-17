# code-review-implementation スキル

コード変更を **実装品質観点**（コード正確性・コーディング規約・パフォーマンス）からレビューする観点別スキル。
内部で implementation-engineer / linter-static-analysis / performance-reviewer の 3 エージェントを並列起動し、
結果を観点別中間レポートとして返却する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。
スキルが実行時に参照するのは `SKILL.md` と `references/` 配下です。

## 評価観点

| 観点 | 担当エージェント | 責務 |
|------|----------------|------|
| 実装正確性 | implementation-engineer | ロジックの正しさ・例外処理・契約整合性・Quality/Style・Simplification |
| コーディング規約・整形 | linter-static-analysis | プロジェクト規約・整形・型違反の検出（ビルド/Linter コマンド実行可） |
| パフォーマンス | performance-reviewer | N+1・ブロッキング・メモリ・状態管理機構肥大化 |

補足:

- 動的検証（ビルド・Linter 実行）は対応する Bash 権限（`dotnet` / `npm` / `eslint` / `tsc` 等）が
  許可されている場合のみ実行し、権限がなければ SKIPPED として記録する（「未実施」を「問題なし」と書かない）
- `spec_summary=<要約>` 引数が指定された場合のみ、仕様整合性（実装漏れ・仕様逸脱・仕様矛盾）を追加観点として評価する

## 使い方

### トリガーフレーズ例

```
実装品質をレビューして
コードの正確性を確認して
Linter / 静的解析だけ実行して
パフォーマンスをレビューして
```

### 起動経路

| 経路 | 説明 |
|------|------|
| code-review オーケストレーター経由 | 標準・簡易モード両方の必須スキルとして Skill ツール経由で委譲される |
| 単独起動 | 上記トリガーフレーズで本スキルのみを直接実行する |

## 出力

`SKILL.md` の「出力フォーマット」に従い、エージェント別の **観点別中間レポート** を返却する。
統合サマリの最終フォーマット・Verdict 判定はオーケストレーター（`code-review`）の責務。

## ファイル構成

```
plugins/deep-code-review/skills/code-review-implementation/
├── SKILL.md                              # Claude が実行時に読むスキル定義
├── README.md                             # 本ファイル（人間向け）
├── evals/                                # 動作分岐検証ケース（case-01〜09 + README）
└── references/
    └── checklist.md                      # 中間レポート返却前の達成チェックリスト
```

## スコープ外

- レビュー対象ソースコードの変更（指摘提示のみ）
- テスト・セキュリティ・アーキテクチャ等の他観点（対応する観点別スキルが担当）
- 統合サマリ生成・Verdict 判定・Finding ID（CR-NNN）採番（code-review オーケストレーターが担当）

## 関連スキル

- `code-review` — オーケストレーター（モード選択・観点別スキル統合）
- `code-review-testing` / `code-review-security` / `code-review-architecture` / `code-review-frontend` — 他の観点別レビュー
