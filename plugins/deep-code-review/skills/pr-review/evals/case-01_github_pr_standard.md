# case-01 GitHub PR の初回標準レビュー（正常系）

GitHub の PR URL を指定して初回レビューを実行する正常系ケース。認証確認・差分取得・観点別レビューを経て、インラインコメントとサマリースレッドの投稿まで到達する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "https://github.com/example/repo/pull/123 をレビューして"（gh auth status 成功） |
| モード | 対話 |

## 分岐の根拠

SKILL.md Step 1 のホスト判定で GitHub（github.com）を検出し、Step 1.5（credentials-precheck.md 1.5.1）で `gh auth status` の成功を確認して通常フロー（Step 2〜8）に進む。mode 引数未指定のため標準モード（SKILL.md 入力表の既定: standard）。

## 期待動作

- URL からホストを GitHub と判定する
- Step 1.5: `gh auth status` の終了コードで認証を確認してから API を呼ぶ
- gh CLI で PR メタ情報・差分を取得する（Step 3）
- Step 3.5: code-review-spec-inference スキルへ期待挙動の推論を委譲する
- Step 4: スレッド一覧を取得する（初回のため自著 active スレッドが 0 件なら Step 5 をスキップ）
- Step 5.5: PR ブランチを worktree で分離チェックアウトする（local-checkout-review.md）
- Step 6: code-review オーケストレーターへ scope=pr-diff で差分・規約サマリを渡して委譲する
- Step 7: 投稿順序（インラインコメント全件 → 旧サマリー closed → 新サマリースレッド）で投稿する（初回は旧サマリーなし）
- 各コメントは投稿前バリデーション 4 項目（PATH / ESCAPE / SANITIZE / TEMPLATE）を通過してから投稿する（署名は connector が投稿前に自動付加するため pr-review は付加・検証しない）
- Step 7.4: finding-thread-map.json を `.claude/.local/work/{session}/` に保存する
- Step 7.5: 完了前チェックリストを通過し、レビュー判定に応じて worktree を処理する
- Step 8: 完了報告にレビューモード / 指摘件数 / 投稿件数 / 失敗件数 / 解消確認件数 / worktree 状態 / PR 外書き込み有無 / マッピング保存先を出力する

## 関連ケース

- case-02: クラウド Azure DevOps（az devops 経路）
- case-10: 投稿順序の詳細
- case-11: 認証情報欠落時（認証失敗側の分岐）
