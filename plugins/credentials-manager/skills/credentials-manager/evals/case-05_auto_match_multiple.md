# Case 05: URL アクセス時の自動マッチ（複数件ヒット）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "https://api.example.com/v1/users にアクセスして。" |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | `credentials.json` に `example-key-prod` と `example-key-dev`（両者ともに domains=`["api.example.com"]`）が保存済み |

## 期待動作

### Phase 1: 暗黙トリガー発火

- URL アクセス依頼から `credentials-manager` スキルを自動起動

### Phase 2: マッチング

- ドメイン `api.example.com` で 2 件ヒット

### Phase 3: ユーザに選択依頼

- `AskUserQuestion` を発火し、以下のような選択肢を提示:
  - `example-key-prod` (`abc-****7890`) — 更新日: 2026-04-15
  - `example-key-dev` (`xyz-****1234`) — 更新日: 2026-04-20

### Phase 4: 選択された認証情報で API 呼び出し

- ユーザの選択に応じて `auth_method` で適用
- 適用通知をユーザに表示

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし |
| 標準出力（要約） | 選択肢提示 → ユーザ選択後に自動適用通知 + API レスポンス |
| 終了状態 | 成功（ユーザ選択後） |

## 分岐の根拠

このケースは「URL 自動マッチ・複数件ヒット」分岐に該当する。選択 UI として `AskUserQuestion` を使うことが必須。

## 関連ケース

- `case-04_auto_match_single.md`（1 件ヒット時の自動適用）
- `case-08_non_interactive.md`（非対話モード時、複数ヒットでも自動選択する分岐の差分）
