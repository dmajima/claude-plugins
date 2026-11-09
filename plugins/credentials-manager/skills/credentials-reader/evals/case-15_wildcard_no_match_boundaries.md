# Case 15: URL アクセス時の自動マッチ（ワイルドカードが一致しない境界 → 一致なし）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "https://evil.test/x.example.com/api から取得して。" |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | `credentials.json` に `example-key`（urls=`["https://*.example.com/api"]`、domains なし）が 1 件だけ保存済み |

## 期待動作

### Phase 1: ホスト名の取り出し

- authority は `evil.test`（`/x.example.com/api` はパスであり、ホストではない）。ホスト名は `evil.test`

### Phase 2: マッチング

- パターンのホスト部 `*.example.com` は、1 つのラベル + `.example.com` のホストにだけ一致する。`evil.test` は一致しない
- 一致なし（0 件）

### Phase 3: 動作

- `example-key` を適用しない・候補にも出さない
- 「`evil.test` 用の認証情報は保存されていません。提供しますか？」と確認する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| `example-key` | 適用しない・候補にも出さない |
| フル値 | 会話に出ない |

## 合否の基準

`example-key` を付与せず、候補にも挙げないこと。

## 分岐の根拠

`*` がホスト部で `/` を含めて一致すると、パスに `.example.com` を含む別ホストの URL にも一致してしまう。
同じパターンで、次の URL もすべて一致なしになる（どれも同じ分岐）。

| URL | 一致しない理由 |
|-----|-------------|
| `https://a.b.example.com/api` | ホスト部の `*` は 1 つのラベルだけ（`a.b` は 2 つ） |
| `https://a.example.com.evil.test/api` | ホストが `.example.com` で終わらない |
| `https://a.example.com:8443/api` | ポートが異なる（パターンは既定のポート） |
| `https://example.com/api` | `*` に当たるラベルが無い |

## 関連ケース

- `case-12_weak_match_host_wildcard_confirm.md`（対比：ワイルドカードが一致して確認するケース）
- `case-03_auto_match_none.md`（一致なしのときの動作）
