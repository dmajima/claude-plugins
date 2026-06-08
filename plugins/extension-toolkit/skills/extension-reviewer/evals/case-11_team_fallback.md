# Case 11: チーム機能不可環境でのフォールバック起動

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`code-formatter` スキルをレビュー" |
| 引数 | `code-formatter` |
| フラグ | なし |
| 環境 | `TeamCreate` ツール **利用不可**（システムリマインダ・利用可能ツール一覧に未掲載） |

## 期待動作

### Phase 1: 対象判定

`SKILL.md` 含むディレクトリを検出 → スキルレビューモード。

### Phase 2: 起動方式判定（フォールバック検知）

[`../references/team-selection.md`](../references/team-selection.md) の「フォールバック起動」節に従い、`TeamCreate` 利用可否を判定。
利用不可と判定した場合、フォールバック経路に切り替える（[`../../../references/guides/agent-utilization.md`](../../../references/guides/agent-utilization.md) の 6.1 章 ADR-017 準拠）。

### Phase 3: チーム定義の抽出

[`../../../references/teams/skill-review-team.md`](../../../references/teams/skill-review-team.md) を Read し、以下を抽出:

| 抽出項目 | 値 |
|---------|----|
| リード | `plugin-structure-reviewer` |
| メンバー | `implementation-engineer` / `evals-coverage-reviewer` |
| スポーンプロンプト | チーム定義末尾の「スポーンプロンプト」セクション |

### Phase 4: 個別並列起動

`TeamCreate` を使わず、`Agent` ツールでメンバーを **同一メッセージ内に複数並列呼び出し**:

```text
Agent({ subagent_type: "plugin-structure-reviewer",
        prompt: "（規約準拠観点）" })          # 並列
Agent({ subagent_type: "implementation-engineer",
        prompt: "（実装可能性観点）" })         # 並列
Agent({ subagent_type: "evals-coverage-reviewer",
        prompt: "（evals 網羅性観点）" })       # 並列
```

機械チェック（[`../references/automated-checks.md`](../references/automated-checks.md)）も並行実行。

### Phase 5: 結果統合（メイン Claude が手動）

チーム機能の自動統合機構が無いため、メイン Claude が:

- 各メンバーの結果を Critical / High / Medium / Low に再分類
- 矛盾指摘があればユーザに提示
- 議論ラウンドの代用として、矛盾・補強要望があれば再依頼で最大 3 ラウンドまで実施
- 総合判定を [`../references/review-perspectives.md`](../references/review-perspectives.md) の判定ルールに従って算出

### Phase 6: 引き渡し（フォールバック明記）

| 結果 | 接続先 |
|-----|-------|
| Critical/High なし | `marketplace-publisher` への接続を提案 |
| Critical/High あり | 該当 `*-toolkit` への接続を提案 |

報告冒頭に「**チーム機能（TeamCreate）が利用不可の環境のため、Agent 並列起動で代替実行しました**」を明記。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 標準出力 | フォールバック実行の明示 + 各メンバー結果 + 統合判定 + 次のアクション提案 |
| 終了状態 | レビュー完了（実体は同等観点をカバー） |

## 分岐の根拠

`TeamCreate` 利用不可 → ADR-017 のフォールバック経路を選択。
チーム定義は SSOT として機能するため、メンバー構成・スポーンプロンプトは正規に取得可能。

## 関連ケース

- `case-01_skill_review.md`（チーム機能利用時の標準フロー）
- `case-02_plugin_review.md`（プラグイン横断、フォールバック時は 5〜6 名並列）
- `case-03_hook_review.md`（フック、フォールバック時は 3 名並列）
