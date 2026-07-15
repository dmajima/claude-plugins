# エージェント運用定義（設計ワークフロー）

`orchestrator-design` が利用するサブエージェントと起動定義。
エージェント定義本体はプラグインの `agents/` に同梱されている。起動プロンプトの必須要素・結果の取り込み方は `orchestrator-coding` の [agents.md](../../orchestrator-coding/references/agents.md) と同一の運用とする。

## このスキルで使用するエージェント

| ID | subagent_type | 役割 | 主なツール |
|----|---------------|------|----------|
| arch | `coding:architect` | 設計妥当性・構造・技術的負債のレビュー（読み取り専用） | Read, Grep, Glob |

設計ワークフローはコード変更を行わないため、実装系エージェント（`code-implementer`）・実装レビュー系（`impl-reviewer` / `test-engineer`）は使用しない。

## フェーズ定義

### Phase 2: Analyze — 現状構造調査の委譲（任意）

- 実行エージェント: 汎用探索エージェント（`Explore` 等の read-only 系）
- 目的: 既存アーキテクチャ・依存関係の調査が大量になる場合の委譲
- 入力: 設計対象の候補パス・シンボル名
- 出力: 現状構造の要約（層構造・境界・依存の説明）
- 起動条件: 3 回以上の探索が見込まれる場合。少量ならメインが直接調査する

### Phase 3: Design — 設計レビュー（条件付き）

- 実行エージェント: arch（単体）
- 目的: 設計の構造妥当性・リスク網羅の検証
- 入力: implementation-design.md + impact-analysis.md の絶対パス + 適用言語スキルの references パス一覧
- 出力: 設計レビュー結果（指摘 + 重大度 + 総合判定）
- 起動条件: [design-principles.md](../../../references/design-principles.md) 節 2.3 の大規模・高リスク判定に該当する場合。非該当でも複数案の比較検証が必要な場合は起動してよい
- 指摘の反映: Critical / High は設計を修正して再レビュー（該当箇所のみ）。Medium / Low は採否を判断し記録する
