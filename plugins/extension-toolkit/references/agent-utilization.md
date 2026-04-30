# エージェント活用ルール（SSOT）

メインコンテキストの圧迫を避けるため、Claude Code が提供するサブエージェント・専用機能を積極的に活用するルール。

## 1. 基本原則

| 原則 | 内容 |
|-----|------|
| メインは判断・統合・対話 | コンテキスト容量を保持 |
| 探索・解析・実装はエージェント | 結果のみメインに集約 |
| 既存ツールを優先 | 新規エージェント定義より既存機能 |

## 2. ツール選定の判断フロー

```
何をしたいか？
  ├─ ファイルを単純に読む / 1 回のパターン検索
  │   └─ Read / Grep / Glob を直接利用
  │
  ├─ 複数回のファイル探索 / 「どこに X があるか」を調査
  │   └─ Explore エージェント（Task ツールで subagent_type="Explore"）
  │
  ├─ 多段階の実装計画
  │   └─ Plan エージェント（subagent_type="Plan"）
  │
  ├─ 多角的なレビュー（並列）
  │   └─ 役割別エージェント（implementation-engineer / architect 等）を並列起動
  │
  ├─ コードレビュー（統合的）
  │   └─ code-reviewer エージェント
  │
  ├─ 自由形式の調査・実装タスク
  │   └─ general-purpose エージェント
  │
  └─ 専門領域のレビュー（議論・合意形成が必要）
      └─ エージェントチーム（最低 3 名、観点少なければ緩和）
```

## 3. Explore エージェントの活用

### 3.1 適用場面

| 場面 | 適用 |
|-----|------|
| 「{機能} はどこに実装されているか」 | Explore（quick） |
| 「3 種類の関連ファイルを横断的に確認」 | Explore（medium） |
| 「複数の命名パターンで広く検索」 | Explore（very thorough） |
| 1 ファイルだけ読む | 直接 Read |
| 1 つのキーワードを検索 | 直接 Grep |

### 3.2 利用例

```text
Agent({
  description: "Find auth middleware",
  subagent_type: "Explore",
  prompt: "Locate the authentication middleware in this codebase. Search common naming patterns (auth, middleware, security). Report the file path(s) and a 1-line summary of each. Search breadth: medium."
})
```

### 3.3 Explore を使わない場面

| 場面 | 代替 |
|-----|------|
| コードレビュー（読み込み窓制限あり） | implementation-engineer 等の専門エージェント |
| 設計書の詳細監査 | architect エージェント |
| 多ファイル横断の整合性チェック | general-purpose（必要に応じてサブエージェント並列） |

## 4. メインで実行 vs エージェント委譲の判断

| 行為 | 推奨 |
|-----|------|
| 1〜3 ファイルの Read | メイン直接 |
| 4 ファイル以上の探索 | Explore エージェント |
| 大量のファイル変更 | 計画は Plan、実行は general-purpose |
| パターンマッチ系の検索 | メイン Grep（特定済の場合） / Explore（複数試行が必要な場合） |
| Bash 一括処理（grep / find / wc） | メイン Bash 直接 |
| 数値計算・整形が必要な処理 | Python スクリプト |
| 並列のレビュー | 専門エージェント並列起動 |

## 5. レビュー時の専門家分散

「レビュー」を 1 つの汎用エージェントに集約せず、**観点ごとに専門家を分散** する。

### 5.1 グローバル専門家エージェント（`~/.claude/agents/`）

`~/.claude/agents/` 配下にプロジェクト横断の専門家エージェントが定義されている場合、まずそれを利用する。例:

| ID | 領域 |
|----|------|
| `implementation-engineer` | コード品質・正確性 |
| `architect` | 設計・技術選定 |
| `security-engineer` | セキュリティ |
| `test-engineer` | テスト・evals |
| `ux-designer` | UX |
| `legal-advisor` | 法務 |
| `infrastructure-engineer` | インフラ |
| `dba` | データ層 |

### 5.2 プラグイン同梱専門家エージェント

プラグイン特有の観点（プラグイン特性に依存する評価）には、プラグイン同梱の専門家エージェントを定義して使う。例:

| ID（例） | 領域 |
|--------|------|
| `extension-structure-reviewer` | プラグイン・スキル構造の妥当性 |
| `extension-evals-reviewer` | evals 網羅性・形式 |
| `extension-marketplace-reviewer` | マーケットプレイス整合・命名衝突 |

### 5.3 専門家を集めたチーム

複数観点が必要なレビューでは、専門家を集めた **エージェントチーム** を組成する。

