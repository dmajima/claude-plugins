# case-03: 期限切れリンク

## 入力

```
ailead のこの共有リンクからデータを取得して
https://dashboard.ailead.app/share/expired_key_example
```

## 前提条件

- 共有リンクの有効期限が切れている

## 期待される動作

### Phase 1: URL確認
- URL パターンは正しい
- share key を抽出

### Phase 2: セッション準備
- 正常系と同様

### Phase 3: データ取得
- `fetch_share.py` が HTML ページ取得時に HTTP 404 を受信
- スクリプトが exit code 1 で終了
- エラーメッセージ: "Share page returned 404. The share link may have expired."

### Phase 4: エラー報告
- 「共有リンクが期限切れまたは無効です」とユーザーに報告
- 新しいリンクの提供を依頼

## 期待される出力

- ファイル出力なし
- エラーメッセージのみ

## 分岐根拠

共有リンク期限切れは最も頻出するエラーケース。
