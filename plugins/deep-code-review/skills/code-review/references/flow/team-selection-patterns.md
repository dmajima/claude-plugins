# Agent Teams 選定: パターン定義（セクション 2 / セクション 5）

> **索引（親）**: [team-selection.md](team-selection.md)
> 本ファイルは `code-review` の Agent Teams 選定パターンの詳細サブファイル。
> **セクション 2（パターン定義・パターン1〜5）** と **セクション 5（パターン早見表）** を収録する。
> 選定フロー図・排他/コスト前提（セクション 0）・共通運用ルール（セクション 3）・
> フォールバック条件（セクション 4）・将来拡張（セクション 6）は
> 索引および [team-selection-flow.md](team-selection-flow.md) を参照。

---

## 2. パターン定義

### パターン1: quality-assurance（標準的な品質総合レビュー）

| 項目 | 内容 |
|------|------|
| ベース | **既存チーム**（`~/.claude/rules/claude/agent-teams.md` で定義済み） |
| リード | `architect` |
| メンバー | `implementation-engineer` / `test-engineer` / `security-engineer` |
| 人数 | 4 名 |
| 起動条件 | 標準モード かつ 大規模変更（10ファイル超 or 1,000行超）または 複数観点に跨る変更 |
| 議論ラウンド | 最低 3 回 |
| 前段サブエージェント | `linter-static-analysis` / `performance-reviewer` / `dependency-safety` / `test-runner`（並列実行・結果をチームに渡す） |
| 想定コスト | 通常レビューの約 4〜6 倍（4 メンバー独立インスタンス + 議論ラウンド） |

#### スポーンプロンプトの骨子

```text
コード変更を品質次元（実装正確性・テスト網羅性・セキュリティ・アーキテクチャ整合性）から多角的に議論するチームを作成してください。
メンバー構成:
- architect エージェントをリードとして、品質評価フレームワークの提示・合意形成を担当
- implementation-engineer がコード品質・実装正確性を評価
- test-engineer がテストカバレッジ・エッジケース・回帰リスクを評価
- security-engineer がセキュリティ品質を評価

対象差分: {{差分要約}}
プロジェクト規約サマリ: {{project-rules-summary}}
検出言語・FW と適用観点プロファイル: {{language-profiles（Step 2 の検出結果。各メンバーは該当プロファイル（${CLAUDE_PLUGIN_ROOT}/references/languages/ 等）を Read して評価に使用する）}}
仕様書サマリ: {{spec-summary または「未指定」}}
前段サブエージェントの結果: {{linter / performance / dependency / runner の中間レポート}}

品質次元間のトレードオフを含む最低3回の議論ラウンドを経て、
品質評価結果と改善方針を優先度・工数見積付きでレポートにまとめてください。
```

---

### パターン2: security-compliance（セキュリティ・コンプライアンス重視）

| 項目 | 内容 |
|------|------|
| ベース | **既存チーム**（agent-teams.md 定義済み） |
| リード | `security-engineer` |
| メンバー | `implementation-engineer` / `legal-advisor` / `infrastructure-engineer` |
| 人数 | 4 名 |
| 起動条件 | 認証/認可変更、決済処理、個人情報取り扱い、外部公開 API、OSS ライセンス追加・破壊的変更 |
| 議論ラウンド | 最低 3 回（攻撃シナリオの相互検証含む） |
| 前段サブエージェント | `dependency-safety`（脆弱性スキャン）/ `linter-static-analysis` / `dba`（DB絡む場合） |
| 想定コスト | 約 4〜6 倍（議論ラウンド込み） |

#### スポーンプロンプトの骨子

```text
セキュリティ・コンプライアンスの総合評価を行うチームを作成してください。
メンバー構成:
- security-engineer をリードとして、脅威モデルの作成・対策方針の合意形成を担当
- implementation-engineer が実装上のセキュリティ対策を評価
- legal-advisor が法的リスク・コンプライアンス（個人情報保護法・OSSライセンス等）を評価
- infrastructure-engineer がインフラ・ネットワーク層の防御を評価

対象差分: {{差分要約}}
変更内容のセキュリティ的特徴: {{認証変更/決済処理/PII等の分類}}
検出言語・FW と適用観点プロファイル: {{language-profiles（Step 2 の検出結果。各メンバーは該当プロファイルのセキュリティ観点を Read して評価に使用する）}}
前段スキャン結果: {{dependency-safety の脆弱性スキャン結果}}

攻撃シナリオの相互検証を含む最低3回の議論ラウンドを経て、
脅威一覧と対策方針を優先度付き（Critical/High/Medium/Low）でレポートにまとめてください。
```

---

### パターン3: system-design（大規模設計変更レビュー）

| 項目 | 内容 |
|------|------|
| ベース | **既存チーム**（agent-teams.md 定義済み） |
| リード | `architect` |
| メンバー | `implementation-engineer` / `security-engineer` / `project-leader` |
| 人数 | 4 名 |
| 起動条件 | 大規模リファクタリング、コンポーネント境界変更、DI/状態管理刷新、技術スタック変更、依存方向の変更 |
| 議論ラウンド | 最低 3 回 |
| 前段サブエージェント | `linter-static-analysis` / `performance-reviewer` / `test-runner` |
| 想定コスト | 約 4〜6 倍（議論ラウンド込み） |

