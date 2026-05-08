# Case 09: ローカルホスト URL（自動マッチスキップ）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "http://localhost:8080/api/users から取得して。" |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | `credentials.json` に複数のエントリ存在（localhost 用なし） |

## 期待動作

### Phase 1: 暗黙トリガー発火

- URL アクセス依頼を検出 → `credentials-reader` 起動

### Phase 2: スキップ判定

- リクエスト URL が `localhost` であるため、`references/auto-match.md` 節 7 のスキップ条件に該当
- 自動マッチをスキップし、認証なしでアクセスを許可

### Phase 3: ユーザ通知

- "Local URL detected (`localhost`). Skipping credential auto-match." と通知（任意・最小）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし |
| 標準出力（要約） | スキップ通知 + 認証なし API レスポンス |
| 終了状態 | 成功 |

## 分岐の根拠

「自動マッチスキップ条件」分岐。誤検出回避が主要な観点。`127.0.0.1` / `::1` / プライベート IP も同様の動作を期待。

## 関連ケース

- `case-01_auto_match_single.md`（外部 URL での自動マッチ）
