# case-02 仕様書指定あり（spec= と spec_divergence 検出）

`spec=` 引数で仕様書が指定されたケース。仕様書を情報源に加え、主要ルート / ルールを実装と粗く突合して `spec_divergence` を材料化することを検証する。乖離は材料化に留め、ケース追加等の決定はしない。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=orderapp-web 対象説明=./ spec=docs/requirements/spec.md base=<base>` |
| 起動形態 | 委譲（オーケストレータ `test` から Skill ツール経由） |
| 前提 | `docs/requirements/spec.md` に要件 ID・主要ルート / ルールを含む仕様書が存在 / リポジトリソースは full で取得可 / `diff=` 指定なし |

## 分岐の根拠

SKILL.md「前提」の引数表（`spec=` は仕様書パス）・「実行フロー」3〜4・「検証」（`spec=` 未指定時に spec_divergence を出力しない、の適用）、references/procedures.md 4.12 章（仕様乖離検出・`spec=` 指定時のみ・突合で確証が持てない事項は open_questions へ）・6.1 章（`meta.spec_provided` の反映）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-analysis.md` 13 章（spec_divergence[] の spec_ref / code_ref / finding / confidence・未指定時は非出力）・3 章（`meta.spec_provided`）、同 `agents.md` 4.3 章（共通注入事項）。

## 期待動作

- 委譲で `target-slug=` を受領しているため slug の解決フロー・確認は行わない
- `docs/requirements/spec.md` を Read で読解する（ディレクトリ指定時は Glob で列挙）。`meta.spec_provided: true` を設定する
- full のコードベース解析（責務 1〜12）に加え、主要ルート / ルールを仕様と粗く突合し、乖離を `spec_divergence[]` に `spec_ref`（節番号・仕様位置）/ `code_ref`（`file:line`）/ `finding` / `confidence` で記録する
- 突合で確証が持てない事項は断定せず `confidence: low` とするか `open_questions` へ回す（捏造禁止）
- 乖離検出は材料化に留め、どのケースを追加すべきか等の **決定はしない**（決定は test-design の責務。hint を越えない）
- `diff=` 未指定のため `change_impact` を出力しない
- source-analyst 自己チェックのプロンプトに仕様への参照を含める（skill agents.md Phase 2 の入力・plugin agents.md 4.3 章の共通注入事項）
- target-analysis.md の概要に情報源として仕様書パスを記録し、「仕様乖離」章を追加する

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `{target-slug}/analysis.yaml`（`meta.spec_provided: true`・`spec_divergence[]` に spec_ref / code_ref / finding / confidence）・`{target-slug}/target-analysis.md`（概要に仕様書パス・「仕様乖離」章）。change_impact は出力しない。test-results.yaml / test-cases.yaml / test-plan.md へは書き込まない |
| 標準出力（要約） | 解析結果サマリに加え、spec_divergence の検出件数と、突合できなかった事項の open_questions 列挙 |
| 終了状態 | source-analyst 自己チェック後に材料 2 ファイルを返却。乖離は材料化のみで、決定は test-design へ委ねる |

## 関連ケース

- case-01: `spec=` なし（spec_divergence を出力しない側）
- case-03: `diff=` 指定（change_impact 側の入力オプション分岐）
