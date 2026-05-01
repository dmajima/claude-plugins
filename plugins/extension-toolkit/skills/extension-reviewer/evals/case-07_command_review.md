# Case 07: コマンドレビュー（専用チームなし、個別エージェント 4 名並列）

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

### Phase 2: 個別エージェント選定（標準 4 名）

コマンド対象は **専用チームを設けない**（観点が限定的なため）。[`../references/review-perspectives.md`](../references/review-perspectives.md) セクション 3 と [`../references/team-selection.md`](../references/team-selection.md) に従い、以下 4 名を並列起動する:

| エージェント | 配布元 | 観点 | 省略可否 |
|------------|-------|------|--------|
| `plugin-structure-reviewer` | プラグイン同梱 | 規約準拠 | 必須 |
| `description-trigger-reviewer` | プラグイン同梱 | description のトリガー精度 | 必須 |
| `implementation-engineer` | グローバル | プロンプト構造・ルーティング | 必須 |
| `security-engineer` | グローバル | 実行コマンド・スクリプトの危険性 | 任意（外部実行・危険操作なしなら省略可） |

最低 3 名（必須エージェント）を確保。`security-engineer` 省略時は 3 名、含める標準時は 4 名構成。

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
