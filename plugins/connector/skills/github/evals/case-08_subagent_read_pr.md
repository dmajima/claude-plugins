# Case 08: サブエージェント呼び出しによる PR 情報取得（Agent + ファイル受け渡し）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 他プラグイン（code-review）が `Agent()` ツールで起動。プロンプトに `Skill(skill: "connector:github", args: "読み取りのみ。PR URL: https://github.com/owner/repo/pull/42 の PR メタ情報を取得して")` + ファイル書き出し指示 + マニフェスト返却指示を含む |
| 引数 | PR URL + 出力ディレクトリ |
| フラグ | なし |
| 既存状態 | `gh` CLI 認証済み。呼び出し元は後続でレビュー実施を予定 |

## 期待動作

1. サブエージェント内で `Skill(skill: "connector:github")` を実行
2. github スキルがパターン B（読み取り）として PR メタ情報を取得
3. 取得結果を `{output-dir}/pr-meta.json` に Write
4. マニフェスト JSON を返却

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `{output-dir}/pr-meta.json` |
| 返却値 | JSON マニフェスト（status=success） |
| 終了状態 | 成功 |

## 分岐の根拠

subagent-protocol.md セクション 5.2 のテンプレートに基づく Agent() 経由呼び出し。

## 関連ケース

- `case-07_pattern_a_read_pr.md`（パターン A の読み取り）
- `case-02_delegation_pending_review.md`（Skill() 直接の書き込み委譲）
