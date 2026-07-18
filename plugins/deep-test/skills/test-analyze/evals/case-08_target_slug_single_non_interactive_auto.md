# case-08 非対話モード × 既存 target-slug 単一（自動採用と解析続行）

`--non-interactive` でのソース解析委譲で、target-slug 未受領かつ唯一の既存 target-slug が存在する場合に、その slug を自動採用して解析を続行することを検証する。採用根拠（唯一の既存 slug）を返却に明記する。既存 slug 複数のエラー中断（case-07）と対になる。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `対象説明=./ --non-interactive`（`target-slug=` の指定なし） |
| 起動形態 | 委譲（オーケストレータ `test` から Skill ツール経由・非対話） |
| 前提 | 基準ディレクトリ配下の既存 `{target-slug}/` は **1 件のみ**（`orderapp-web/`）/ リポジトリソースは full で取得可 / `spec=` `diff=` 指定なし |

## 分岐の根拠

SKILL.md「実行モード判定」（非対話: target-slug は data-locations.md 4.2 章の非対話規則〔唯一の既存 slug 採用〕）・「前提」の引数表（`target-slug=` 未指定時は data-locations.md 4 章の解決フロー）、references/procedures.md 2 章（target-slug 未受領時は data-locations.md 4 章の解決フロー・非対話時は唯一の既存 slug 採用）、`${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` 4.1 章（1 対象 1 slug・再テスト / 追加テストでは既存 slug を再利用）・4.2 章（非対話時は唯一の既存 slug を採用）、同 `execution-policy.md` 9 章（非対話既定値表: target-slug は複数のみエラー中断・唯一の既存は採用）、同 `agents.md` 4.3 章（共通注入事項）。

## 期待動作

- AskUserQuestion を一切呼ばない（非対話モード）
- target-slug が未受領のため data-locations.md 4 章の解決フローに入り、唯一の既存 slug（`orderapp-web`）を自動採用する（新規 slug を作らない・確認も挟まない）
- 採用根拠（唯一の既存 slug のため）を返却に明記する
- source_availability を full と判定し、責務 1〜12 の解析を自動進行して analysis.yaml / target-analysis.md を生成する。**同一 slug への再解析（材料の上書き更新）**であり、1 対象 1 slug の再利用に沿う（data-locations.md 4.1 章）
- 複雑度計測ツールが無いため hotspots は `measured: false` + `null`（本ケースは slug 解決分岐の検証が主眼で、解析内容は case-01 と同等）
- `spec=` `diff=` 未指定のため `spec_divergence` / `change_impact` を出力しない
- `deep-test:source-analyst` を単独起動して自己チェックし、重大指摘を反映してから返却する（非対話でも省略しない）
- read-only に徹し test-results.yaml / test-cases.yaml / test-plan.md へは書き込まない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | `orderapp-web/` 配下の analysis.yaml / target-analysis.md（唯一の既存 slug を自動採用して生成・上書き更新）。spec_divergence / change_impact は出力しない。test-results.yaml / test-cases.yaml / test-plan.md へは書き込まない |
| 標準出力（要約） | 自動採用の根拠（slug = 唯一の既存）を明記した解析結果サマリ（対象種別・source_availability・件数表・source-analyst 所見・open_questions・次フェーズは test-design がレベル / 技法 / 優先度 / ケースを決定する旨） |
| 終了状態 | AskUserQuestion を呼ばず唯一の既存 slug を自動採用して材料 2 ファイルを生成し委譲元へ返却。自己チェックは非対話でも省略しない |

## 関連ケース

- case-07: 同じ非対話で既存 slug が複数の場合（自動選択せずエラー中断する側。本ケースの対）
- case-05: 非対話で target-slug / base が付与済みの自動進行（slug 解決が不要な側）
- case-01: 対話モードでの新規 slug 解決（AskUserQuestion 使用）
- case-09: 解析対象の不在による対話確認（本ケースとは別軸。slug 解決ではなく対象の不在）
