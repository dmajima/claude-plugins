# Case 10: JSON パース失敗時の引き継ぎ提案

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "保存してある認証情報を一覧表示して。" |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | `credentials.json` が破損（JSON として不正） |

## 期待動作

### Phase 1: パス解決 + 読み込み試行

- 解決パスから `credentials.json` を読み込み試行
- JSON パースエラーが発生

### Phase 2: エラー通知 + 引き継ぎ提案

- ユーザに通知: "credentials.json のパースに失敗しました。バックアップして再初期化が必要です。"
- `AskUserQuestion` で「引き継いで修復する／中止する」を確認

### Phase 3: 引き継ぎ判断

- ユーザ承諾 → **`credentials-manager` を起動して `repair` モード** を実行
  - `credentials.json.bak.{timestamp}` バックアップ作成
  - 空ストア `{"credentials": {}}` で再初期化
- 拒否 → reader を終了し、エラー状態のまま中止

### Phase 4: 復旧後

- 修復完了後 → reader に戻り元の操作（list）を再試行

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル（承諾時） | `credentials.json.bak.{timestamp}`、空ストアで再初期化された `credentials.json` |
| 標準出力（要約） | エラー通知 + 引き継ぎ案内 + 再試行結果 |
| 終了状態 | 成功（承諾時）／中止（拒否時） |

## 分岐の根拠

「エラー系（書き込み修復は manager 責務）」分岐。reader が単独で `credentials.json` を破壊しない（書き込みを持たない）こと、修復は `credentials-manager` に委譲することを検証する。

## 関連ケース

- `credentials-manager:case-11_json_parse_error.md`（manager 側の repair 引き継ぎ受け入れフロー）
