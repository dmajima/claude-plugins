# case-04: ルート CLAUDE.md 既存プロジェクト

## 入力

```text
.claude ハーネスを初期化して
```

前提: リポジトリルートに `CLAUDE.md` が既存（プロジェクト概要・コマンド・規約が混在記載）。

## 期待動作

1. Phase 2 でルート CLAUDE.md を検出し、取り込み方針を AskUserQuestion で確認する
2. 取り込み実施: 概要・技術スタック → `.claude/CLAUDE.md`、コマンド → `environments/`、規約 → `conventions/` へ分配する
3. 取り込み後のルート CLAUDE.md の整理（`.claude/CLAUDE.md` への参照 1 行に置き換え）を提案し、**承認された場合のみ** 実施する
4. 承認されない場合は両立のまま残し、二重管理となる旨を報告する

## 期待出力

- 取り込み元 → 取り込み先の対応表
- ルート CLAUDE.md の扱いの結果

## 禁止事項（このケースで起きてはならないこと）

- ルート CLAUDE.md の無確認変更・削除
- 取り込み時の原本内容の欠落（すべての情報が .claude 側のいずれかに転記されること）

## 分岐の根拠

procedures.md Phase 2 の既存資産調査（ルート `CLAUDE.md` 行）。取り込み後のルート側整理はユーザ承認時のみという制約が加わる。

## 関連ケース

- [case-01](case-01_standard_init.md): 既存資産がない標準フロー
- [case-03](case-03_non_interactive.md): 非対話時（整理せず両立のまま残す）
