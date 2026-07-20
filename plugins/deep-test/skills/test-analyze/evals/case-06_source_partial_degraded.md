# case-06 部分ソースの縮退（source_availability partial・取得可能範囲のみ解析し欠落を open_questions へ）

リポジトリの一部モジュール / 依存のみ取得できるケース。取得済み範囲は full 同様に解析しつつ、取得できないモジュール / 依存を open_questions に明記する partial 縮退を検証する。取得済み EP・hotspots と欠落 open_questions が 1 ファイル内に併存し、セクションごとに confidence / 充足度が異なる（full 一律 / none 一律のいずれとも異なる）。**full とも none とも異なる独立経路**であることを確認する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `対象説明=./ target-slug=orderapp-web base=<base>` |
| 起動形態 | 委譲（オーケストレータ `test` から Skill ツール経由） |
| 前提 | 一部ディレクトリ（例: `web/` `api/` のみ提供・`payment/` サブモジュールと一部外部依存が非公開で Glob / Read 取得不能）/ 複雑度計測ツール（radon / lizard 等）は未導入 / `spec=` `diff=` 指定なし |

## 分岐の根拠

SKILL.md「実行フロー」2〜3（source_availability 判定・`partial` は取得可能範囲を解析し欠落を `open_questions` へ）・「重要な制約」（縮退時 `confidence: low`・縮退セクションの明示）、references/procedures.md 3 章（`partial` の判定例: 一部ディレクトリのみ提供・ビルド生成物のみ・依存の一部が非公開）・5 章（縮退動作表: `partial` は取得可能範囲のみ 4 章を実施し欠落を `open_questions` に明記・数値は `measured: false` 厳守）、`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-analysis.md` 16 章（`partial` の縮退動作）・7 章（`measured: false` + `null`）・15 章（open_questions は必ず記録）、同 `execution-policy.md` 2 章（未実施を問題なしと書かない SKIPPED 原則）、同 `agents.md` 4.3 章（共通注入事項）。

## 期待動作

- `source_availability` を `partial` と判定し、判定根拠（取得できたモジュール範囲と取得できなかったモジュール / 依存）を target-analysis.md 冒頭に明記する
- 取得可能範囲（`web/` `api/`）は 4 章の解析（アーキ / EP / 依存 / テスタビリティ / churn 等）を full 同様に実施する（`partial` は `none` と異なりコードベース解析を全スキップしない）
- 取得できないモジュール（`payment/`）・非公開依存に関わる EP・依存エッジ・seam は断定せず、欠落として `open_questions` に明記する（捏造しない・`source_ref` は確認できた範囲のみ付与）
- セクションごとに充足度・`confidence` が分かれることを許容する（取得済み範囲由来の所見は相応の confidence、欠落に隣接する推定は `confidence: low`）。full 一律 / none 一律のどちらとも異なる中間経路である
- churn は取得できたパスのみ Bash の git 読み取りで取得し、複雑度計測ツールが無いため hotspots は `cyclomatic_complexity: null` + `measured: false` とする（捏造しない）
- risk_register は取得済み範囲の複雑度 / churn / 露出から算出しつつ、欠落モジュールに起因するリスクは likelihood を弱く推定し `confidence: low` を付与する。`suggested_focus` は hint に留める（決定は test-design）
- `spec=` `diff=` 未指定のため `spec_divergence` / `change_impact` を出力しない
- target-analysis.md の欠落に関わる章に縮退である旨（取得できなかった範囲の併記）を明示する（procedures.md 5 章の縮退明示に従う。`none` の「縮退（ソース不在）」に対し partial は取得済み / 欠落範囲を併記する）
- source-analyst 自己チェックで縮退整合（`partial` と各セクション充足度・`confidence`・`open_questions` の一致）を確認させ、重大指摘を反映する
- read-only に徹し、SUT / 稼働アプリへ書き込まない。test-results.yaml / test-cases.yaml / test-plan.md へも書き込まない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `{target-slug}/analysis.yaml`（`meta.source_availability: partial`・取得済み範囲の EP / HS / TF / RISK・欠落は `open_questions`・hotspots は `measured: false` + `null`・欠落隣接の risk は `confidence: low`）・`{target-slug}/target-analysis.md`（判定根拠に取得済み / 欠落範囲・欠落章に縮退明示）。spec_divergence / change_impact は出力しない。test-results.yaml / test-cases.yaml / test-plan.md へは書き込まない |
| 標準出力（要約） | 解析結果サマリ（`source_availability: partial`・取得済み範囲と縮退範囲の別・件数表）と、欠落モジュール / 依存に関する `open_questions` の列挙 |
| 終了状態 | 取得可能範囲を解析し欠落を `open_questions` に記録した partial 材料を返却。数値は捏造せず `measured: false`、full 一律 / none 一律のいずれとも異なる中間経路。決定は test-design へ |

## 関連ケース

- case-01: source_availability=full（全解析する端点）
- case-04: source_availability=none（コードベース解析を全スキップする端点。partial はその中間）
- case-11: 複雑度計測ツール利用可能時の measured: true（本ケースは取得可能範囲でも measured: false 側）
