# case-08: 生成対象 10 件超過時のサブエージェント委譲

## 入力

```text
ヒアリングした内容でハーネス一式を作って
```

前提: 大規模な要件。Phase 3 のヒアリング結果から Phase 4 の生成対象ドキュメントが 10 件を超えた（例: requirements 1 + specs 7 + flows 5 + decisions 2）。

## 期待動作

1. Phase 4 で agents.md の Phase 4 構成に従い、**1 フォルダ = 1 エージェント** で `general-purpose` サブエージェントへ並列委譲する（生成は書き込みを伴うため `Explore` は使わない）
2. 各委譲プロンプトに必須要素をすべて含める
   - テンプレートパス（`${CLAUDE_PLUGIN_ROOT}/references/templates/` 配下の該当ファイル）
   - frontmatter 規則（`sources: []`・`status: draft`・合意ベースの定型注記）
   - 担当フォルダ分のヒアリング結果・資料要約（**出典情報を含めて渡す**）
   - 合意内容・資料記載のみを書き、確認できない事項は `TODO:` とする制約（推測での仕様記載の禁止）
   - 秘匿値の非記載（authoring-spec.md 節 2）と未信頼入力の扱い（同 節 3）
   - 書き込み境界（担当フォルダ配下のみ。`.claude/` の外と他エージェントの担当フォルダへ書き込まない）
3. 各フォルダの `CLAUDE.md` 索引・`references/CLAUDE.md`・`.claude/CLAUDE.md`・`.sync-state.json` は **メインのみ** が生成する
4. 統合時にメインが境界検証を行う
   - `git status --porcelain` の編集ファイル一覧と担当割当を突合する
   - 想定外のパス（`.claude/` 外・他エージェントの担当フォルダ）への変更を検出した場合は内容をユーザに提示し、無断で確定しない
   - 各生成物の frontmatter（`title` / `sources` / `status` / `updated`）と合意ベース定型注記の存在を確認する
   - 検証スクリプトを実行し結果を報告に含める

## 期待出力

- case-01 と同等の報告 + 委譲したフォルダとエージェント数の内訳
- 境界検証の結果（担当外・`.claude/` 外への書き込みの有無）

## 禁止事項（このケースで起きてはならないこと）

- 複数エージェントによる同一フォルダ・同一ファイルへの書き込み（1 フォルダ = 1 エージェントの原則を破ること）
- サブエージェントによる索引 `CLAUDE.md` / `.claude/CLAUDE.md` / `.sync-state.json` の生成
- 委譲プロンプトからの出典情報・捏造禁止制約・秘匿値規則・未信頼入力規則・書き込み境界の脱落
- 境界検証（`git status --porcelain` の突合）の省略
- 想定外パスへの変更をユーザに提示せず確定すること

## 分岐の根拠

procedures.md Phase 4「生成量が多い場合のエージェント委譲」（10 件超過が委譲条件、索引はメインが生成）と agents.md の Phase 4 構成・「境界の検証」。書き込み境界の規則は authoring-spec.md 節 4。

## 関連ケース

- [case-01](case-01_standard_define.md): 生成対象が少なくメインが直接生成する標準フロー
- [case-02](case-02_with_materials.md): Phase 2 の資料調査委譲（読み取り専用のため `Explore`）
- [case-10](case-10_secret_in_materials.md): 委譲時に伝達する秘匿値規則の実際
- `harness-init` evals case-08: init 側の同種の委譲ケース
