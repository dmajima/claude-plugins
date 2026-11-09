# Case 12: URL アクセス時の自動マッチ（ホスト部のワイルドカード → 確認 / ドメインをまたぐ URL → 一致しない）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ 例 1 | "https://eu.example.com/api から取得して。" |
| 起動フレーズ 例 2 | "https://evil.test/x.example.com/api から取得して。" |
| 起動フレーズ 例 3 | "https://api.example.com@evil.test/api から取得して。" |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | `credentials.json` に `example-key`（urls=`["https://*.example.com/api"]`、domains なし）が 1 件だけ保存済み |

## 期待動作

### Phase 1: ホスト名の取り出し

- 例 1: ホスト名は `eu.example.com`
- 例 2: ホスト名は `evil.test`（パスの `/x.example.com/api` はホストではない）
- 例 3: `@` の後ろがホストのため、ホスト名は `evil.test`

### Phase 2: マッチング

- パターンのホスト部 `*.example.com` の `*` は 1 つのラベルにだけ一致する
- 例 1: `eu` が 1 つのラベルとして一致し、スキーム・パスも一致 → ホスト部に `*` を含むため **弱い一致**
- 例 2・例 3: ホスト名 `evil.test` は `*.example.com` に一致しない → 一致なし

### Phase 3: 動作

- 例 1: 自動適用せず、`AskUserQuestion` で「`example-key` (`****`) が `eu.example.com` に一致しうる（ワイルドカードのホスト）。適用しますか？」と確認する
- 例 2・例 3: 一致なしとして扱い、「`evil.test` 用の認証情報は保存されていません。提供しますか？」と確認する（`example-key` は候補に出さない）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 例 1 | `AskUserQuestion` が発火し、承諾前に付与しない |
| 例 2・例 3 | `example-key` を適用しない・候補にも出さない |
| フル値 | 会話に出ない |

## 分岐の根拠

`*` がホスト部で `/` や `.` を含めて一致すると、`https://evil.test/x.example.com/api` のような別ホストの URL にも一致し、
保存済みの値を攻撃者のホストへ送ってしまう。ホスト部の `*` は 1 つのラベルに限り、ホスト名は `@` の後ろ・最初の `/` の前で取り出す。
ワイルドカードのホストは保存した時点でホストを確定しないため、一致しても確認を求める。確認なしで使いたい場合は `domains[]` に完全なホスト名を入れる。

## 関連ケース

- `case-11_weak_match_description_confirm.md`（説明文の部分一致での弱い一致）
- `case-01_auto_match_single.md`（対比：`domains[]` の完全一致で自動適用）
