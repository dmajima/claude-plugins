# Evals: render-check

このディレクトリは `render-check` の動作分岐の期待挙動を例示する。

## ケース一覧

| ケース | 内容 | 主な分岐根拠 |
|-------|-----|-------------|
| case-01 | `backlog-notation` ターゲットへの Markdown 混入を NOTATION FAIL で検出 → Backlog 記法への変換案を採用 → 全カテゴリ再チェックで PASS | NOTATION 検出 = FAIL |
| case-02 | `ado-markdown` の地の文に裸の `@yamada` / `#123` → AUTOLINK WARN（通知発生を明示）→ ユーザーが「このまま投稿」を選択し WARN のまま引き渡し | AUTOLINK 検出 = WARN（FAIL なし） |
| case-03 | `backlog-markdown` で記法・構造・機密いずれも問題なし → 5 カテゴリ全 PASS → プレビュー提示と PASS 引き渡し | 全カテゴリ検出 0 件 |
| case-04 | ログ引用内の Bearer トークンを SECRET FAIL で検出 → マスクして報告 + マスク済み修正案 → ユーザーが投稿を中止 | SECRET 確定的パターン検出 |
| case-05 | 単体起動でターゲット記法が不明 → 推測せず AskUserQuestion で記法を確認してからチェック実行 | 入力のターゲット未確定 |
| case-06 | `ado-markdown` でコードフェンス未クローズ（フェンス行が奇数個）→ 前処理の時点で STRUCTURE FAIL → 閉じフェンス挿入の修正案 → 再チェックで PASS | STRUCTURE 検出 = FAIL（フェンス開閉不一致） |
| case-07 | `ado-markdown` の地の文の `@yamada` で AUTOLINK WARN → ユーザーが「修正する」を選択 → インラインコード化の修正案を採用 → 全カテゴリ再チェックで PASS → 修正後本文を引き渡し | WARN 時のユーザー選択 = 修正する |

各ケースは仕様書として機能する（自動実行用の runnable フロントマターは付与していない）。

## 実行確認方法

各ケースの「入力」セクションのフレーズ・前提状態で Claude Code を起動し、「期待動作」「期待出力」と一致することを目視確認する。AskUserQuestion の実発火・選択肢の文言・プレビューの読みやすさは機械検証の射程外のため、人間レビューで確認する。

## demo.sh（構造検証）

スキル定義と参照ファイルの構造を **読み取り専用** で検証するスクリプト。外部 API 呼び出し・ネットワーク通信・ファイル変更を一切行わない。

```bash
# 計画のみ表示（副作用ゼロ; 既定）
bash plugins/connector/skills/render-check/evals/demo.sh

# 読み取り専用チェックを実行
bash plugins/connector/skills/render-check/evals/demo.sh --no-whatif
```

検証内容: `SKILL.md` の存在と frontmatter `name: render-check`、`references/check-procedures.md` の存在、プラグイン共通レンダリングルール 3 ファイルの存在、SKILL.md 内の 5 カテゴリ定義、ケースファイル 7 件の存在、ケースファイルが仕様書専用（runnable フロントマター無し）であること。
