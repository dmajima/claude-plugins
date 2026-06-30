# case-07: 不正な URL 形式

## 入力

```
ailead のデータを取得して https://example.com/share/abc123
```

## 前提条件

- 提示された URL が `dashboard.ailead.app/share/` パターンに一致しない

## 期待される動作

### Phase 1: URL確認
- URL パターン不一致を検出
- 「ailead の共有リンク URL（dashboard.ailead.app/share/...）を提供してください」とユーザーに確認

## 分岐根拠

URL のドメインや形式が異なる場合の入力バリデーション。
