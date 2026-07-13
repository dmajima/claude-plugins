# case-03: ファイル作成（承認フロー）

## 入力

```
Google Drive に「週次MTG議事録」という名前で新しいドキュメントを作成して
```

## 期待される動作

### Phase 1: 操作判定
- 操作種別: 書き込み（ファイル作成）

### Phase 2: 承認
- `AskUserQuestion` で作成内容を提示:
  - ファイル名: 週次MTG議事録
  - 種別: Google ドキュメント
- ユーザーが「作成する」を選択

### Phase 3: 作成実行
- `create_file` で `title: "週次MTG議事録"`, `contentMimeType: "application/vnd.google-apps.document"` を指定
- ファイルリンクを報告

## 分岐根拠

書き込み操作（承認必須）。AskUserQuestion 承認 → create_file の正常系。

## 関連ケース

- `case-06_user_cancel_create.md`（同じ作成依頼で承認時に「中止」を選択する対比）
