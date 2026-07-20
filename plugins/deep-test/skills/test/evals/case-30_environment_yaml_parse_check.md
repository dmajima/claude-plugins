<!-- TEST-ORCH-EVAL-ENVPARSE-SENTINEL-v1 -->
# case-30 Phase 1.7 provision 受領後の environment.yaml parse 検証（失敗時の再委譲と縮退）

Phase 1.7 で test-environment の provision を受領した直後に、オーケストレータが `environment.yaml` の YAML parse 可能性を venv の Python（`yaml.safe_load`）で機械確認することを検証する。parse 失敗時は再委譲 1 回 → 環境なし前提への縮退でフローを止めず、venv 不在時は目視確認に縮退することを確認する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動 | フルフロー（Phase 1.7 の provision 委譲が発生する条件下）。対話 / 非対話共通の機械検証 |
| 前提 | Phase 0 で venv 構築済み（PyYAML は共通 requirements.txt に固定）。test-environment の provision が完了し `{base}/{target-slug}/environment.yaml` が返却された直後 |

## 分岐の根拠

`${CLAUDE_SKILL_DIR}/references/flow.md` 6 章 Phase 1.7 節「受領後の parse 検証」（venv Python での safe_load 機械確認・parse 可能性のみ〔値の解釈・スキーマ妥当性の再判定はしない = 生成品質は test-environment の自己チェックの責務〕・失敗は再委譲 1 回〔受領後に本検証を再適用〕→ 環境なし縮退・venv 不在は存在・可読性の目視縮退）・2.1 節 Phase 1.7 行、SKILL.md「権限ポリシー」（Bash の用途に environment.yaml の parse 検証を含む）、`${CLAUDE_SKILL_DIR}/references/state-handoff.md` 2.4（Phase 1.7 受領時の確認・縮退の受け渡し規約）。

## 期待動作

- **主系（段 1・段 2 とも成功 = parse OK）**: 受領直後に venv Python で 2 段確認（段 1: `import yaml` の可用性 / 段 2: `yaml.safe_load` + `encoding='utf-8'` 明示）し、「parse OK」を確認して Phase 2 へ進む（environment.yaml の値の解釈・スキーマ再判定・書き換えは行わない）
- **段 2 失敗 = parse 失敗（副分岐 1）**: test-environment へ provision の再委譲を **1 回だけ** 試み（失敗内容を依頼文脈に含める）、受領後は parse 検証を再適用する。それでも失敗の場合は環境なし前提（従来フロー）へ縮退して続行し、縮退した旨を進捗と報告材料に記録する（フローを止めない・エラー中断しない）
- **段 1 失敗（PyYAML 欠落の壊れた venv）または venv 不在（副分岐 2）**: 機械検証を行えないため、Read によるファイルの存在・可読性の目視確認に縮退する（**parse 失敗〔副分岐 1〕とは振り分けを分ける** = 検証不能を再委譲の無限誘発に使わない。値・キーの妥当性は判定しない粗い代替であり、test-environment の自己チェックを代替しない。venv を Phase 1.7 のためだけに新規構築しない）
- **resume 時（副分岐 3）**: 中断 run の resume（flow.md 5.1 手順 6）で既存 `environment.yaml` を再利用する場合も、`applicability: applicable` 判定の前に本検証を同形で適用する（中断中に破損したマニフェストをそのまま稼働確認に用いない）
- parse 検証の結果を理由に test-environment の成果物（environment.yaml / 派生成果物）を Edit / Write で直接修正しない（生成・更新は test-environment の専有）
- 再委譲は 2 回以上繰り返さない（無限ループ防止）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（検証は読み取りのみ。environment.yaml へ書き込まない） |
| 標準出力(要約) | parse OK: 検証結果 1 行 → Phase 2 継続 / 失敗→縮退時: 縮退の旨と理由の記録 |
| 終了状態 | いずれの分岐でもフローは継続する（parse 失敗が run 全体を中断させない） |

## 関連ケース

- case-25: Phase 1.7 を含むライフサイクル全通（provision → up → 実行 → down の主系）
- case-26: NEEDS REVISION 時の環境維持（環境状態の判断が別軸であることの対比）
- case-27: resume 時の環境再確認（health 再確認は稼働状態の検証・本ケースはマニフェストの parse 可能性の検証という違い）
