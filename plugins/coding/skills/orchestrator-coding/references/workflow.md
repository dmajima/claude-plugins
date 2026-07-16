# 6 フェーズワークフロー詳細

`orchestrator-coding` の各フェーズの手順・成果物・品質ゲート・遡行規定。

## 0. 共通規定

### 0.1 成果物の配置

セッション作業領域に配置する（リポジトリ配下優先、なければユーザホーム）:

```
.claude/.local/work/{yyyyMMdd_nn_summary}/
├── implementation-plan.md      # Phase 1 成果物
├── impact-analysis.md          # Phase 2 成果物
├── implementation-design.md    # Phase 3 成果物
├── file-list.md                # Phase 4 成果物
├── self-review-result.md       # Phase 5 成果物
├── implementation-report.md    # Phase 6 成果物（最終）
├── inputs/                     # ユーザ提供資料（読み取り専用）
└── workspace/                  # 中間生成物・一時ファイル
```

テンプレートは `../../../references/template/`（SSOT）を使用する。ソースコードの変更はリポジトリへ直接行う（作業領域にはコードを置かない）。

### 0.2 品質ゲート判定（全フェーズ共通）

各フェーズの成果物末尾に以下を必ず出力する:

```markdown
## 品質ゲート判定

- 判定: PASS / FAIL
- 理由: （判定根拠を 1〜3 行）
- SKIPPED 項目: （実施できなかった検証があれば列挙、なければ「なし」）
```

- オーケストレーターはこの判定を読み、PASS なら次フェーズへ、FAIL なら遡行規定に従う
- 判定は各フェーズの実施者（メイン or エージェント）が行い、オーケストレーターは判定内容を書き換えない

### 0.3 遡行規定

| 状況 | 遡行先 |
|------|-------|
| Phase 2 で前提（タスク理解）の誤りが判明 | Phase 1 |
| Phase 3 で分析不足が判明 | Phase 2 |
| Phase 4 で設計の実現不能が判明 | Phase 3 |
| Phase 5 で Critical / High 指摘 | Phase 4（設計起因なら Phase 3） |
| Phase 6 で成果物の欠落を検出 | 該当フェーズ |

- 同一フェーズへの遡行は **最大 3 回**。超過時はユーザに状況（試行内容・残る問題・選択肢）を報告して判断を仰ぐ
- Phase 4 以降からの遡行で実装済みコードを破棄する場合は、破棄範囲をユーザに確認する（非対話モードでは変更を残したまま遡行し、その旨を記録）

### 0.4 クイックモード（簡略化規定）

以下を **すべて** 満たす場合、Phase 2 と Phase 3 を統合し、成果物を `impact-analysis.md` 1 つ（設計セクション込み）に簡略化してよい:

- 変更見込みが 1〜3 ファイル
- 実装方針が一意に定まる（技術選定・構造変更を伴わない）
- 言語・FW 検出と規約解決は **省略しない**（クイックモードでも必須）

Phase 5 のレビューは `impl-reviewer` 1 体に簡略化してよい。Phase 1 / 4 / 6 は省略しない。

クイックモード中に「設計起因」の遡行（0.3 の Phase 5 → Phase 3 相当）が必要になった場合は、統合済みの `impact-analysis.md` の設計セクションを修正して Phase 4 をやり直す。修正の過程でクイックモードの条件（1〜3 ファイル・方針一意）を満たさなくなった場合は、独立した `implementation-design.md` を新規作成して標準モードへ移行し、その旨を成果物に記録する。

## Phase 1: Intake（指示受領）

| 項目 | 内容 |
|------|------|
| 目的 | タスクの正確な理解と作業単位への分解 |
| 入力 | ユーザのタスク説明（テキスト / 参照ファイル / URL） |
| 成果物 | `implementation-plan.md`（`../../../references/template/implementation-plan.md`） |

手順:

1. セッション作業領域を作成する（`0.1` の構造）
2. タスク説明を読み、目的・完了条件・制約を整理する
3. 不明点・複数解釈があれば `AskUserQuestion` で確認する（非対話モードでは最も保守的な解釈を採用し、その判断を成果物に記録）
4. タスクを作業単位に分解し、実施順序を決める
5. ブランチ方針を確認する（現在のブランチで作業してよいか。デフォルトブランチ上なら新規ブランチ作成を提案）

品質ゲート観点: タスクの完了条件が明文化されているか / 分解された作業単位に漏れがないか。

## Phase 2: Analyze（分析）

| 項目 | 内容 |
|------|------|
| 目的 | 言語・FW・規約の確定と影響範囲の把握 |
| 入力 | implementation-plan.md |
| 成果物 | `impact-analysis.md`（`../../../references/template/impact-analysis.md`） |

手順:

1. **言語・FW 検出**: [language-detection.md](../../../references/language-detection.md) に従い適用言語スキルを確定する（[skill-index.md](../../../references/skill-index.md)）
2. **規約解決**: [conventions-resolution.md](../../../references/conventions-resolution.md) に従い適用規約サマリを生成する
3. **影響範囲調査**: 変更対象と依存関係（呼び出し元 / 参照先 / テスト / 設定）を Grep / Glob で追跡する。調査量が多い場合は `Explore` 系サブエージェントに委譲し、結果の要約のみ取り込む
4. **技術制約の把握**: 適用言語スキル（`references/conventions.md`）のツールチェーン（ビルド / テスト / Lint コマンド）が対象環境で利用可能か確認する。利用不可の場合は SKIPPED として記録

