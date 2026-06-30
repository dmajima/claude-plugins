# Case 04: 認証失敗時の停止（gh auth status 失敗）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "https://github.com/contoso/webapp/pull/42 のレビュースレッド一覧を取得して" |
| 既存状態 | `gh auth status` が終了コード != 0（未認証） |

## 期待動作

1. `gh auth status` の終了コード確認 → 認証失敗を検出
2. API を呼ばずに停止
3. ユーザーに `gh auth login` の実行を案内

## 分岐の根拠

認証失敗時の停止フロー。API を呼ばずに停止することが重要（認証情報の不正送信防止）。
