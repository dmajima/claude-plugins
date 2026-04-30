# Case 03: フックレビュー（hook-security-team 起動）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`dev-toolkit` プラグインのフック設定をレビュー" |
| 引数 | `dev-toolkit/hooks/hooks.json` |
| フラグ | なし |
| 既存状態 | フック設定が存在 |

## 期待動作

### Phase 1: 対象判定

`hooks.json` → フックレビューモード。

### Phase 2: チーム選定

[`../references/team-selection.md`](../references/team-selection.md) に従い `hook-security-team`（3 名）を採用。

| メンバー | 配布元 | 役割 |
|--------|-------|------|
| `security-engineer` | グローバル | リード（脅威モデル・command 安全性） |
| `implementation-engineer` | グローバル | timeout / パスポータビリティ / 終了コード |
| `infrastructure-engineer` | グローバル | 副作用・パフォーマンス影響 |

### Phase 3: チーム起動 + 機械チェック

[`../../../references/teams/hook-security-team.md`](../../../references/teams/hook-security-team.md) のスポーンプロンプトに従い、3 名を 1 メッセージ内で **並列 Agent 起動**。command フィールドの危険コマンド検出を重点的に実施。

### Phase 4: セキュリティ指摘の扱い

セキュリティ指摘は **必ずユーザ確認** を求める（自動修正対象外）。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 標準出力 | フック毎のセキュリティ評価 + 総合判定 |
| 終了状態 | レビュー完了 |

## 分岐の根拠

対象 = フック → `hook-security-team` 採用。

## 関連ケース

- `case-02_plugin_review.md`（フック含むプラグイン全体レビュー）
