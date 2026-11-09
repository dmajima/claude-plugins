# Case 11: URL アクセス時の自動マッチ（description の部分一致だけ → 確認）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "https://hub.com/api/v1/items から取得して。" |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | `credentials.json` に `github-pat`（domains=`["api.github.com"]`、urls なし、description=`api.github.com 用の個人用トークン`）が 1 件だけ保存済み |

## 期待動作

### Phase 1: ホスト名の取り出し

- リクエスト URL のホスト名は `hub.com`

### Phase 2: マッチング

- `domains[]` の `api.github.com` は `hub.com` と完全一致しない（強い一致なし）
- `description` の `api.github.com 用の…` が文字列 `hub.com` を含むため、部分一致する（弱い一致）

### Phase 3: 確認

- 弱い一致だけのため、自動適用しない
- `AskUserQuestion` で「`github-pat` (`ghp_****abcd`) が `hub.com` に一致しうる（説明文の部分一致）。適用しますか？」と確認し、選択肢は「適用しない / 適用する」
- 「適用しない」が選ばれたら認証情報を付けずに処理を続け、「適用する」なら `auth_method` に従って付与する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| `AskUserQuestion` | 発火する（マスク済み値・一致の根拠を表示） |
| 自動適用の通知 | 出ない（承諾前に付与しない） |
| フル値 | 会話に出ない |

## 分岐の根拠

`description` の部分一致はホストを確定しない。自動適用すると、`hub.com` のような別ホストへの要求に
GitHub のトークンを付けてしまう。非対話モードでは確認できないため、適用せずに候補があることだけを通知する。

## 関連ケース

- `case-01_auto_match_single.md`（対比：`domains[]` の完全一致で自動適用）
- `case-12_weak_match_host_wildcard_confirm.md`（ホスト部のワイルドカードでの弱い一致）
