# Case 03: URL アクセス時の自動マッチ（0 件 → credentials-manager 引き継ぎ）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "https://api.newvendor.com/v1/orders から取得して。" |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | `credentials.json` 不在、または該当ドメインの認証情報なし |

## 期待動作

### Phase 1: 暗黙トリガー発火

- `credentials-reader` 起動

### Phase 2: マッチング

- 0 件ヒット

### Phase 3: 保存提案

- ユーザに通知: "[credentials-manager] No stored credential matches api.newvendor.com. Do you have credentials for this URL?"
- `AskUserQuestion` で「提供する／提供しない」を確認

### Phase 4: 引き継ぎ判断

- ユーザが「提供する」と回答 → **`credentials-manager` を起動して保存フローへ遷移**（[`references/handoff.md`](../references/handoff.md) 節 4）
- ユーザが「提供しない」と回答 → 引き継ぎなし、認証なしで API 呼び出し or 中止

### Phase 5: 引き継ぎ後

- `credentials-manager` が保存フローを完了 → メインに戻り元の URL アクセス処理を続行

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル（提供時） | `credentials.json`（解決パス） |
| 標準出力（要約） | 保存提案 → 引き継ぎ通知 → 保存完了 → API レスポンス |
| 終了状態 | 成功 |

## 分岐の根拠

「URL 自動マッチ・0 件 → 引き継ぎ」分岐。reader が書き込みを持たないこと、引き継ぎ時にフル値を残さないことを検証する。

## 関連ケース

- `case-01_auto_match_single.md`（1 件ヒットでの自動適用）
- `case-07_proactive_detect.md`（プロアクティブ検出後の引き継ぎ）
