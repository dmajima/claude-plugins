# case-12: .gitignore の 2 段階検査（ハーネス本体の無視を検出）

## 入力

```text
/project-harness:define
```

前提: 対象プロジェクトの `.gitignore` に `.claude/` を丸ごと無視するパターンが既に存在する（または `.claude/.local/` の登録が無い）。

## 期待動作

1. Phase 4 の骨格生成で structure-spec.md 節 10 手順 7 の gitignore 検査（2 段階）を実施する:
   - 段階 1: `git check-ignore -q .claude/CLAUDE.md` でハーネス本体が無視されていることを検出し、`!.claude/CLAUDE.md` / `!.claude/references/` の否定パターン追加を **ユーザ承認のうえ** 提案する
   - 段階 2: `.claude/.local/` が `.gitignore` に含まれない場合、追記を提案する
2. 段階 1 で拒否された場合、「ローカル専用ハーネスとして運用され、チームで同期状態を共有できない」旨を報告に明記して続行する
3. ハーネス本体が無視されたままの場合、Phase 6 の初回コミット（コミット 0 件時）では `.claude/` 配下がステージできないため、その影響（state の同期基準を確立できない）もあわせて報告する
4. 非対話モードでは `.gitignore` を変更せず、検出結果と対処方法の報告のみ行う

## 期待出力

- gitignore 検査の結果（段階 1 / 2 それぞれの検出と提案・承認結果）
- 拒否時: ローカル専用ハーネスとなる旨の注意

## 禁止事項（このケースで起きてはならないこと）

- ユーザ承認なしでの `.gitignore` 変更（`.claude/` 外への書き込みのため承認必須）
- ハーネス本体が無視されていることを検出せずに生成・コミットへ進むこと（コミットしたつもりで何も追跡されない事故）
- 非対話モードでの `.gitignore` 自動変更

## 分岐の根拠

structure-spec.md 節 10 手順 7（gitignore 検査 2 段階。両スキル共通の骨格生成順序）と、harness-define SKILL.md 重要な制約「ルート `CLAUDE.md`・`.gitignore`・`git init`・初回コミットはユーザ承認を経る」。

## 関連ケース

- [case-01](case-01_standard_define.md): 検出なしで素通りする標準経路
- [case-06](case-06_no_commits_first_commit.md): 初回コミットの承認ゲート（本ケースの段階 1 拒否はコミット可否に影響する）
- `harness-init` evals case-10: 姉妹スキルにおける同一検査
