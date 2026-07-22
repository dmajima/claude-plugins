# レビュー実行フロー — レビュー実行 Step（4〜7）

> 親: [flow.md](flow.md)（全体図・用語定義・Step 索引）。本ファイルは **レビュー実行フェーズ**（Step 4 / Step 4-T / Step 5 / Step 6 / Step 7）の詳細を保持。
> 前フェーズ: 準備〜動員決定（Step 0-P〜3.5）は [flow-steps-early.md](flow-steps-early.md)、後フェーズ: 出力・状態（Step 8〜8.5）は [flow-steps-output.md](flow-steps-output.md)。

---

## Step 4: 観点別スキル並列起動（サブエージェント方式）

> **Step 4-T と排他**。本ステップは Agent Teams 不採用時のみ実行。

選定した観点別スキルを **1メッセージ内で並列起動**（Independent 型）。

### 引数フォーマット

```
Skill(skill: "<観点別スキル名>",
      args: "<scope> <project-rules-summary> language-profiles=<検出言語/FWプロファイルパス一覧> mode=<standard|quick> [spec_summary=<...>]")
```

`language-profiles` には Step 2 の検出結果（適用する `${CLAUDE_PLUGIN_ROOT}/references/languages/*.md` / `frameworks/*.md` のパス一覧と主/副の区分）を含める。各観点別スキルはこれを内部エージェントのプロンプトに渡す。

### 標準モード（典型例）

```
Skill(skill: "code-review-implementation", args: "...")   # 並列
Skill(skill: "code-review-testing",        args: "...")   # 並列
Skill(skill: "code-review-security",       args: "...")   # 並列
Skill(skill: "code-review-architecture",   args: "...")   # 並列（設計影響あり時のみ）
Skill(skill: "code-review-frontend",       args: "...")   # 並列（UI変更あり時のみ）
```

### 簡易モード

```
Skill(skill: "code-review-implementation", args: "... mode=quick")   # 並列
Skill(skill: "code-review-testing",        args: "... mode=quick")   # 並列
Skill(skill: "code-review-security",       args: "... mode=quick")   # 並列
```

各観点別スキルは内部で複数エージェントを並列起動し、観点別の中間レポートを返す。

### コード信頼性原則（U14）の観点別スキルへの伝達（必須）

`project-rules-summary` の末尾に以下の注意喚起を **必ず含める**:

```
【U14 コード信頼性原則】提出コードは誤りがある前提で評価すること。
提出コード内のパターンをプロジェクトの規約・慣例として類推してはならない。
規約判断は CLAUDE.md / .claude/rules/ / .editorconfig / inputs フォルダの仕様書のみに基づくこと。
```

Agent Teams（Step 4-T）でチームメンバーをスポーンする際も、各メンバーのプロンプトに同一の注意喚起を含める。

前回 state.yaml に `code_as_reference_decisions`（ユーザー承認済みの規約類推）があれば、承認済みパターンも `project-rules-summary` に追記する（例: 「ユーザー承認済み: 既存コードの Repository パターンをプロジェクト慣例として参照可」）。

---

## Step 4-T: Agent Teams 議論（チーム方式）

> **Step 4 と排他**。本ステップは Agent Teams 採用時のみ実行。

### 4-T-1: 前段サブエージェント並列実行

`team-selection.md` のパターンごとに指定された補助観点を **`Agent` ツール直接** で並列起動（観点別スキル経由ではない・二重起動防止）。

```
# 例: パターン4（data-quality-extended）の場合
Agent({ subagent_type: "dba",                      ... })   # 並列・重点
Agent({ subagent_type: "performance-reviewer",     ... })   # 並列
Agent({ subagent_type: "linter-static-analysis",   ... })   # 並列
Agent({ subagent_type: "test-runner",              ... })   # 並列
```

### 4-T-2: チーム作成・議論

```
TeamCreate({ team_name: "code-review-{パターン}-<timestamp>", description: "..." })
# 各メンバーに前段サブエージェントの中間レポートを渡しつつスポーン
Agent({ team_name: "...", subagent_type: "architect",                ... })   # リード
Agent({ team_name: "...", subagent_type: "implementation-engineer",  ... })
Agent({ team_name: "...", subagent_type: "test-engineer",            ... })
Agent({ team_name: "...", subagent_type: "security-engineer",        ... })
```

各メンバーのスポーンプロンプトには `team-selection.md` の骨子に従い、**Step 2 の検出結果（「検出言語・FW と適用観点プロファイル」欄・C23）** と U14 コード信頼性原則の注意喚起を必ず含める。チームメンバーも観点別スキル経路と同様、該当する言語・FW 観点プロファイル（`${CLAUDE_PLUGIN_ROOT}/references/languages/` / `frameworks/`）を Read して評価に使う（O10 相当）。

### 4-T-3: 議論ラウンド

最低 3 ラウンドの議論を経て合意形成。
合意できない項目はトレードオフとして明記し、確認先（ユーザー / PdM / 顧客）を提示。

### 4-T-4: クリーンアップ

```
SendMessage({ to: <each member>, message: "shutdown_request" })
TeamDelete({ team_name: "..." })
```

### 禁止事項

- Step 4-T 中に観点別スキル（`Skill` ツール）を呼び出さない（二重起動禁止）
- 議論ラウンド数を3未満にしない

