# case-13: ルート CLAUDE.md が無いプロジェクトでの到達性確保

## 入力

```text
/project-harness:init
```

前提: リポジトリルートに `CLAUDE.md` が存在しない（新規導入プロジェクト）。

## 期待動作

1. Phase 2 でルート `CLAUDE.md` の不在を検出する
2. ハーネス入口への到達性を確保するため、最小スタブの作成を AskUserQuestion で提案する（structure-spec.md 節 4.1）
3. 承認時: 以下の内容でルート `CLAUDE.md` を作成する

   ```markdown
   # <project-name>

   プロジェクトの概要・技術スタック・ドキュメント体系は `.claude/CLAUDE.md` を参照する。

   @.claude/CLAUDE.md
   ```

4. 拒否時 / 非対話モード: 作成せず、「ハーネス入口への到達性が未確保である」旨と対処方法を報告に含める
5. Phase 6 の検証スクリプトが到達性の有無を判定し、結果を報告に反映する

## 期待出力

- スタブ作成の提案と実施結果（または未実施の理由）
- 検証スクリプトの項目 2（到達性）の結果

## 禁止事項（このケースで起きてはならないこと）

- ルート `CLAUDE.md` の無確認作成（`.claude/` 外への書き込みのため承認必須）
- 散文だけのポインタ（「詳細は .claude/CLAUDE.md 参照」）で済ませること（読み込みが保証されない）

## 分岐の根拠

structure-spec.md 節 4.1「ルート CLAUDE.md からの到達保証」の不在パス。既存 CLAUDE.md がある case-04 とは動作（新規作成 vs 追記）が異なる。

## 関連ケース

- [case-04](case-04_existing_claude_md.md): ルート CLAUDE.md が既存の場合（import 行の追記）
- [case-03](case-03_non_interactive.md): 非対話モードの基本挙動
