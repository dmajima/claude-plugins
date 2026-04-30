# Case 09: 取得（retrieve、対象あり）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "保存してある OpenAI のキーを使って `https://api.openai.com/v1/models` を呼び出して。" |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | `credentials.json` に `openai-api-key`（domains=`["api.openai.com"]`）が存在 |

## 期待動作

### Phase 1: パス解決と読み込み

- 解決パスから `credentials.json` を読み込み

### Phase 2: 名前検索

- ユーザ発話「OpenAI のキー」から `openai-api-key` を部分一致でヒット
- 単一ヒットのため確認なしで採用

### Phase 3: フル値の取得と内部利用

- `value` フィールドのフル文字列を取り出し、API 呼び出しに使用
- ユーザへの応答にはフル値を含めない（マスク済み値のみ表示）

### Phase 4: ユーザ通知

- "Using stored credential 'openai-api-key' (`sk-p****7890`) for api.openai.com." と通知

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（読み取りのみ） |
| 標準出力（要約） | マスク済み認証情報の通知 + API レスポンス |
| 終了状態 | 成功 |

## 分岐の根拠

このケースは「取得（retrieve）+ 部分一致単一ヒット」分岐に該当する。フル値が会話に出ないこと（マスキング規則）の検証が主要な観点。

## 関連ケース

- `case-10_retrieve_not_found.md`（候補不在時の動作）
- `case-04_auto_match_single.md`（URL のみ指定で名前指定なしの自動マッチとの違い）
