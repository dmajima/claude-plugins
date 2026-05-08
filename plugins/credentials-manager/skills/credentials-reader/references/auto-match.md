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

## 2. マッチング順序

ユーザリクエストから対象 URL とドメインを抽出し、以下の順で `credentials.json` の `credentials.{name}` を検索する。

| 優先 | 突き合わせフィールド | 判定 |
|----|------------------|------|
| 1 | `domains[]` | リクエストドメインと完全一致（小文字化して比較） |
| 2 | `urls[]` | リクエスト URL とパターン一致（`*` ワイルドカード対応） |
| 3 | `description` | リクエスト URL / ドメインを含むかの部分一致（フォールバック） |

## 3. マッチ件数別の動作

| マッチ件数 | 動作 |
|----------|------|
| 1 件 | 自動適用。ユーザに「保存済み認証情報 `<name>` (`<masked>`) を `<domain>` に自動適用しました。」と通知 |
| 複数件 | `AskUserQuestion` でどれを使うか確認。選択肢にはマスク済み値・関連ドメイン・更新日を表示 |
| 0 件 | ユーザに「`<domain>` 用の認証情報は保存されていません。提供しますか？」と確認。提供されたら **`credentials-manager` への引き継ぎ**（[`handoff.md`](handoff.md) 参照） |

## 4. 適用方法（auth_method 解釈）

| `auth_method` 値 | 適用方法 |
|---------------|--------|
| `header:Authorization:Bearer`（既定） | HTTP リクエストヘッダ `Authorization: Bearer <value>` を付与 |
| `header:<name>:<prefix>` | `<name>: <prefix><value>`（prefix が空ならスペース無し） |
| `query:<param>` | URL に `?<param>=<value>` を付与（既存クエリがあれば `&` で連結） |

`auth_method` 未指定時は `header:Authorization:Bearer` を既定値として扱う。

## 5. ワイルドカード仕様

`urls[]` のパターンマッチでは末尾と中間の `*` のみ対応する。

| パターン | マッチ例 | 不一致例 |
|---------|--------|--------|
| `https://api.example.com/v1/*` | `https://api.example.com/v1/users` `https://api.example.com/v1/orders/123` | `https://api.example.com/v2/users` |
| `https://*.example.com/api` | `https://a.example.com/api` `https://b.example.com/api` | `https://example.com/api` |

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
