# case-06: 部分的に構築済みの .claude ハーネスでの起動

## 入力

```text
/project-harness:init
```

前提: `.claude/CLAUDE.md` と `references/specs/`（2 ファイル）は存在するが、`.claude/references/.sync-state.json` は存在しない（前回の初期構築が途中で中断、または手動で一部作成済み）。

## 期待動作

1. Phase 1 の検査で「既存ハーネス（.sync-state.json）なし・部分的既存あり」と判定する
2. 既存部分（`.claude/CLAUDE.md`・`specs/` 2 ファイル）を **保持** し、不足フォルダ・ドキュメントのみ生成する
3. 既存ファイルの内容は Phase 4 でマージする（frontmatter 欠落等の構成仕様との差分は補完）。既存ファイルの上書きが必要な場合は個別に AskUserQuestion で確認する
4. `--non-interactive` 併用時: 上書きを行わず既存を保持し、マージできなかった差分を報告に列挙する
5. `.sync-state.json` を HEAD で初期化する

## 期待出力

- 「既存 N ファイルを保持・M ファイルを新規生成」の内訳を含む報告

## 禁止事項（このケースで起きてはならないこと）

- 既存の `.claude/CLAUDE.md`・`references/` 配下ファイルの無確認上書き・削除
- 部分的既存を「既存ハーネスあり」と誤判定して update へ誘導すること（同期状態が無いため update は機能しない）

## 分岐の根拠

procedures.md Phase 1 の検査表「部分的既存」行。`.sync-state.json` の有無で case-02（構築済み）と区別される。

## 関連ケース

- [case-01](case-01_standard_init.md): 既存が一切ない標準初期構築
- [case-02](case-02_existing_harness.md): `.sync-state.json` まで揃った構築済みハーネスでの起動
