# ailead API Specification

ailead（dashboard.ailead.app）の外部共有ページで使用される API の技術仕様。

## 1. システム構成

| レイヤー | 技術 |
|---------|------|
| フロントエンド | Next.js (SSG + CSR) |
| GraphQL クライアント | URQL + Apollo Client（混在） |
| 認証 | Firebase Authentication（共有ページでは不要） |
| ストレージ | Firebase Storage（動画セグメント） |
| Persisted Query | カスタム実装（`extensions.operationHash` + `extensions.buildId`） |

## 2. GraphQL エンドポイント

```
POST https://dashboard.ailead.app/api/v2/graphql
Content-Type: application/json; charset=utf-8
```

### リクエスト形式

ailead は標準的な Apollo APQ ではなく、カスタム Persisted Query 形式を使用する。
`query` フィールドは送信しない。代わりに `extensions` に `operationHash` と `buildId` を含める。

```json
{
  "operationName": "externalShare",
  "variables": {
    "key": "<share-key>"
  },
  "extensions": {
    "operationHash": "<hash>",
    "buildId": "<next-build-id>"
  }
}
```

| フィールド | 説明 | 取得方法 |
|-----------|------|---------|
| `operationName` | GraphQL オペレーション名（固定: `externalShare`） | 固定値 |
| `variables.key` | 共有リンクの key パラメータ | URL パスから抽出 |
| `extensions.operationHash` | クエリの SHA-256 ハッシュ | JS チャンクから抽出（後述） |
| `extensions.buildId` | Next.js のビルド ID | HTML の `__NEXT_DATA__` から抽出 |

### operationHash の取得

`operationHash` は共有ページの JS チャンクにハードコードされている。

**JS チャンクの特定方法:**

HTML ソース内の `<script>` タグから `pages/share/%5Bkey%5D-*.js` パターンのファイルを探す。

```
/_next/static/chunks/pages/share/%5Bkey%5D-<hash>.js
```

**JS チャンク内でのハッシュの位置:**

```javascript
key:"externalShare/dataflow/query",query:{__meta__:{hash:"<operationHash>"},kind:"Document",...}
```

正規表現パターン:
```
externalShare/dataflow/query.*?hash:"([0-9a-f]{64})"
```

### buildId の取得

HTML ソースの `<script id="__NEXT_DATA__">` から JSON をパースして取得する。

```html
<script id="__NEXT_DATA__" type="application/json">
  {"props":...,"buildId":"e4cd6bf-20260519",...}
</script>
```

正規表現パターン:
```
"buildId":"([^"]+)"
```

## 3. externalShare クエリのレスポンススキーマ

```graphql
query externalShare($key: String!) {
  externalShare(key: $key) {
    expirationDatetime
    id
    companyId
    title
    hostUser {
      id
      lastName
      firstName
      iconUrl
    }
    startDatetime
    duration
    system
    hlsUrl
    participants {
      id
      isHost
      displayName
      participantName
      participantTalkRatio
      oneFileSpeakerDiarizationNumbers
    }
    transcripts {
      id
      participantName
      text
      startTime
      endTime
    }
    diarizations {
      id
      participantName
      startTime
      endTime
    }
    callTasks {
      id
      type
      status
    }
    callSummary {
      id
      description
      keywords
      topics {
        id
        category
        dateTime
        description
        speakerName
        title
      }
    }
  }
}
```

### 主要フィールド解説

| フィールド | 型 | 説明 |
|-----------|---|------|
| `hlsUrl` | String | HLS ストリーミングプレイリスト URL（`.m3u8`） |
| `transcripts` | Array | 文字起こしセグメント（発話者・テキスト・時刻） |
| `transcripts[].startTime` / `endTime` | Float | 正規化された時刻（0.0〜1.0 の割合。実時刻は `duration` を乗算して算出） |
| `callSummary.description` | String | AI 生成の会議全体要約 |
| `callSummary.topics` | Array | トピック別の要約（カテゴリ: SHARE/DISCUSSION/DECISION/CONCERN/SUGGESTION/DIALOGUE/SCHEDULE） |
| `callSummary.keywords` | Array | 抽出キーワード |
| `diarizations` | Array | 話者分離データ |
| `participants[].participantTalkRatio` | Float | 発言割合（0.0〜1.0） |
| `system` | String | 録画元システム（`TEAMS` / `ZOOM` 等） |
| `expirationDatetime` | String | 共有リンクの有効期限（ISO 8601） |
| `callTasks` | Array | 処理タスクのステータス（RECORD/TRANSCRIPT/SUMMARY/EXTRACT/CONVERT） |

## 4. HLS 動画/音声

`hlsUrl` フィールドは以下形式の URL を返す:

```
https://dashboard.ailead.app/api/v1/share/media.m3u8?key=<share-key>
```

### .m3u8 プレイリスト構造

```
#EXTM3U
#EXT-X-VERSION:3
#EXT-X-TARGETDURATION:36
#EXT-X-MEDIA-SEQUENCE:0
#EXTINF:31.250000,
https://firebasestorage.googleapis.com/v0/b/champs-production.appspot.com/o/companies%2F<company-id>%2Fcalls%2F<call-id>%2Fstream%2Fstreaming0.ts?alt=media&token=<token>
...
#EXT-X-ENDLIST
```

- 各 `.ts` セグメントは Firebase Storage 上に配置
- URL にはアクセストークンが含まれており、認証なしで直接ダウンロード可能
- セグメント長は約 20〜36 秒

### ダウンロード方法（ffmpeg）

```powershell
ffmpeg -i "https://dashboard.ailead.app/api/v1/share/media.m3u8?key=<key>" -c copy output.mp4
```

音声のみ:
```powershell
ffmpeg -i "https://dashboard.ailead.app/api/v1/share/media.m3u8?key=<key>" -vn -acodec copy output.aac
```

## 5. パスワード保護されたリンク

パスワード保護されたリンクには追加のエンドポイントが存在する。

```
GET https://dashboard.ailead.app/api/v1/share/password?key=<share-key>
```

パスワード認証のフローは本スキル初回バージョンでは未実装。
必要に応じて今後追加する。

## 6. 既知の制約・注意事項

| 項目 | 説明 |
|------|------|
| `operationHash` の有効期限 | ailead のデプロイごとに変更される可能性がある。取得失敗時は JS チャンクからハッシュを再抽出する |
| `buildId` の更新 | デプロイごとに変更される。HTML から毎回動的に取得するため、通常は問題ない |
| 共有リンクの有効期限 | `expirationDatetime` を超過するとデータ取得不可 |
| `transcripts[].startTime` | 正規化値（0.0〜1.0）。実秒数は `startTime * duration` で算出 |
| Firebase Storage トークン | `.ts` セグメント URL のトークンは共有リンクの有効期限に準ずると推定 |
| レート制限 | 未検証。過度なリクエストは避ける |

## 7. 確認済みの operationHash（参考）

| 確認日 | hash | buildId 例 |
|-------|------|-----------|
| 2026-05-26 | `4a1237bbe10bf7ef3a7e9586ef2eb3a171b96311f6d3dbd6323be604b207f037` | `e4cd6bf-20260519` |

デプロイ更新で変更される可能性があるため、取得失敗時は JS チャンクから再抽出すること。
