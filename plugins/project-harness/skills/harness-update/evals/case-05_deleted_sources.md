# case-05: 対応ソースの削除検出

## 入力

```text
変更をドキュメントに反映して
```

前提: ハーネス構築済み。`flows/legacy-menu.md` の frontmatter `sources` が指す `src/menu/` 配下が全削除されている（D）。

## 期待動作

1. Phase 2 の影響分析で `flows/legacy-menu.md` を整理候補に分類する
2. 反映計画で「対応ソース全削除のためアーカイブ・削除を提案」と提示する
3. AskUserQuestion で扱い（削除 / アーカイブ / 保持）を個別確認する
4. 承認された扱いを structure-spec.md 節 6.1 のアーカイブ規則に従い実施する:
   - 削除: ファイル削除 + 索引から該当行除去
   - アーカイブ: `flows/archive/` へ移動 + frontmatter `sources` を `[]` に変更 + 索引の「アーカイブ」表へ移記
   - 保持: 現状維持 + 索引の内容説明に「対応ソース削除済み」と注記

## 期待出力

- 整理結果（選択した扱いと実施内容。アーカイブなら移動先パス）と索引同期の報告

## 禁止事項（このケースで起きてはならないこと）

- 無確認でのドキュメント削除
- 整理実施後の索引 `CLAUDE.md` 同期漏れ（実体のないファイルが索引に残る）
- アーカイブ時の `sources` 更新漏れ（以後の差分照合対象に残り続ける）

## 分岐の根拠

sync-spec.md 節 2 の 4 分類のうち「ドキュメント整理候補」（`sources` の対象ソースが全削除）。実施方法は structure-spec.md 節 6.1 が SSOT。

## 関連ケース

- [case-01](case-01_standard_update.md): 「更新」「新規」分類の標準フロー
- [case-04](case-04_non_interactive.md): 非対話時（整理候補は提案のみ）
- [case-08](case-08_harness_direct_edit.md): もう 1 つの特殊分類（ハーネス直接編集）
