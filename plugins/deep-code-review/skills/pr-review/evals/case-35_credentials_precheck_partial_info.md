# case-35 認証情報の部分欠落時の最小問い合わせ（credentials-precheck 1.5.2）

オンプレ TFS Server の PR で、credentials.json に `username` はあるが `value`（パスワード）が欠落している部分情報状態を Step 1.5 で検出し、パスワードのみをユーザーに問い合わせる（他の情報は再入力させない）分岐。認証情報が全欠落の case-11 とは別の部分欠落パス。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "この TFS の PR をレビューして https://<社内ホスト>/tfs/.../pullrequest/46" |
| モード | 対話 |
| 認証情報の状態 | credentials.json の該当エントリに `username` はあるが `value`（パスワード）が空。`auth_method` は設定済み |

## 分岐の根拠

skills/pr-review/references/credentials-precheck.md セクション1.5.1（ホスト別の確認対象）・セクション1.5.2（部分的な情報のみある場合・表 1 行目）・セクション1.5.3（セキュリティ補足・値の非表示）、skills/pr-review/SKILL.md Step 1.5（認証情報の事前確認）、skill-rules-matrix.md P2 / U12。

## 期待動作

- Step 1（ホスト判定）: PR URL が社内ホスト（独自ドメイン）のため オンプレ TFS Server と判定する（credentials-precheck.md セクション1.5.1）
- Step 1.5: `connector:azure` に認証確認を委譲する経路で、connector が解決する credentials-manager ストア（`.claude/.local/plugins/credentials-manager/credentials.json`。後方互換で従来パスも）の該当エントリに `username` はあるが `value`（パスワード）が欠落していることを検出する（pr-review は直接参照しない・U12）
- Step 1.5.2: **パスワードのみをユーザーに問い合わせる**。既にある `username` / `auth_method` 等その他の情報は再入力させない（セクション1.5.2 表 1 行目）
- Step 1.5.3: 認証情報の値そのものは表示・確認させない（マスク / `value` の存在のみ確認・U12）
- ユーザーがパスワードを整えるまで Step 1 以降（PR API アクセス）には進まない（credentials-precheck.md セクション1.5.1「情報を整えるまで進まない」）
- 対照（別分岐）: `value` のみあり `username` も `auth_method` も空の場合は username を問い合わせる（または `auth_method=ntlm:<user>` 形式での再登録を促す・セクション1.5.2 表 2 行目）
- （以下は検出してはならない誤り）
    - `username` を含む全情報をユーザーに再入力させる（部分情報の無駄な再要求・セクション1.5.2 違反）
    - `value` 欠落のまま connector 経由で PR API を呼び、401 / 403 を誘発する
    - 「別の保管場所にあるかもしれない」と推測して API を呼ぶ（セクション1.5.2 表最終行・禁止）

## 関連ケース

- case-11: 認証情報が全て欠落時のユーザー問い合わせ（API 不発行。本ケースの部分欠落と対）
- case-06: オンプレ TFS Server の PR レビュー正常系（認証情報が揃っている場合）
