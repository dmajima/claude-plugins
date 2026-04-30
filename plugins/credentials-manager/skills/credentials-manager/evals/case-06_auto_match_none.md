# Case 06: URL アクセス時の自動マッチ（0 件）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "https://api.unknown-service.com/v1/data から取得して。" |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | `credentials.json` に `api.unknown-service.com` ドメインの認証情報なし |
| グローバルルール | `~/.claude/rules/security/credentials-management.md` は不在 |

## 期待動作

### Phase 1: 暗黙トリガー発火

- URL アクセス依頼から `credentials-manager` スキルを自動起動

### Phase 2: マッチング

- ドメイン `api.unknown-service.com` で 0 件ヒット

### Phase 3: ユーザに認証情報の有無を確認

- `AskUserQuestion` で「`api.unknown-service.com` 用の認証情報は保存されていません。提供しますか？」を提示
- 選択肢:
  - 「認証情報を提供する」 → 提供されたら save フローへ
  - 「認証なしでアクセス」 → 認証ヘッダなしで API 呼び出し
  - 「キャンセル」 → アクセス中止

### Phase 4: 選択された経路で実行

- ユーザ選択に応じて分岐

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | save 選択時のみ `credentials.json` 更新 |
| 標準出力（要約） | 「認証情報未保存」通知 + ユーザ選択後の動作結果 |
| 終了状態 | ユーザ選択に応じる |

## 分岐の根拠

このケースは「URL 自動マッチ・0 件ヒット」分岐に該当する。**重要**: グローバルルール不在環境でも本スキルが認証情報問い合わせの起点として機能することを検証する。

## 関連ケース

- `case-04_auto_match_single.md`（1 件ヒット時）
- `case-01_save_with_url.md`（保存フローへの遷移先）
