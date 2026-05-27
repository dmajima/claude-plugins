# Case 03: 共有リンク期限切れ（HTTP 404）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "この ailead リンクから議事録を作って https://dashboard.ailead.app/share/<expired-key>" |
| 入力 URL | `https://dashboard.ailead.app/share/<期限切れの share-key>` |
| リンク状態 | 共有リンクの `expirationDatetime` を超過しており、HTML ページが 404 を返す |

## 期待動作

1. URL から share key を抽出する
2. HTML ページを `Invoke-WebRequest` で取得しようとする
3. HTTP 404 エラーが返されることを検出する
4. エラーの原因として共有リンクの期限切れを判断する
5. ユーザーに以下の情報を提示する:
   - 共有リンクが無効であること（期限切れまたは削除済みの可能性）
   - ailead 側で共有リンクを再発行するか、新しいリンクを取得するよう案内する
6. 処理を中断する（リトライしない）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（エラーのため出力しない） |
| ユーザーへの通知 | 「共有リンクが無効です（HTTP 404）。リンクの有効期限が切れている可能性があります。ailead で共有リンクを再発行してください。」等のエラーメッセージ |
| 終了状態 | エラー終了（ユーザーに原因と対処を明示） |

## 分岐の根拠

`references/procedures.md` エラーハンドリング表: 「HTTP 404 on HTML → 共有リンクの期限切れ → `expirationDatetime` を確認」。`references/api-spec.md` セクション6「既知の制約」: 「共有リンクの有効期限: expirationDatetime を超過するとデータ取得不可」。

## 関連ケース

- `case-01_success.md`（リンクが有効な正常パス）
- `case-02_hash_outdated.md`（リンクは有効だが API ハッシュが古い場合）
