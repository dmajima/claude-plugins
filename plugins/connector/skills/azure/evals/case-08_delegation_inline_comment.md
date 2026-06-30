# Case 08: 他プラグイン委譲によるインラインコメント投稿（パターン B）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | `Skill(skill: "connector:azure", args: "PR URL: https://tfs.example.com/DefaultCollection/MyProject/_git/myrepo/pullrequest/45 にインラインコメントを投稿。ファイル: /src/Controllers/OrderController.cs, 開始行: 120, 終了行: 135, 本文: [CR-001] SQL インジェクションの可能性。render-check 通過済み。承認済み。")` |
| 引数 | PR URL + ファイルパス + 行範囲 + 投稿本文 + 「render-check 通過済み」+ 「承認済み」 |
| フラグ | なし |
| 既存状態 | 呼び出し元は コードレビュー用プラグインの pr-review スキル。credentials.json に `tfs-password` エントリ登録済み。PR 45 は active |

## 期待動作

### Phase 1: 呼び出し元判別

- args に「render-check 通過済み」「承認済み」が含まれるため **パターン B（他プラグイン委譲）** と判別する

### Phase 2: 認証事前確認

- 認証確認はパターン A・B 共通で必ず実行する
- `tfs.example.com` が credentials.json の `tfs-password.domains` に含まれることを確認

### Phase 3: 安全ゲートの適用判定

- 呼び出し元が「render-check 通過済み」を明示 → render-check をスキップ
- 呼び出し元が「承認済み」を明示 → AskUserQuestion 承認をスキップ
- 操作内容はインラインコメント投稿（PR レビュー文脈で妥当）

### Phase 4: 実行と結果検証

- `threadContext` 付き body を構築し、`curl --ntlm --netrc-file` で POST
- レスポンスからスレッド `id` を取得し、**呼び出し元に threadId を返す**（ユーザーへの追加操作の提案は行わない）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（PR 45 にインラインコメントスレッドが 1 件作成される） |
| 標準出力（要約） | render-check スキップ → 承認スキップ → インラインコメント投稿完了（スレッド ID を呼び出し元に返す） |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは **パターン B（他プラグイン委譲）** である。パターン A（case-07）と異なり、render-check と AskUserQuestion 承認がスキップされる。呼び出し元（code-review の pr-review）が自身のワークフローで既にユーザー承認を取得済みであることを前提とする。

## 関連ケース

- `case-07_inline_comment_tfs.md`（パターン A のインラインコメント。安全ゲートを全て通過する対比）
- `case-09_delegation_thread_status.md`（パターン B でスレッドステータスを変更する場合）
