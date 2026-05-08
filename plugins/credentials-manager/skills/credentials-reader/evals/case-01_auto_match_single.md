# Case 01: URL アクセス時の自動マッチ（1 件ヒット）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "https://api.openai.com/v1/models から取得して。" |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | `credentials.json` に `openai-api-key`（domains=`["api.openai.com"]`、auth_method=`header:Authorization:Bearer`）が 1 件保存済み |
| グローバルルール | **`~/.claude/rules/security/credentials-management.md` は不在** |

## 期待動作

### Phase 1: 暗黙トリガー発火

- ユーザが認証情報を明示提供していないが、URL アクセス依頼を検出
- `credentials-reader` スキルの description により AI が自動トリガー判定し本スキルを起動
- グローバルルールが不在でも description の Use when 条件で起動する

### Phase 2: マッチング

- リクエストドメイン `api.openai.com` を `credentials[].domains` と完全一致比較
- `openai-api-key` が 1 件ヒット

### Phase 3: 自動適用

- `auth_method: header:Authorization:Bearer` に従い `Authorization: Bearer <full-value>` を WebFetch / API 呼び出しに付与
- ユーザに通知: "Stored credential 'openai-api-key' (sk-p****f456) was automatically applied for api.openai.com."

### Phase 4: API 呼び出し実行

- 認証情報を付けて `https://api.openai.com/v1/models` を取得

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（読み取りのみ、`credentials-manager` への引き継ぎなし） |
| 標準出力（要約） | 自動適用通知 + API レスポンス |
| 終了状態 | 成功 |

## 分岐の根拠

「URL 自動マッチ・1 件ヒット」分岐に該当。グローバルルール不在でも description のトリガー条件により発火することを検証する。

## 関連ケース

- `case-02_auto_match_multiple.md`（複数件ヒット時の選択依頼）
- `case-03_auto_match_none.md`（0 件時の保存提案 → manager 引き継ぎ）
