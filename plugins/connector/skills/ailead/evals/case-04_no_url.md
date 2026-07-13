# case-04: URL なし — 対話モード

## 入力

```
ailead のデータを取得して
```

## 前提条件

- ailead 共有 URL が引数に含まれていない

## 期待される動作

### Phase 1: URL確認
- 引数に `dashboard.ailead.app/share/` パターンの URL がない
- `AskUserQuestion` でユーザーに URL を確認する

```
AskUserQuestion({
  question: "ailead の共有リンク URL を入力してください",
  header: "ailead URL",
  options: [
    { label: "URL を入力する", description: "dashboard.ailead.app/share/... 形式の URL" }
  ]
})
```

### Phase 2以降
- ユーザーが URL を提供した場合: 正常系と同様のフローを実行
- ユーザーが中止した場合: 処理を中断

## 分岐根拠

URL なしでスキルが起動された場合の対話的 URL 取得フロー。
