# case-13 非対話モード × 既存 target-slug 0 件（対象名フォールバック slug 生成 / 特定不可はエラー中断）

`--non-interactive` でのソース解析委譲で、target-slug 未受領かつ既存 slug が 0 件の場合の挙動を検証する。対話であれば新規 slug 名を確認できる（case-01）が、非対話では確認できないため、data-locations.md 4.2 の J 分岐に従い **対象名から kebab-case で slug を自動生成**して新規採用する。ただし対象名を一意に特定できない/曖昧な場合は **捏造回避エラー中断**とする（推測で slug をでっち上げない）。target-slug（データ配置領域）の解決分岐であり、解析対象そのものの不在（case-09 / 10）とは別軸である。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `対象説明=<対象> --non-interactive`（`target-slug=` の指定なし）。サブケース A: `対象説明=./payment-gateway`（リポジトリ名 / 対象名が一意に特定できる）/ サブケース B: `対象説明=./`（リポジトリ名も取得できず対象名が一意に定まらない） |
| 起動形態 | 委譲（オーケストレータ `test` から Skill ツール経由・非対話） |
| 前提 | 基準ディレクトリ配下に既存 `{target-slug}/` が **0 件**（新規対象）/ リポジトリソースは full で取得可 / `spec=` `diff=` 指定なし |

## 分岐の根拠

SKILL.md「実行モード判定」（非対話: target-slug は data-locations.md 4.2 章の非対話規則）・「前提」の引数表（`target-slug=` 未指定時は data-locations.md 4 章の解決フロー）、references/procedures.md 2 章（target-slug 未受領時は data-locations.md 4 章の解決フロー・非対話時は唯一の既存 slug 採用・複数はエラー中断。0 件時の自動生成も同フローに含む）、`${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` 4.1 章（命名規約: 対象名の kebab-case・1 対象 1 slug）・4.2 章（**非対話かつ既存 0 件は対象名から kebab-case で自動生成。対象名を特定できない場合はエラーで中断**する = フロー図 J 分岐）、同 `execution-policy.md` 9 章（非対話既定値表: 推測が必要な情報不足は自動補完せずエラー中断する方針）。

## 期待動作

- AskUserQuestion を一切呼ばない（非対話モード）
- target-slug が未受領のため data-locations.md 4 章の解決フローに入り、既存 slug が 0 件かつ非対話のため **J 分岐（対象名からの自動生成 / 特定不可はエラー中断）**に入る
- **サブケース A（対象名フォールバック slug 生成）**: リポジトリ名 / 対象名（例: `payment-gateway`）を一意に特定できる場合、data-locations.md 4.1 章の命名規約に従い kebab-case slug（`payment-gateway`）を **新規生成して採用**し、`{payment-gateway}/` 配下に材料を生成して解析を続行する。採用根拠（対象名からの自動生成・既存 0 件のため新規作成）を返却に明記する。唯一の既存 slug の再利用（case-08）ではなく **新規作成**である点で区別する
- **サブケース B（捏造回避エラー中断）**: 対象名を一意に特定できない/曖昧な場合（例: 対象説明が `./` のみでリポジトリ名も取得できない・モノレポルートで対象が絞れない）は、**推測で slug をでっち上げず**エラーで中断する。中断時の返却に「対象名から slug を特定できないため中断した」旨と、`target-slug=` の明示指定（または対象名の明確化）による再実行の案内を含める
- サブケース A の解析内容（source_availability=full の責務 1〜12・複雑度計測ツール無しは `measured: false` + `null`・`spec=` `diff=` 未指定で spec_divergence / change_impact 非出力・`suggested_focus` は hint 止まり）は case-01 / case-08 と同等（本ケースの主眼は slug 解決分岐）。生成後に `deep-test:source-analyst` を単独起動して自己チェックし、重大指摘を反映してから返却する（非対話でも省略しない）
- サブケース B は材料生成前に停止するため source-analyst 自己チェックも実施しない
- どちらのサブケースでも read-only に徹し、test-results.yaml / test-cases.yaml / test-plan.md へは書き込まない
- 解析対象の不在（case-09 / 10）とは独立した検証である。本ケースは対象説明が与えられている（少なくともサブケース A）前提で、既存 slug が 0 件・非対話という **slug 解決**の分岐を扱う

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | サブケース A: 自動生成した `{payment-gateway}/` 配下の analysis.yaml / target-analysis.md（新規作成）。spec_divergence / change_impact は出力しない。サブケース B: なし（特定不可で中断・材料生成前に停止）。いずれも test-results.yaml / test-cases.yaml / test-plan.md へは書き込まない |
| 標準出力（要約） | サブケース A: 自動生成 slug の採用根拠（対象名からの kebab-case 生成・既存 0 件のため新規）を明記した解析結果サマリ（対象種別・source_availability・件数表・source-analyst 所見・open_questions・次フェーズは test-design がレベル / 技法 / 優先度 / ケースを決定する旨）。サブケース B: 「対象名から slug を特定できないため中断した」旨と `target-slug=` 明示指定による再実行の案内 |
| 終了状態 | サブケース A: AskUserQuestion を呼ばず対象名から自動生成した slug を採用して材料 2 ファイルを生成し委譲元へ返却（自己チェックは非対話でも省略しない）。サブケース B: AskUserQuestion を呼ばずエラーで中断（推測で slug を作らない・材料生成前に停止） |

## 関連ケース

- case-08: 非対話 × 既存 slug 1 件の自動採用（既存の再利用側。本ケース A は既存 0 件からの新規自動生成であり区別する）
- case-07: 非対話 × 既存 slug 複数のエラー中断（同じ非対話でも既存件数が複数の分岐）
- case-14: 対話 × 既存 slug 1 件以上（同じ「既存あり／なし」を対話側で扱う対。本ケースは非対話側）
- case-01: 対話 × 既存 slug 0 件の新規 slug 解決（AskUserQuestion で新規 slug 名を確認。本ケースはその非対話版に相当）
- case-05: 非対話で target-slug / base が付与済みの自動進行（slug 解決フローに入らない側）
- case-10: 解析対象の不在による非対話エラー中断（本ケースとは別軸。slug 解決ではなく対象の不在）
