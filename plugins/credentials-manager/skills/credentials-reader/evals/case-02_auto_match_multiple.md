# Case 02: URL アクセス時の自動マッチ（複数件ヒット）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "https://api.openai.com/v1/models を呼び出して。" |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | `credentials.json` に `openai-api-key-personal`、`openai-api-key-work` の 2 件（共に domains=`["api.openai.com"]`）が保存済み |

## 期待動作

### Phase 1: 暗黙トリガー発火

- 同 case-01 同様、URL アクセス依頼から `credentials-reader` 起動

### Phase 2: マッチング

- 2 件ヒット

### Phase 3: 選択依頼（AskUserQuestion）

- ユーザに以下のように選択肢を提示:
  - `openai-api-key-personal` (`sk-p****f456`) — last updated 2026-04-08
  - `openai-api-key-work` (`sk-w****a123`) — last updated 2026-04-12
- ユーザ選択を受けて該当認証情報を採用

### Phase 4: 自動適用 + API 呼び出し

- 選択結果に基づき `Authorization: Bearer ...` を付与して API 呼び出し

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし |
| 標準出力（要約） | 選択UI → 選択結果通知 + API レスポンス |
| 終了状態 | 成功 |

## 分岐の根拠

「URL 自動マッチ・複数件」分岐に該当。`AskUserQuestion` 起動とマスク値表示が主要な観点。

## 関連ケース

- `case-08_non_interactive_multi.md`（非対話モードでは最新更新を採用）
