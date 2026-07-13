# Case 17: サブエージェント実行中の HTTP 401（auth_failed マニフェスト返却）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 他プラグインが subagent-protocol.md のテンプレートに従い `Agent()` で起動。args: `読み取りのみ。PROJ-123 の件名・本文・コメントを取得して` + 出力ディレクトリ + マニフェスト返却指示 |
| 既存状態 | credentials.json に `domains: ["example.backlog.jp"]` のエントリあり（`value` 非空）だが、API キーは Backlog 側で失効している |

## 期待動作

1. サブエージェント内で `Skill(skill: "connector:backlog")` を実行する
2. 認証事前確認は成功する（キーの失効はこの時点では検出されない）
3. `GET /api/v2/issues/PROJ-123` で HTTP **401** を受領する
4. サブエージェント実行（`AskUserQuestion` 利用不可）のため、再取得確認を試みず、**同一キーでのリトライも行わず**、以下のエラーマニフェストのみを返して終了する:

```json
{
  "status": "error",
  "error": "auth_failed",
  "service": "backlog",
  "detail": "HTTP 401（example.backlog.jp の API キーが失効している可能性）"
}
```

5. 呼び出し元は subagent-protocol.md セクション 3.5 に従い、メインコンテキストで対話取得フォールバックにより新しいキーを受領し（ストアの現在値と異なることを比較確認してから上書き保存）、同一テンプレートで再起動する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（issue.json は書き出されない） |
| 返却値 | JSON マニフェスト（`status=error` / `error=auth_failed` / `service=backlog`。`detail` にキーの値・レスポンス本文は含めない） |
| 終了状態 | 呼び出し元が復帰手順を実行可能（新キー保存 → 再起動後に success マニフェスト） |

## 分岐の根拠

サブエージェント実行時は 401 後の対話再取得（case-08 の Phase 4）が実行できないため、標準エラー種別 `auth_failed`（subagent-protocol.md セクション 3.3）のマニフェスト返却に分岐する。同一認証情報でのリトライ禁止（safe-api-access.md セクション 5）はサブエージェント内でも維持される。

## 関連ケース

- `case-08_http_401_error.md`（同じ 401 でもメインコンテキストでは対話取得フォールバックで再取得する対比）
- `case-15_subagent_credentials_missing.md`（認証情報が最初から無い場合のマニフェスト返却）
