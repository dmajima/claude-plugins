# case-02: operationHash 更新 — 既知ハッシュ失敗からの自動復旧

## 入力

```
https://dashboard.ailead.app/share/abc123 のデータを取得して
```

## 前提条件

- 共有リンクが有効
- ailead がデプロイ更新され、既知の operationHash が期限切れ

## 期待される動作

### Phase 1-2: URL確認・準備
- 正常系と同様

### Phase 3: データ取得
- `fetch_share.py` が既知ハッシュで GraphQL を呼び出す
- `CLIENT_CODE_OUT_OF_DATE` エラーが返る
- スクリプトが HTML から JS チャンク URL を抽出
- JS チャンクから新しい operationHash を正規表現で取得
- 新ハッシュで再クエリ → 成功

### Phase 4-5: 報告・クリーンアップ
- 正常系と同様

## 分岐根拠

ailead のデプロイ更新で operationHash が変わった場合の自動リカバリフロー。
`api-spec.md` セクション7の既知ハッシュが古くなった際に発動する。