| チーム名 | 構成 | 適用 | 定義ファイル |
|---------|------|-----|-----------|
| `plugin-review-team` | architect（リード）+ plugin-structure-reviewer + implementation-engineer + evals-coverage-reviewer + marketplace-fit-reviewer + security-engineer（フック含有時のみ） | プラグイン横断レビュー（5〜6 名） | [`../teams/plugin-review-team.md`](../teams/plugin-review-team.md) |
| `skill-review-team` | plugin-structure-reviewer（リード）+ implementation-engineer + evals-coverage-reviewer | スキル単体レビュー（3 名） | [`../teams/skill-review-team.md`](../teams/skill-review-team.md) |
| `hook-security-team` | security-engineer（リード）+ implementation-engineer + infrastructure-engineer | フック安全性レビュー（3 名） | [`../teams/hook-security-team.md`](../teams/hook-security-team.md) |
| （例）`gender-perspective-team` | male-perspective-reviewer + female-perspective-reviewer | 観点が 2 つに固定（最低 3 名規則の例外、本プラグインでは未定義） | — |

## 5.5 単独並列起動するエージェント

一部の専門家エージェントはチーム内に組み込むと議論ラウンドで他観点と混ざり、専門評価の独立性が損なわれる。これらは **チームの外で単独並列起動** する運用とする。

| エージェント | 単独並列が望ましい理由 |
|------------|-------------------|
| `description-trigger-reviewer` | description は AI 自動トリガー判定に直結する独立した評価軸であり、構造・実装の議論と混ぜないほうが評価が明瞭 |

`extension-reviewer` がこれらを起動する際は、対象に応じて主たるチームと **同じメッセージ内で並列起動** する:

```text
Agent({ subagent_type: "{lead}", prompt: "（チームスポーンプロンプト）" })       # 並列（チーム）
Agent({ subagent_type: "{member-1}", prompt: "..." })                       # 並列（チーム）
Agent({ subagent_type: "{member-2}", prompt: "..." })                       # 並列（チーム）
Agent({ subagent_type: "description-trigger-reviewer", prompt: "..." })     # 並列（単独）
```

結果統合時にチーム結果と単独結果を同一フォーマットで集約する。

## 6. チームサイズの原則

| 原則 | 内容 |
|-----|------|
| 標準 | 最低 3 名（リード含む） |
| 例外（下限） | 観点が 2 つしか想定できない場合は 2 名でも可（理由を team 定義に明記） |
| 例外（上限） | プラグイン全体レビュー（フック含有時の `plugin-review-team`）は 6 名まで許容 |
| 最大 | 標準 5 名、例外条項該当時 6 名（議論調整コストの上限） |

## 7. 並列起動と逐次起動の使い分け

| 場面 | 推奨 |
|-----|------|
| 独立した観点のレビュー | 並列（同一メッセージで複数 Agent 呼び出し） |
| 前段の結果が必要な処理 | 逐次（前段完了後に次を呼ぶ） |
| 議論・合意形成 | チーム編成（並列 + 中間集約） |

## 8. メインコンテキスト圧迫を避ける具体策

| 策 | 内容 |
|---|------|
| 大量ファイル読み込みは Explore に委譲 | 読み込み量をエージェント側に閉じる |
| 探索の中間結果を要約させる | エージェントが「結果サマリ」を返す前提でプロンプト設計 |
| 自由探索より具体的な指示 | 「X を探して、結果を 3 行で報告」のような明示 |
| Plan / general-purpose / Explore を場面で使い分け | 用途別に最適なエージェント選択 |
| 不要な再読込を避ける | 1 度読んだファイルはメインで覚える |

## 9. アンチパターン

| パターン | 問題 | 代替 |
|---------|------|------|
| メインで 10 ファイルを順次 Read | コンテキスト圧迫 | Explore で一括調査 + 要約 |
| 大量の grep 結果をそのまま保持 | コンテキスト圧迫 | grep をエージェントに委譲 + サマリ取得 |
| すべて general-purpose で実行 | 専門性活用できない | 適切な専門エージェント選択 |
| すべて単独レビュー | 観点抜け | 専門家チームで多角化 |

## 10. 関連ルール

| 用途 | ファイル |
|-----|---------|
| 専門家エージェント・チーム設計 | [`../skills/agent-toolkit/references/team-design.md`](../skills/agent-toolkit/references/team-design.md) |
| レビュー観点 | [`../skills/extension-reviewer/references/review-perspectives.md`](../skills/extension-reviewer/references/review-perspectives.md) |
| グローバルルール | `~/.claude/rules/claude/agent-architecture.md` / `~/.claude/rules/claude/agent-teams.md` / `~/.claude/rules/claude/agent-usage.md` |

## 11. 禁止事項

- メインで全作業を完結させようとしてコンテキストを圧迫すること
- 専門エージェント不在の領域で general-purpose を選択せず手動実行すること
- 並列実行可能なレビューを逐次で実行すること（時間効率の浪費）
- 観点抜けが想定されるレビューを 1 名のエージェントだけで実施すること
