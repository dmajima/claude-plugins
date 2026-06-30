# Case 09: 他プラグイン委譲によるスレッドステータス変更（パターン B）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | `Skill(skill: "connector:azure", args: "PR URL: https://dev.azure.com/contoso/WebApp/_git/webapp/pullrequest/123 のスレッド 456 のステータスを fixed に変更。承認済み。")` |
| 引数 | PR URL + スレッド ID + 新ステータス + 「承認済み」 |
| フラグ | なし |
| 既存状態 | 呼び出し元は コードレビュー用プラグインの pr-review スキル。`az` CLI ログイン済み。PR 123 は active。スレッド 456 は status=active |

## 期待動作

### Phase 1: 呼び出し元判別

- args に「承認済み」が含まれるため **パターン B（他プラグイン委譲）** と判別する

### Phase 2: 認証事前確認

- `az account show` で MS アカウント認証済みを確認
- ホスト種別 = クラウド / 操作手段 = `az` CLI / api-version = 7.1

### Phase 3: 操作種別判定

- 「スレッドステータス変更」を **書き込み（本文なし）** と判定
- render-check は本文なし操作のため対象外

### Phase 4: 安全ゲート

- 呼び出し元が「承認済み」を明示 → AskUserQuestion 承認をスキップ

### Phase 5: 実行と結果検証

- `az devops invoke ... --http-method PATCH --in-file "$BODY"` で `{ "status": "fixed" }` を送信
- レスポンスの `status` が `fixed` と一致することを確認し、呼び出し元に結果を返す

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし |
| 標準出力（要約） | 承認スキップ → スレッド 456 のステータスを fixed に変更完了 |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは **パターン B + 本文なし書き込み（ステータス変更）** である。render-check が対象外で、かつ承認もスキップされる最も簡潔な委譲パターン。

## 関連ケース

- `case-08_delegation_inline_comment.md`（パターン B の本文あり書き込み。render-check スキップが追加される対比）
- `case-03_pr_approve.md`（パターン A の本文なし書き込み。承認を省略しない対比）
