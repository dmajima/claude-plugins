# case-13: ルート CLAUDE.md の到達性確保（最小スタブ作成 / import 追記）

## 入力

```text
/project-harness:define
```

前提 A: リポジトリルートに `CLAUDE.md` が存在しない（新規プロジェクトの最頻出パス）。
前提 B: リポジトリルートに既存の `CLAUDE.md` がある（手書きの開発メモ等）。

## 期待動作

1. Phase 4 の骨格生成で structure-spec.md 節 10 手順 8（節 4.1）の到達性確保を実施する:
   - 前提 A: `@.claude/CLAUDE.md` の import を含む最小スタブの作成可否を `AskUserQuestion` で確認する
   - 前提 B: 既存内容を残したまま `@.claude/CLAUDE.md` の import 行 1 行を追記する可否を `AskUserQuestion` で確認する（既存記述の削除・要約はしない）
2. 拒否された場合、到達性が未確保である旨と対処方法を報告に含めて続行する（検証スクリプトの検査 2 が NG になるが、承認保留由来の **既知の未達** として区分報告する。authoring-spec.md 節 6.1）
3. 非対話モードではルート `CLAUDE.md` を変更せず、到達性未確保の旨と対処方法を報告に含める

## 期待出力

- 到達性確保の実施有無（スタブ作成 / import 追記 / 見送り）
- 見送り時: 検証結果で検査 2 の NG が「既知の未達（承認保留由来）」として通常の違反と区分されていること

## 禁止事項（このケースで起きてはならないこと）

- ユーザ承認なしでのルート `CLAUDE.md` 作成・変更（`.claude/` 外への書き込みのため承認必須）
- 既存ルート `CLAUDE.md` の記述の削除・要約（追記のみ）
- 散文だけのポインタ（「詳細は .claude/CLAUDE.md を参照」等）での代替（import 記法でなければ読み込みが保証されない）
- 到達性未確保の検査 2 NG を「修正して再実行」で解消しようとして、承認なしにルート `CLAUDE.md` へ書き込むこと

## 分岐の根拠

structure-spec.md 節 4.1（ルート CLAUDE.md からの到達保証）・節 10 手順 8、authoring-spec.md 節 6.1（承認保留由来の既知の未達）。

## 関連ケース

- [case-01](case-01_standard_define.md): 承認して一巡する標準経路（前提 A を含む）
- [case-02](case-02_with_materials.md): 既存資産の取り込み（前提 B と併発しうる）
- `harness-init` evals case-04 / case-13: 姉妹スキルにおける同一分岐（既存時 / 不在時）