品質ゲート観点: 言語・FW 検出結果と適用規約サマリが記録されているか / 影響範囲に主要な依存の漏れがないか。

## Phase 3: Design（設計）

| 項目 | 内容 |
|------|------|
| 目的 | 実装方針の確定とリスクの事前評価 |
| 入力 | impact-analysis.md |
| 成果物 | `implementation-design.md`（`../../../references/template/implementation-design.md`） |

手順:

1. 実装方針（変更アプローチ・データフロー・エラーハンドリング方針）を確定する。設計観点・データフロー原則は [design-principles.md](../../../references/design-principles.md)（SSOT）に従い、言語のコード構造・FW 構造規約は適用言語スキルの references を参照する
2. 変更ファイルリスト（新規 / 修正 / 削除）を作成する
3. リスクと対応策を列挙する（分類と標準対応は [design-principles.md](../../../references/design-principles.md) 節 2）
4. **大規模・高リスク判定**: [design-principles.md](../../../references/design-principles.md) 節 2.3 の判定基準に該当する場合、`architect` エージェントに設計レビューを依頼し、指摘を反映する（[agents.md](agents.md)）
5. 複数の実装方針が拮抗する場合は、推奨案と根拠を添えて `AskUserQuestion` で確認する

品質ゲート観点: 変更ファイルリストが影響範囲と整合しているか / リスクへの対応が方針に含まれているか。

## Phase 4: Implement（実装）

| 項目 | 内容 |
|------|------|
| 目的 | 規約準拠の実装とローカル検証 |
| 入力 | implementation-design.md + 適用規約サマリ |
| 成果物 | コード変更（リポジトリ直接）+ `file-list.md`（`../../../references/template/file-list.md`） |

手順:

1. 設計の変更ファイルリストに従って実装する。実装量が大きい場合は `code-implementer` エージェントに委譲する（適用規約サマリと設計をプロンプトに含める。[agents.md](agents.md)）
2. **規約準拠**: 適用規約サマリの全項目に従う。迷った場合は適用言語スキルの `references/conventions.md` を参照する
3. **既存ファイルの編集規律**: 元ファイルのエンコーディング・改行コードを維持する。周辺コードのスタイル（コメント密度・命名・イディオム）に揃える
4. **ローカル検証**: 適用言語スキルのツールチェーンで検証する（ビルド → Lint → フォーマット確認 → 関連テスト実行）。コマンドは規約サマリに記録されたものを使用する
5. 変更したファイルと変更概要を `file-list.md` に記録する

品質ゲート観点: ビルド / Lint が通過したか（実行不能なら SKIPPED 明記）/ 変更が設計のファイルリストの範囲内か（範囲外変更が必要になった場合は理由を記録）。

## Phase 5: Self-Review（自己レビュー）

| 項目 | 内容 |
|------|------|
| 目的 | 独立した視点による品質検証 |
| 入力 | file-list.md + 適用規約サマリ + implementation-design.md |
| 成果物 | `self-review-result.md`（`../../../references/template/self-review-result.md`） |

手順:

1. `impl-reviewer`（実装品質・規約準拠）と `test-engineer`（テスト十分性・回帰リスク）を **並列** 起動する（[agents.md](agents.md)）
2. レビュー対象は file-list.md 記載のファイルに限定する。適用規約サマリをプロンプトに含め、**規約準拠の判定基準を規約サマリに固定** する
3. 指摘を統合し、重大度（Critical / High / Medium / Low）で分類する
4. Critical / High があれば Phase 4 へ遡行して修正する（設計起因なら Phase 3 へ）。Medium / Low は対応可否を判断し、未対応分は残課題として記録する
5. 修正後は指摘該当箇所の再レビューを行う（全件再レビューは不要）

品質ゲート観点: Critical / High 指摘が 0 件か / 未対応の Medium / Low が残課題として記録されているか。

## Phase 6: Report（報告）

| 項目 | 内容 |
|------|------|
| 目的 | 成果の集約と最終検証 |
| 入力 | 全フェーズ成果物 |
| 成果物 | `implementation-report.md`（`../../../references/template/implementation-report.md`） |

手順:

1. 変更概要・検証結果・残課題・後続推奨アクションを implementation-report.md に集約する。遡行が発生していた場合は「遡行」という内部用語のまま書かず、経緯を平易な言葉に変換して変更概要に含める（例:「レビューで設計の不足が見つかったため、設計を見直して再実装しました」）
2. **機密情報チェック**: 全成果物を Grep で走査する（`password` / `token` / `secret` / `Bearer ` / `sk-` / `AKIA` / `Server=` + パスワード様文字列 / PEM ヘッダ / メールアドレス形式）。検出時は該当値を `***` にマスクする
3. ユーザへ報告する（変更ファイル・検証結果・残課題の要約 + セッション作業領域の絶対パス）。コミット・PR 作成は指示があるまで行わない

品質ゲート観点: 全フェーズの成果物が揃っているか / 機密チェックが完了したか。
