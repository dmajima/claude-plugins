# case-04 PR description からの期待挙動推論（委譲・仕様書/外部リンクなし）

仕様書（`spec=`）も外部リンクもなく、PR description の自然言語情報のみから期待挙動を推論する委譲起動ケース。description 単独の推論と、外部 fetch が発生しないことを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `spec` なし / PR description あり（構造化見出しを含む）/ 外部リンクなし / `fetch-external` 未指定（既定 `ask`） |
| モード | 委譲呼び出し（pr-review Step 3.5 から Skill ツール経由・対話） |

## 分岐の根拠

SKILL.md「責務」「トリガー条件」（pr-review Step 3.5 / code-review から委譲され、PR の自然言語情報〈description〉から期待挙動サマリを生成）、SKILL.md「実行モード判定」（本スキルは **委譲起動のみ**・対話 UI は持たない）、SKILL.md「ステップ詳細」Step 1 の優先順位 2「PR description の構造化見出し」、`${CLAUDE_SKILL_DIR}/references/expected-behavior.md` セクション 1（入力の優先順位・優先 2: PR description）・セクション 2.1（構造化された見出しの抽出）・セクション 2.2（自由記述の解析）、references/checklist.md セクション B の I1 / I5。

> **差別化**: 本ケースは `spec=` も外部リンクも持たない **description 単独** の委譲推論（外部 fetch 不発生）を検証する。`spec=` 明示の決定的根拠採用は case-01、外部リンクを伴う推論委譲は case-05 が扱う。

## 期待動作

- `pr-review` Step 3.5 から委譲され、対話 UI（AskUserQuestion）を出さずに非対話で期待挙動サマリを生成する（SKILL.md「実行モード判定」＝委譲起動のみ）
- Step 1: PR description を情報源として収集し、優先度 2（構造化見出し）として扱う（I1・expected-behavior.md セクション 1 表）
- expected-behavior.md セクション 2.1 の見出しパターン（`## 概要` / `## 要件` / `## 期待挙動` / `## 受入条件` 等）直下の本文を抽出し、requirements / acceptance_criteria を構築する
- 見出しがない場合は description 全体を自然言語として解析し「変更点」「目的」「Why」を抽出する（expected-behavior.md セクション 2.2）
- `spec=` と外部リンクが入力にないため、Step 2 の外部 fetch は発生せず、fetch 候補提示（承認 UI）も行われない（承認 UI 自体は呼び出し元 pr-review の責務・expected-behavior.md セクション 0.1）
- 期待挙動サマリ（expected_behavior_summary）を含む 5 フィールド構造（expected_behavior_summary / requirements / acceptance_criteria / conflicts / sources_used）の出力 JSON で返却する（I5）
- sources_used に description-section エントリを type / priority 付きで列挙する（I1・checklist セクション C の C-Auto-3）
- Write / Edit は使用せず、推論結果の出力のみでファイル変更を行わない（SKILL.md 権限ポリシー・重要な制約）

## 関連ケース

- case-01: 仕様書明示（`spec=` 最高優先）— 決定的根拠が存在する対比
- case-05: 外部リンク付き PR での推論委譲（外部 fetch を伴う対比）
