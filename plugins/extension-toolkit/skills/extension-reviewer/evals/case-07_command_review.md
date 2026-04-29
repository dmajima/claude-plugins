# Case 07: コマンドレビュー（スキルチーム + description-trigger-reviewer 単独並列）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`/extension` コマンドをレビュー" |
| 引数 | `commands/extension.md` |
| フラグ | なし |
| 既存状態 | コマンドファイル単体 |

## 期待動作

### Phase 1: 対象判定

`commands/{name}.md` 単体 → コマンドレビューモード。

### Phase 2: チーム + 個別エージェント選定

[`../references/team-selection.md`](../references/team-selection.md) に従う。コマンド対象は **専用チームを設けない**（観点が限定的なため）。代わりに以下を並列起動:

| エージェント | 配布元 | 観点 |
|------------|-------|------|
| `plugin-structure-reviewer` | プラグイン同梱 | 規約準拠 |
| `description-trigger-reviewer` | プラグイン同梱 | description のトリガー精度 |
| `security-engineer` | グローバル | 実行コマンド・スクリプトの危険性 |
| `implementation-engineer` | グローバル | プロンプト構造・ルーティング |

3 名以上の並列起動を最低条件とし、コマンドの性質に応じてメンバーを増減する。

### Phase 3: 並列起動 + 機械チェック

選定したエージェントを 1 メッセージ内で **並列 Agent 起動**。description 文字数チェック、ルーティング先スキルの存在確認等を機械チェックで実施。

### Phase 4: 結果統合 + 引き渡し

通常の統合 → 優先度付け → 次アクション提案。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 標準出力 | エージェント別の指摘 + 統合レビュー結果 + 総合判定 |
| 終了状態 | レビュー完了 |

## 分岐の根拠

対象 = コマンド単体（専用チームなし、個別エージェントの並列起動）。

## 関連ケース

- `case-01_skill_review.md`（スキル単体、`skill-review-team`）
- `case-02_plugin_review.md`（プラグイン横断、`plugin-review-team`）
