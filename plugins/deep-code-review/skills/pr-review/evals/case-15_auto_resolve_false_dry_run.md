# case-15 auto-resolve=false 指定時の dry-run（status 更新なし）

引数 `auto-resolve=false` を指定して再レビューを実行し、解消確認できたスレッドにも reply のみ投稿して status を変更しないケース（既定は auto-resolve のため dry-run は明示指定時のみ。`${CLAUDE_SKILL_DIR}/references/comment-status-policy.md` セクション 0.1-0.2）。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "PR #123 をレビューして auto-resolve=false"（既存自著スレッドあり・うち 1 件は解消済み） |
| モード | 非対話 |

## 分岐の根拠

comment-status-policy.md セクション 0.1「ユーザーが明示的に `auto-resolve=false` を指定しない限り、解消確認できたスレッドのステータス更新まで実施する。`auto-resolve=false` 指定時は解消候補のレポート（reply）のみ生成する」。

## 期待動作

- 解消確認できた自著スレッドへ解消候補 reply を投稿する（Pattern A の reply 文面で「status は未変更」の旨を明示）
- スレッドの status は active のまま変更しない（fixed / resolved への PATCH を実行しない）
- 旧サマリーの closed 化 PATCH も実行せず、完了報告に「実投稿時の closed 化アクション」を含める（comment-posting.md 7.5.5.1）
- 完了報告（Step 8）に dry-run 状態であることを明示する（completion-checklist.md D-8）
- 未解消スレッド（Pattern C）の動作は既定時と同一（reply のみ・status 不変）

## 関連ケース

- case-12: スレッド空配列時の早期スキップ
- case-13: スコープ外了承処理（ack-scope-out）
