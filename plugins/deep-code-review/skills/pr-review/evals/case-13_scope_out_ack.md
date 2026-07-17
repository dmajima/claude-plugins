# case-13 スコープ外了承処理（ack-scope-out）

引数 `ack-scope-out=CR-001,CR-003` でスコープ外了承を実行するケース。通常レビューフロー（Step 1〜8）はスキップ。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "ack-scope-out=CR-001,CR-003" |
| モード | 非対話 |

## 分岐の根拠

SKILL.md Step 9「引数に ack-scope-out が含まれる場合、Step 1〜8 を実行せず本ステップのみ実行」。

## 期待動作

- finding-thread-map.json から CR-001, CR-003 の Thread ID を解決する
- Critical/High/security 系を含む場合でも警告なしで処理を続行する（キーワード除外・警告再確認は撤廃済み。`${CLAUDE_SKILL_DIR}/references/comment-status-policy.md` の P11 廃止注記を参照）
- 各スレッドへ了承 reply を投稿する
- Azure DevOps: status を wontFix に変更 / GitHub: resolve に変更
- PR の active なインラインスレッド残数を確認する
- 完了報告に処理件数・スキップ件数・PR 最終状態を出力する

## 関連ケース

- case-14: 修正完了確認（ack-fixed）
