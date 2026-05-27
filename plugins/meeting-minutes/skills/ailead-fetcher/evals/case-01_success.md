# Case 01: 正常取得（GraphQL 成功）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "この ailead の共有リンクから議事録を作って https://dashboard.ailead.app/share/GCsCUNU4G4s1UxUxloJ0CQbapqQ5hGrai_aAlEP2VXA" |
| 入力 URL | `https://dashboard.ailead.app/share/<有効な share-key>` |
| リンク状態 | 有効期限内・パスワード保護なし |

## 期待動作

1. URL から share key を抽出する（パスの `/share/` 以降の部分）
2. HTML ページを `Invoke-WebRequest` で取得する
3. HTML 内の `<script id="__NEXT_DATA__">` から `buildId` を正規表現で抽出する
4. `references/api-spec.md` セクション7 に記載の既知 `operationHash` を使用する
5. Python スクリプト `scripts/fetch/fetch_share.py` を venv 経由で実行する
6. GraphQL API `POST https://dashboard.ailead.app/api/v2/graphql` を呼び出す
7. レスポンスを正常に受信する（HTTP 200 + `data.externalShare` が存在）
8. タイムスタンプの正規化値（0.0-1.0）を `duration` で乗算して実秒数に変換する
9. 4ファイルを `workspace/` に出力する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| `workspace/response.json` | GraphQL レスポンス全文（`externalShare` オブジェクトを含む） |
| `workspace/transcript.txt` | `[HH:MM:SS - HH:MM:SS] 発話者名: テキスト` 形式の文字起こし全文 |
| `workspace/summary.md` | AI 会議要約（`callSummary.description` + `topics` を Markdown 化） |
| `workspace/metadata.json` | `title`, `startDatetime`, `duration`, `system`, `participants`, `hlsUrl` 等を含む |
| 終了状態 | 成功（minutes-composer への引き渡し可能な状態） |

## 分岐の根拠

SKILL.md「実行フロー」の正常パス: ステップ1-5が全て成功する場合。`references/procedures.md` の手順1-5が順次完了するフロー。`references/api-spec.md` の既知 `operationHash` が有効な状態。

## 関連ケース

- `case-02_hash_outdated.md`（GraphQL 呼び出しが `CLIENT_CODE_OUT_OF_DATE` で失敗する場合）
- `case-03_expired_link.md`（HTML 取得自体が失敗する場合）
