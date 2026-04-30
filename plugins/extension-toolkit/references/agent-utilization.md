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
メンバー詳細・人数・役割の正典は各チーム定義ファイル側に置く（SSOT）。

| チーム名 | 用途 | 定義ファイル（メンバー詳細はこちら） |
|---------|------|-----------|
| `plugin-review-team` | プラグイン横断レビュー | [`teams/plugin-review-team.md`](teams/plugin-review-team.md) |
| `skill-review-team` | スキル単体レビュー | [`teams/skill-review-team.md`](teams/skill-review-team.md) |
| `hook-security-team` | フック安全性レビュー | [`teams/hook-security-team.md`](teams/hook-security-team.md) |
| （例）`gender-perspective-team` | 観点が 2 つに固定の場合の参考例（本プラグインでは未定義） | — |

### 5.4 単独並列起動するエージェント

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

### 6.1 チーム機能が利用できない環境でのフォールバック（ADR-017 準拠）

エージェントチーム（`TeamCreate` / Agent Teams 機能）は Claude Code の特定バージョン・特定環境でのみ利用可能。利用できない環境では **Agent ツール（subagent_type 指定）でメンバーを個別並列起動** することで同等のレビュー体験を提供する。

#### 6.1.1 利用可否の判定

| 観点 | 判定方法 |
|-----|---------|
| `TeamCreate` ツール提供 | システムリマインダ・利用可能ツール一覧に `TeamCreate` が含まれるか |
| ユーザ環境の制限 | ユーザから「チーム機能を使わない」と明示された場合 |
| トークンコスト判断 | チームメンバー独立インスタンスのコストを抑えたい場合（フォールバックは Agent サブエージェントなのでメインコンテキスト消費は発生するがインスタンス分離なし） |

#### 6.1.2 フォールバック手順

| ステップ | 動作 |
|---------|------|
| 1 | 起動対象チーム（例: `skill-review-team`）の定義ファイルを Read |
| 2 | チーム情報テーブルから「リード」「メンバー（リード以外）」を抽出 |
| 3 | スポーンプロンプトを Read してメンバー別観点を抽出 |
| 4 | 各メンバーを `Agent` ツールで **並列起動**（同一メッセージ内に複数呼び出し） |
| 5 | 各エージェントの結果をメインに集約（チームの議論ラウンドはメイン Claude が役割を兼ねる） |
| 6 | 統合判定を [`../skills/extension-reviewer/references/review-perspectives.md`](../skills/extension-reviewer/references/review-perspectives.md) の「総合判定ルール」に従って算出 |

#### 6.1.3 並列起動の例

`skill-review-team`（3 名）をフォールバックで起動する例:

```text
Agent({ subagent_type: "plugin-structure-reviewer",
        prompt: "（team 定義のスポーンプロンプト・規約準拠観点）" })   # 並列
Agent({ subagent_type: "implementation-engineer",
        prompt: "（procedures の実装可能性観点）" })                   # 並列
Agent({ subagent_type: "evals-coverage-reviewer",
        prompt: "（evals 網羅性観点）" })                              # 並列
```

#### 6.1.4 チーム機能との差分

| 観点 | チーム機能あり | フォールバック |
|-----|------------|------------|
| メンバー間直接通信 | 可能（独立インスタンスが SendMessage で議論） | 不可（メイン Claude が結果を統合する） |
| 議論ラウンド | TeamCreate が管理 | メイン Claude が役割兼任（最低 3 ラウンドの「再依頼」で代用） |
| トークンコスト | 各メンバー独立インスタンス分 | メイン + サブエージェント、議論なし分は軽量 |
| 結果統合 | 自動（チーム機能内） | メイン Claude が手動 |
| 適用範囲 | 議論・反論・合意形成が必要 | 観点並列レビューのみで足りる場合 |

#### 6.1.5 フォールバック使用時の注意

- **議論ラウンドが省略される** ため、メンバー間の反論・補強による品質向上は期待できない。重要な判断（公開判定・セキュリティ審議）ではチーム機能が利用可能な環境での実施を推奨する
- メイン Claude が複数視点を取り込む際、結果統合の偏りに注意（特に矛盾指摘の扱い）
- フォールバック使用時はその旨をユーザへの最終報告に明記する（「チーム機能不可のため Agent 並列起動で代替」等）

#### 6.1.6 適用先

`extension-reviewer` のチーム起動を前提とするレビューケース全般に対し、本フォールバックを適用することで同じ観点をカバーできる。具体的なケースとフォールバック起動方法は [`../skills/extension-reviewer/references/team-selection.md`](../skills/extension-reviewer/references/team-selection.md) の「フォールバック起動」節を参照。

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
