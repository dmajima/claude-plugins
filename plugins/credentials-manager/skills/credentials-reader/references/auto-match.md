# URL 自動マッチ仕様

`credentials-reader` スキルの **暗黙トリガー** 時に動作する、URL/ドメインからの保存済み認証情報の自動マッチング仕様。SKILL.md 実行フロー step 4 から参照される。

## 1. 暗黙トリガーの条件

以下のいずれかに該当すると、ユーザから明示要求がなくても本スキルが起動する（PreToolUse / UserPromptSubmit フックからの `additionalContext` でも誘導される）。

| トリガー | 例 |
|--------|---|
| WebFetch ツールでの URL アクセス | 「`https://api.example.com/v1/users` から取得して」 |
| curl / wget / `gh api` 等のシェル経由 API 呼び出し | 「`curl https://api.github.com/user` を実行」 |
| Python `requests` / Node `fetch` 等のスクリプト記述 | コード生成・実行依頼 |
| API エンドポイント URL を含む指示一般 | 「`api.openai.com` にアクセス」 |
| 認証情報系ファイル（`.env` / `id_rsa` 等）の読み取り | フック検出経由で起動 |

## 2. マッチング順序と一致の強さ

ユーザリクエストから対象 URL を取り出し、ホスト名を次のとおり求める（ここを誤ると、別のホストに認証情報を付けてしまう）。

- スキームの後の `//` から、最初の `/` `?` `#` の前までを取り出す
- `@` があれば、その後ろだけをホストとする（`https://api.example.com@evil.test/` のホストは `evil.test`）
- `:` の後ろのポートは除き、小文字にする（ポートはホストとは別に比較する）

以下の順で `credentials.json` の `credentials.{name}` を検索する。**一致の強さ** が「強い」のは、保存済みの値がそのホスト用だと確定する一致だけである。

| 優先 | 突き合わせフィールド | 判定 | 一致の強さ |
|----|------------------|------|----------|
| 1 | `domains[]` | リクエストのホスト名と完全一致（小文字化して比較） | 強い |
| 2 | `urls[]`（ホスト部に `*` を含まないパターン） | スキーム・ホスト・ポートが完全一致し、パス部がパターンに一致（5 章） | 強い |
| 3 | `urls[]`（ホスト部に `*` を含むパターン） | ホスト部の `*` が 1 つのラベルにだけ一致し、ほかの部分も一致（5 章） | 弱い |
| 4 | `description` | リクエスト URL / ドメインを含むかの部分一致（フォールバック） | 弱い |

## 3. マッチ件数別の動作

確認なしで自動適用するのは **強い一致** だけである。弱い一致で自動適用すると、認証の要らない要求や
意図しないホストにトークンを付けてしまう（`description` の部分一致では、`hub.com` 宛ての要求が
`api.github.com` を含む説明に一致しうる）。

| 一致 | 対話モード | 非対話モード |
|-----|----------|------------|
| 強い一致が 1 件 | 自動適用。ユーザに「保存済み認証情報 `<name>` (`<masked>`) を `<domain>` に自動適用しました。」と通知 | 同左 |
| 強い一致が複数件 | `AskUserQuestion` でどれを使うか確認。選択肢にはマスク済み値・関連ドメイン・更新日を表示 | 最新の `updated_at` のエントリを採用し、採用したことを通知 |
| 強い一致が無く、弱い一致がある | 候補（マスク済み値・一致の根拠・更新日）を示し、`AskUserQuestion` で「適用する / 適用しない」を確認。承諾されたものだけ適用する | 適用しない（確認できないため）。「`<domain>` に一致しうる候補 `<name>` があるが、確認できないため適用しなかった」と通知 |
| 一致なし（0 件） | ユーザに「`<domain>` 用の認証情報は保存されていません。提供しますか？」と確認。提供されたら **`credentials-manager` への引き継ぎ**（[`handoff.md`](handoff.md) 参照） | 同左 |

確認なしで自動適用させたい認証情報は、保存時に `domains[]` へ完全なホスト名を入れる（`credentials-manager` の save / update）。

## 4. 適用方法（auth_method 解釈）

| `auth_method` 値 | 適用方法 |
|---------------|--------|
| `header:Authorization:Bearer`（既定） | HTTP リクエストヘッダ `Authorization: Bearer <value>` を付与 |
| `header:<name>:<prefix>` | `<name>: <prefix><value>`（prefix が空ならスペース無し） |
| `query:<param>` | URL に `?<param>=<value>` を付与（既存クエリがあれば `&` で連結） |

`auth_method` 未指定時は `header:Authorization:Bearer` を既定値として扱う。

## 5. ワイルドカード仕様

`urls[]` のパターンは、スキーム・ホスト・ポート・パスに分けて比較する。`*` が一致する範囲は、現れる位置で異なる。

| 位置 | `*` が一致する範囲 |
|-----|-----------------|
| ホスト部 | 1 つのラベルだけ（英数字とハイフン。`.` `/` `:` `@` を含まない） |
| パス部 | 任意の文字列（`/` を含む） |

スキームとポートは完全一致で比較する（`*` は使えない）。

| パターン | マッチ例 | 不一致例 |
|---------|--------|--------|
| `https://api.example.com/v1/*` | `https://api.example.com/v1/users` `https://api.example.com/v1/orders/123` | `https://api.example.com/v2/users` `http://api.example.com/v1/users` |
| `https://*.example.com/api` | `https://a.example.com/api` `https://b.example.com/api` | `https://example.com/api` `https://a.b.example.com/api` `https://evil.test/x.example.com/api` `https://evil.test/?.example.com/api` |

ホスト部の `*` はホストを確定しないため、この一致は弱い一致として扱う（3 章。自動適用せず確認する）。
正規表現は使用しない（誤マッチ防止）。

## 6. 通知メッセージのテンプレート

```
[credentials-manager] Stored credential '<name>' (<masked-value>) was automatically applied for <domain>.
```

複数件選択を求める場合:

```
[credentials-manager] Multiple stored credentials match <domain>. Please choose:
  - <name-1> (<masked-1>) — last updated <date>
  - <name-2> (<masked-2>) — last updated <date>
```

弱い一致だけの場合（適用してよいか確認する）:

```
[credentials-manager] Stored credential '<name>' (<masked-value>) may apply to <domain> (matched by <urls wildcard | description>). Apply it?
```

0 件の場合:

```
[credentials-manager] No stored credential matches <domain>. Do you have credentials for this URL?
```

承諾されたら `credentials-manager` を起動して保存フローへ遷移する（[`handoff.md`](handoff.md)）。

## 7. 暗黙トリガー時のスキップ条件

以下に該当する場合は自動マッチを実行しない（誤検出回避）。

| 状況 | 理由 |
|-----|------|
| URL がローカルホスト（`localhost` / `127.0.0.1` / `::1`） | 認証情報不要のことが多い |
| URL がプライベート IP（`10.x` / `172.16-31.x` / `192.168.x`） | 同上 |
| ユーザが明示的に「認証なしでアクセス」と指示 | 意図尊重 |
| ユーザが既に認証情報を提供済み | 二重適用を避ける |

## 8. プロアクティブ検出（API キー風文字列）との関係

会話中にシークレットパターン（`sk-` `ghp_` `AKIA` `Bearer` 等）が現れた場合のプロアクティブ検出は、本スキル SKILL.md 実行フロー step 6 + [`handoff.md`](handoff.md) を参照する。
