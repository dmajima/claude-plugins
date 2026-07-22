# code-review 達成チェックリスト（オーケストレーター）

`code-review` オーケストレータースキルが **統合サマリを出力する前** に通過すべきルール群。
ID 体系・SSOT は `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` を参照。

> **確認タイミング**: Step 8（統合サマリ出力）の直前。
> **未通過時**: 該当項目を解消してから出力。チェックリスト未通過のままサマリを返却してはならない。

---

## A. Universal ルール（全スキル共通）

> 規範本文・達成基準は **`${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md`** を参照（プラグイン内 SSOT）。
> 適用範囲は `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` セクション8 を参照。

上記 SSOT（`${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` の U マップ表）の U1〜U16 全項目の通過を確認（各 U の 1 行要約・達成基準は同ファイルおよび `universal-rules-{environment,process,quality}.md` を参照）。

---

## B. Coordinator ルール（オーケストレーター固有）

```
[ ] (C1)  Step 0 で標準/簡易モードを確定している（コマンド経由は固定 / 非対話は標準既定）
[ ] (C2)  比較ブランチを origin/develop → main → master の順で自動判定している
[ ] (C3)  Step 4 で観点別スキルを 1 メッセージ内で並列起動している（または Step 4-T）
[ ] (C4)  Agent Teams 採用時は 5 パターンから選定し AskUserQuestion で承認を得ている
[ ] (C5)  Issues / Suggestions / Scope-out の三分類で結果を統合している
[ ] (C6)  Verdict 判定マトリクスに従って Ready/Attention/Work を確定している
[ ] (C7)  template/review-summary.md の 9 セクション + ヘッダブロック順序を厳守し、各 H2 セクションを `<details><summary>` 折り畳み + 内部 HTML 記法で出力している（セクション 1〜3 の summary には件数 + 状態記号（>0 は ⚠ / 0 件は ✓ + 状態語）を付記）
[ ] (C8)  本 PR スコープ外の指摘を「## 3. スコープ外指摘」セクションに分離している
[ ] (C9)  ビルド / Linter / テスト / CVE / PR 差分 / 大規模絞り込みを「## 7. 未確認事項・制約」で明示している
[ ] (C10) 集計セクションに実施日時・モード・参加観点別スキル・比較ブランチ・対象 head SHA・参照規約・件数を記載している
[ ] (C11) Step 2 でプロジェクト規約（CLAUDE.md / .claude/rules/ / .editorconfig 等）を読み込み 2,000 字要約を生成している
[ ] (C12) PR 識別子（URL/ID）を直接処理していない（pr-review からの委譲のみ受領）
[ ] (C13) Step 6 で全指摘・改善提案・スコープ外指摘に Finding ID（`CR-NNN`）を一括採番している
[ ] (C14) Finding ID が統合サマリ全体で連続通番（Issues → Suggestions → Scope-out の順）になっている
[ ] (C15) 各指摘の見出しが HTML 記法（`<h4>CR-NNN: <タイトル></h4>` 等の `<h3>`/`<h4>`）+ サマリー表の ID 列に Finding ID を含む
[ ] (C16) Step 0-P で前回 state.yaml の読み込みを実施している（存在する場合）
[ ] (C17) Step 0-P で inputs フォルダの確認を実施している（未作成時はヒアリングまたはスキップ理由あり）
[ ] (C18) Step 8.5 で state.yaml を生成・保存している（全 finding に detail_summary 記述あり）
[ ] (C19) PR レビュー時、投稿済み全 finding に pr_thread_id が state.yaml に記録されている
[ ] (C20) 提出コードのパターンを規約として無断類推していない（code-trustworthiness.md 遵守）
[ ] (C21) remaining_issues と resolved_since_last に同一 ID が存在しない
[ ] (C22) pr-review から委譲された場合、結果返却が「内部データ」として構成されているか
      （ユーザー向けメッセージとして整形して返却していないか。返却はフロー内部のデータ受け渡しであり、ユーザー対話ではない）
[ ] (C23) Step 2 で language-detection.md に従い言語・FW を検出し、適用プロファイル一覧を適用規約サマリに記録・Step 4 委譲引数 language-profiles で引き渡している
[ ] (C24) Step 5 統合時に信頼度 60 未満の指摘を Issues / Suggestions から除外し、除外件数を集計セクションに記録している（Critical 相当は「要人間確認」として未確認事項に記載）
[ ] (C25) Step 5 でプロファイルアンカー照合を実施し、適用プロファイルのアンカー下限が Medium 以上の指摘を Suggestions（Low）に降格していない（flow.md Step 5「プロファイルアンカー照合」）
```

---

## C. 出力チェック（統合サマリの自動検証案）

Step 8 出力前に以下を検証（ルール ID 判定は A/B 節が担う。ランタイム自動実行はしない）:

- **C-Auto-1**: 必須 9 セクションの `<summary>` 存在（セクション 1〜3 は件数＋状態記号の完全形）
- **C-Auto-2**: 別 PR 推奨・Issue/Work Item 起票等の禁止文言が混入していないこと
- **C-Auto-3**: ヘッダブロック必須項目（レビュー結果 / 対応必須 / 改善提案 / スコープ外 / 実施日時 / 対象 head SHA / レビュー対象 / レビューモード）の存在
- **C-Auto-4**: Finding ID（`CR-NNN`）の重複なし・連続通番・詳細補足 `<h4>` 件数 ≤ 一意 ID 件数

bash 実装案は `${CLAUDE_PLUGIN_ROOT}/skills/pr-review/references/completion-checklist-autocheck-samples.md`（E-1〜E-2.5 と同一方式・自動化検討時のみ Read）を参照。

---

## D. 未通過時の対応

> 本表は頻出の未通過パターンのみを記載（絞り込みは意図的）。記載外の ID はセクション A〜C の該当項目と `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` の達成基準に従って解消する。

| 未通過 ID | 対応 |
|----------|------|
| U7 / U8 | 該当文言を削除 / スコープ外セクションへ移動 |
| C5 / C6 | severity-ranking.md / output-format.md セクション3 の判定マトリクスを再適用 |
| C7 / C8 / C9 | template/review-summary.md に従って見出し・順序を修正 |
| C11 | プロジェクト規約読込を追加実行してから Step 4 をやり直す |
| C16 / C17 | Step 0-P を再実行して state / inputs を読み込む |
| C18 / C19 | state.yaml の不足項目を補完して再書き込み |
| C20 | 該当類推の削除、またはユーザー承認を取得して code_as_reference_decisions に記録 |
| C21 | remaining_issues / resolved_since_last の矛盾を修正 |
| C22 | 返却形式をユーザー向け整形から内部データ形式に修正し、対話的導入文を除去 |

---

## E. 関連リファレンス

- `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` — 全スキルのルール ID 体系
- `${CLAUDE_SKILL_DIR}/references/flow/flow.md` — Step 0-P〜8.5 の実行手順
- `${CLAUDE_SKILL_DIR}/references/output/output-format.md` — 出力フォーマット規範
- `${CLAUDE_SKILL_DIR}/references/template/output/review-summary.md` — 統合サマリテンプレート
- `${CLAUDE_SKILL_DIR}/references/state/state-management.md` — state.yaml 管理
- `${CLAUDE_SKILL_DIR}/references/state/inputs-management.md` — inputs フォルダ管理
- `${CLAUDE_SKILL_DIR}/references/state/code-trustworthiness.md` — コード信頼性原則
- `${CLAUDE_SKILL_DIR}/references/template/state/state_template.yaml` — state.yaml テンプレート
