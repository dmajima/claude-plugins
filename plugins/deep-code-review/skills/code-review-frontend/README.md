# code-review-frontend スキル

コード変更を **フロントエンド・UI/UX 観点**（HTML / CSS / JavaScript / React / Vue / テンプレートエンジン・アクセシビリティ・
レスポンシブ）からレビューする観点別スキル。内部で web-designer エージェントを起動し、
結果を観点別中間レポートとして返却する。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。
スキルが実行時に参照するのは `SKILL.md` と `references/` 配下です。

## 評価観点

| 観点 | 担当エージェント | 責務 |
|------|----------------|------|
| Web デザイン | web-designer | HTML 構造・CSS 設計・Vue.js コンポーネント・Liquid テンプレート・JS 動作・アクセシビリティ（WCAG）・レスポンシブ |

本スキル自体を呼ぶか否かの判断はオーケストレーター側の責務
（HTML / テンプレート（`.cshtml` / `.razor` / `.blade.php` / `.vue` / `.jsx` / `.tsx` / `.liquid` / `.twig` 等）/ CSS / 静的アセット / JavaScript の変更が一切ない場合に省略される）。

## 使い方

### トリガーフレーズ例

```
フロントエンドをレビューして
HTML / CSS / Vue / JS の変更を見て
アクセシビリティを確認して
レスポンシブ対応をレビューして
```

UI / 画面 / フォームの変更時に特に有効。

### 起動経路

| 経路 | 説明 |
|------|------|
| code-review オーケストレーター経由 | 標準モード・UI 変更あり時の観点別スキルとして Skill ツール経由で委譲される |
| 単独起動 | 上記トリガーフレーズで本スキルのみを直接実行する |

## 出力

`SKILL.md` の「出力フォーマット」に従い、HTML 構造・セマンティクス、CSS 設計・命名・スタイル衝突、
アクセシビリティ（WCAG）違反、レスポンシブ対応、React / Vue / テンプレートエンジン / JS の問題を **観点別中間レポート** として返却する。
統合サマリの最終フォーマット・Verdict 判定はオーケストレーター（`code-review`）の責務。

## ファイル構成

```
plugins/deep-code-review/skills/code-review-frontend/
├── SKILL.md                              # Claude が実行時に読むスキル定義
├── README.md                             # 本ファイル（人間向け）
├── evals/                                # 動作分岐検証ケース（case-01〜09 + README）
└── references/
    └── checklist.md                      # 中間レポート返却前の達成チェックリスト
```

## スコープ外

- レビュー対象ソースコードの変更（指摘提示のみ）
- 実装品質・テスト・セキュリティ等の他観点（対応する観点別スキルが担当）
- 統合サマリ生成・Verdict 判定（code-review オーケストレーターが担当）

## 関連スキル

- `code-review` — オーケストレーター（モード選択・観点別スキル統合）
- `code-review-implementation` / `code-review-testing` / `code-review-security` / `code-review-architecture` — 他の観点別レビュー
