# case-11 複雑度計測ツール利用可（radon / lizard 等で hotspots を measured: true 実数値化）

複雑度計測ツール（radon / lizard 等）が対象環境に導入済みで read-only 実行できるケース。procedures.md 4.3 章の if 側（ツール有時に循環的複雑度を実測）を検証する。既存ケースは全て `measured: false` 側のため、本ケースで `measured: true` + 実数値 + churn 併記の経路（**実測複雑度 × churn で高リスク Top N**）を確認する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `対象説明=./ target-slug=orderapp-web base=<base>` |
| 起動形態 | 委譲（オーケストレータ `test` から Skill ツール経由） |
| 前提 | 対象環境に複雑度計測ツール（例: Python の radon / 多言語の lizard）が導入済みで read-only 実行可能 / リポジトリソースは full で取得可 / `spec=` `diff=` 指定なし |

## 分岐の根拠

SKILL.md 責務 3（循環的複雑度〔計測ツール有時のみ〕× git churn で高リスク Top N を特定・ツール無しは `measured: false`）・「前提」（`test-setup` から複雑度 / カバレッジツール情報を受領。無ければ自力検出）・frontmatter の allowed-tools（存在時のみ `Bash(radon *)` / `Bash(lizard *)` を利用）、references/procedures.md 4.3 章（循環的複雑度は存在する read-only ツールが利用可能な場合のみ計測し、複雑度〔ツール有時〕× churn で `HS-{3桁}` を抽出。利用不可なら `null` + `measured: false`）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-analysis.md` 7 章（hotspots の `cyclomatic_complexity` は計測時 integer・`measured: true`）、同 `execution-policy.md` 2 章（実行手段が有る場合は実測し、無い場合のみ SKIPPED）、同 `agents.md` 4.3 章（共通注入事項）。

## 期待動作

- source_availability を full と判定する
- `test-setup`（Phase 1）から複雑度計測ツールの検出結果を受領していれば用い、無ければ自力で存在確認する（SKILL.md 前提）
- 複雑度計測ツール（radon / lizard 等）が利用可能なため、read-only で実行し循環的複雑度を実測する（frontmatter に列挙された `Bash(radon *)` / `Bash(lizard *)` は存在時のみ利用）
- hotspots の `cyclomatic_complexity` に実測の整数値を設定し、`measured: true` とする（既存ケースの `measured: false` + `null` と対になる分岐）
- churn は従来どおり Bash の git 読み取りで取得し、**実測複雑度 × churn で高リスク Top N** を `HS-{3桁}` として抽出する。`rationale` に実測複雑度と churn の根拠を記す
- 計測できたのは複雑度であり、他の未計測・未確認事項（例: 計測ツールが解析対象外とした言語 / ファイル）は引き続き `measured: false` / `open_questions` で誠実に扱う（全項目を `measured: true` にしない・捏造しない）
- risk_register は実測複雑度を `likelihood_basis` の complexity 根拠に反映する。`suggested_focus` は hint に留める（決定は test-design）
- `spec=` `diff=` 未指定のため `spec_divergence` / `change_impact` を出力しない
- source-analyst 自己チェックで `measured: true` 箇所の数値と根拠の整合（`measured: false` の誠実な併用を含む）を確認させ、重大指摘を反映する
- read-only に徹し（計測ツールは read-only 実行のみ）test-results.yaml / test-cases.yaml / test-plan.md へ書き込まない。**カバレッジの実測はしない**（責務外・test-run-unit 拡張）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `{target-slug}/analysis.yaml`（hotspots に `cyclomatic_complexity: <整数>` + `measured: true`・実測複雑度 × churn の rationale・`source_availability: full`）・`{target-slug}/target-analysis.md`（ホットスポット Top N を measured 実測の別付きで記載）。spec_divergence / change_impact は出力しない。test-results.yaml / test-cases.yaml / test-plan.md へは書き込まない |
| 標準出力（要約） | 解析結果サマリ（hotspots 件数表に measured 実測の別を明示・複雑度計測ツール名）。測れなかった範囲があれば `open_questions` に列挙 |
| 終了状態 | 複雑度を実測した `measured: true` 材料を返却。カバレッジ実測はせず（責務外）、計測対象外は `measured: false` / `open_questions` で誠実に扱う。決定は test-design へ |

## 関連ケース

- case-01: 複雑度計測ツール未導入（`measured: false` + `null` 側。本ケースの対）
- case-06: partial 縮退では取得可能範囲でも複雑度は `measured: false`（churn のみ取得）
- case-04: none 縮退でコードベース解析自体をスキップ（複雑度・churn とも `null`）