#### スポーンプロンプトの骨子

```text
システムの設計変更について多角的に議論するチームを作成してください。
メンバー構成:
- architect をリードとして、設計案の提示・合意形成を担当
- implementation-engineer が実装実現性・既存コードへの影響を評価
- security-engineer がセキュリティリスク（攻撃面の変化・認可境界）を評価
- project-leader がスコープ・スケジュール影響・依存タスクを評価

対象差分: {{差分要約}}
既存アーキテクチャ概要: {{architecture-summary}}
プロジェクト規約サマリ: {{project-rules-summary}}
検出言語・FW と適用観点プロファイル: {{language-profiles（Step 2 の検出結果。各メンバーは該当プロファイル（${CLAUDE_PLUGIN_ROOT}/references/languages/ 等）を Read して評価に使用する）}}

最低3回の議論ラウンドを経て、合意形成された設計方針をレポートにまとめてください。
合意に至らない項目はトレードオフとして明記し、確認先（ユーザー/PdM/顧客）を提示してください。
```

---

### パターン4: data-quality-extended（DB変更主体の品質レビュー）

| 項目 | 内容 |
|------|------|
| ベース | パターン1 (quality-assurance) を流用 + DB 観点を前段強化 |
| リード | `architect` |
| メンバー | `implementation-engineer` / `test-engineer` / `security-engineer` |
| 人数 | 4 名 |
| 起動条件 | DB スキーマ変更、マイグレーション、ストアドプロシージャ変更、大量データクエリ追加、トランザクション境界変更 |
| 議論ラウンド | 最低 3 回 |
| 前段サブエージェント | **`dba`（重点）** / `performance-reviewer` / `linter-static-analysis` / `test-runner` |
| 想定コスト | 約 4〜6 倍（チーム・議論ラウンド込み）+ 前段サブエージェント |

#### 前段サブエージェントの強化

`dba` の中間レポートを **重点情報** としてチームに渡す。論点:
- スキーマ変更の安全性（NOT NULL 追加の互換性、既存データ整合性）
- マイグレーション戦略（オンライン/オフライン、ロールバック手順）
- インデックス設計（クエリプラン影響）
- ロック・デッドロックリスク
- データ移行時間の見積もり

チーム内では impl/test/sec が dba 結果を踏まえて議論する（例: マイグレーション中のロックがアプリケーションタイムアウトを起こさないか、データ移行スクリプトのテスト戦略、移行データへの不正アクセス防止）。

---

### パターン5: frontend-quality-extended（フロントエンド主体の品質レビュー）

| 項目 | 内容 |
|------|------|
| ベース | パターン1 (quality-assurance) を流用 + フロントエンド観点を前段強化 |
| リード | `architect` |
| メンバー | `implementation-engineer` / `test-engineer` / `security-engineer` |
| 人数 | 4 名 |
| 起動条件 | 大規模UI変更、Vue.js コンポーネント設計刷新、Liquid/DotLiquid テンプレート再構築、アクセシビリティ要件強化、フロントエンドビルド設定変更 |
| 議論ラウンド | 最低 3 回 |
| 前段サブエージェント | **`web-designer`（重点）** / `linter-static-analysis` / `test-runner` |
| 想定コスト | 約 4〜6 倍（チーム・議論ラウンド込み）+ 前段サブエージェント |

#### 前段サブエージェントの強化

`web-designer` の中間レポートを **重点情報** としてチームに渡す。論点:
- HTML セマンティクス・CSS 設計の妥当性
- アクセシビリティ（WCAG 2.2 AA）違反
- Liquid / DotLiquid テンプレートのロジック肥大化・null 安全性・XSS 観点
- レスポンシブ対応・ブラウザ互換性
- Vue.js コンポーネント分割粒度

チーム内では impl/test/sec が web-designer 結果を踏まえて議論する（例: テンプレート XSS の影響範囲、Vue コンポーネントのテスト戦略、UI 変更によるバックエンド契約への影響）。


---

## 5. パターン早見表

| 適用シーン | パターン | リード | メンバー | 前段サブエージェント |
|-----------|---------|-------|---------|------|
| 標準的な大規模レビュー | quality-assurance | arch | impl + test + sec | linter / perf / dep / runner |
| 認証/決済/PII/外部API/OSS追加 | security-compliance | sec | impl + legal + infra | dep / linter / dba（DB絡む場合） |
| 大規模設計変更・技術選定 | system-design | arch | impl + sec + pl | linter / perf / runner |
| DB変更主体 | data-quality-extended | arch | impl + test + sec | **dba（重点）** + linter / perf / runner |
| FE変更主体 | frontend-quality-extended | arch | impl + test + sec | **web-designer（重点）** + linter / runner |


---

> **選定フロー・運用ルール**: [team-selection-flow.md](team-selection-flow.md)
> **索引に戻る**: [team-selection.md](team-selection.md)
