# case-10: .gitignore の 2 段階検査

## 入力

```text
/project-harness:init
```

前提: 対象プロジェクトの `.gitignore` に `.claude/` が記載されており、ハーネス本体が git 管理対象外になる。`.claude/.local/` の記載はない。

## 期待動作

1. Phase 4 の gitignore 検査 1 段階目で `git check-ignore -q .claude/CLAUDE.md` によりハーネス本体が無視されることを検出する
2. `!.claude/CLAUDE.md` / `!.claude/references/` の否定パターン追加を AskUserQuestion で提案する
3. 承認時: `.gitignore` へ否定パターンを追記する（`.claude/` 外への書き込みのためユーザ承認必須）
4. 拒否時: 「ローカル専用ハーネスとして運用され、チームで同期状態を共有できない」旨を報告に明記する
5. 2 段階目で `.claude/.local/` の追記を提案する
6. 非対話モード: いずれも実施せず、検出結果と対処方法を報告のみとする

## 期待出力

- ハーネス本体が無視されている旨の警告と提案内容
- 承認結果に応じた実施内容、または未実施の理由

## 禁止事項（このケースで起きてはならないこと）

- `.gitignore` の無確認変更
- ハーネス本体が無視されている状態を検出せずに完了報告すること（チーム展開時まで破綻が露見しない）

## 分岐の根拠

procedures.md Phase 4「gitignore 検査（2 段階）」。`.sync-state.json` を git 管理対象として共有する前提（sync-spec.md 節 1）が成立するかの検査であり、通常フロー（case-01）では 2 段階目のみが動く。

## 関連ケース

- [case-01](case-01_standard_init.md): `.claude/` が無視されていない標準フロー