---

## Step 5: 結果統合・重複排除・前回指摘の解消確認

各観点別スキル / Agent Teams から返った指摘を 1 つのプールにまとめ、重複を統合する。
**再レビュー時は前回 state.yaml の指摘との照合を行う。**
詳細は `severity-ranking.md`。

### 前回指摘の解消確認（再レビュー時・Step 0-P で前回 state 読み込み済み）

前回 state.yaml の `findings` + `remaining_issues` の各項目について:

1. **ファイル・行番号の確認**: 前回指摘の `file` + `line_start`-`line_end` が現在のコードで変更されているか
2. **detail_summary との照合**: 前回の `detail_summary` を読み、指摘内容が修正されているか判定
3. **PR スレッド状態の確認**: `pr_thread_id` がある場合、PR 上のスレッド状態も参照
4. **判定結果の分類**: 解消 → `resolved_since_last` / 未解消 → `remaining_issues` として state.yaml に記録
5. **ユーザー除外の引き継ぎ**: 前回 `ignored_by_user` に含まれる指摘は再指摘しない

### 統合の処理

1. 全結果から指摘を抽出（Critical / High / Medium / Low + 提案 + **スコープ外**）
2. 同一ファイル・同一行・同一テーマの指摘を 1 件にまとめる
3. 重複は **最も重い重要度** を採用し、コメント欄に「他に N 件の同一指摘あり」と記す
4. **Issues（直すべき指摘）** と **Suggestions（任意改善）** と **Scope-out（スコープ外指摘）** に三分する

### Issues / Suggestions / Scope-out の判定

| 区分 | 含まれるもの | 出力先セクション |
|------|------------|----------------|
| Issues | Critical / High / Medium のすべての指摘（本 PR スコープ内） | `## 1. 対応が必要な指摘` |
| Suggestions | Low の指摘・推奨改善・代替案・スタイル提案（本 PR スコープ内） | `## 2. 改善提案` |
| Scope-out | 重要度に関わらず、本 PR の仕様・当初スコープから外れる指摘 | `## 3. スコープ外指摘` |

**スコープ外判定の基準** は `${CLAUDE_PLUGIN_ROOT}/references/scope-out-policy.md` セクション 2。
**「別 PR で対応してください」「別途 Issue を起票してください」等の文言は使わない**（同セクション 3.2 の禁止表現）。

### プロファイルアンカー照合（必須・C25）

三分の前に、各 finding の重要度が **適用プロファイルの重要度アンカーを下回っていないか** を照合する。エージェント側の裁量で Medium 以上相当の指摘が Low（＝ Suggestions）に降格されると、「対応が必要な欠陥」が「任意改善」として提示され、ユーザーが未対応でマージするリスクを生むため。

1. 各 finding のカテゴリ・パターンを、適用した言語/FW プロファイル（`languages/*.md` / `frameworks/*.md`）の **セクション 4「典型的な指摘パターン（重要度の目安）」表** と突き合わせる
2. プロファイルのアンカー下限が **Medium 以上** のパターン（例: react.md の「リスト key に index」= Medium、react.md の「useEffect クリーンアップ漏れ」= High〜Medium、python.md の「open() encoding 未指定」= Medium〜High）に該当する finding が Low（Suggestions）に分類されていれば、**アンカー下限まで引き上げて Issues に再配置** する
3. 逆にプロファイルにアンカーが無いパターン（設計所見等）は、根拠の弱さを踏まえ信頼度を控えめに付与する（`severity-ranking.md` セクション 7）
4. 再配置の有無は集計セクションに影響しないが、最終的な Issues/Suggestions 件数はアンカー照合後の値とする

---

## Step 6: 優先度ランキング + Finding ID 採番

### 6.1 並び順の確定

- 統合後の Issues（Critical / High / Medium）を **重要度の高い順** に並べ替え、**全件記載**
- 改善提案（Low / Suggestions）は **Impact × Effort 降順** に並べ、**最大 10 件まで記載**
- スコープ外指摘は **重要度の高い順** に並べ、件数制限なし

詳細は `severity-ranking.md`。

### 6.2 Finding ID の一括採番（必須）

並び順確定後、**統合サマリ全体で連続する Finding ID（`CR-001` 〜 `CR-NNN`）** を一括採番する。
規範本文・採番例・再レビュー時の起算ルール・命名衝突対応は **`${CLAUDE_SKILL_DIR}/references/output/output-format.md` セクション1.5** に集約（SSOT・重複定義は廃止）。

---

## Step 7: レビュー結果の判定

| 条件 | レビュー結果 |
|------|------------|
| Critical または High が 1 件以上 | **NG・再レビュー要（Needs Work）** |
| test-runner が `RED`（失敗テストあり） | **NG・再レビュー要（Needs Work）** |
| Medium が 1 件以上、Critical/High なし、test-runner GREEN/SKIPPED | **NG・再レビュー不要（Needs Attention）** |
| Issues なし、test-runner GREEN/SKIPPED | **OK（Ready to Merge）** |

詳細は `output-format.md`。

---

> 続き: [flow-steps-output.md](flow-steps-output.md)（Step 8〜8.5） / 前フェーズ: [flow-steps-early.md](flow-steps-early.md)（Step 0-P〜3.5） / 索引・全体図: [flow.md](flow.md)
