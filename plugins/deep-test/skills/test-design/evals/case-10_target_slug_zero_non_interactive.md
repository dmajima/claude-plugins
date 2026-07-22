# case-10 非対話モード × 既存 target-slug 0 件（対象名フォールバック slug 生成 / 特定不可はエラー中断）

`--non-interactive` でのテスト設計委譲で、target-slug 未受領かつ既存 slug が 0 件の場合の挙動を検証する。対話であれば新規 slug 名を確認できる（case-09 応答 B）が、非対話では確認できないため、data-locations.md 4.2 の J 分岐に従い **対象名から kebab-case で slug を自動生成**して新規採用する。ただし対象名を一意に特定できない/曖昧な場合は **捏造回避エラー中断**とする（推測で slug をでっち上げない）。target-slug の解決分岐であり、テスト対象そのものの不在（case-07 / 08）とは別軸である。test-analyze case-13 の対応ケース様式に倣う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `対象説明=<対象> --non-interactive`（`target-slug=` の指定なし）。サブケース A: `対象説明=./payment-gateway`（リポジトリ名 / 対象名が一意に特定できる）/ サブケース B: `対象説明=./`（リポジトリ名も取得できず対象名が一意に定まらない） |
| 起動形態 | 委譲（オーケストレータ `test` の design フェーズ・非対話）/ 単独起動でも同一挙動 |
| 前提 | 基準ディレクトリ配下に既存 `{target-slug}/` が **0 件**（新規対象）/ 既存 test-cases.yaml も無い（新規設計） |

## 分岐の根拠

SKILL.md「実行モード判定」（非対話: target-slug は data-locations.md 4.2 章の非対話規則）・「受け取る引数」（`target-slug=` 未指定時は data-locations.md 4 章の解決フロー）、`${CLAUDE_SKILL_DIR}/references/design-procedures.md` 2 章（target-slug 未受領時は data-locations.md 4 章の解決フロー・非対話時は唯一の既存 slug 採用・複数はエラー中断。0 件時の自動生成も同フローに含む）、`${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` 4.1 章（命名規約: 対象名の kebab-case・1 対象 1 slug）・4.2 章（**非対話かつ既存 0 件は対象名から kebab-case で自動生成。対象名を特定できない場合はエラーで中断**する = フロー図 J 分岐）、同 `execution-policy.md` 9 章（非対話既定値表: 推測が必要な情報不足は自動補完せずエラー中断する方針）。

## 期待動作

- AskUserQuestion を一切呼ばない（非対話モード）
- target-slug が未受領のため data-locations.md 4 章の解決フローに入り、既存 slug が 0 件かつ非対話のため **J 分岐（対象名からの自動生成 / 特定不可はエラー中断）**に入る
- **サブケース A（対象名フォールバック slug 生成）**: リポジトリ名 / 対象名（例: `payment-gateway`）を一意に特定できる場合、data-locations.md 4.1 章の命名規約に従い kebab-case slug（`payment-gateway`）を **新規生成して採用**し、`{payment-gateway}/` 配下に test-plan.md / test-cases.yaml を生成して設計を完遂する。採用根拠（対象名からの自動生成・既存 0 件のため新規作成）を返却に明記する。唯一の既存 slug の再利用（case-06）ではなく **新規作成**である点で区別する
- **サブケース B（捏造回避エラー中断）**: 対象名を一意に特定できない/曖昧な場合（例: 対象説明が `./` のみでリポジトリ名も取得できない・モノレポルートで対象が絞れない）は、**推測で slug をでっち上げず**エラーで中断する。中断時の返却に「対象名から slug を特定できないため中断した」旨と、`target-slug=` の明示指定（または対象名の明確化）による再実行の案内を含める
- サブケース A の設計内容（レベル未指定なら分析からの提案採用・全ケース draft・revision: 1）は case-06 と同等（本ケースの主眼は slug 解決分岐）。生成後に test-architect の自己チェックを経てから返却する（非対話でも省略しない）
- サブケース B は生成前に停止するため test-architect 自己チェックも実施しない
- どちらのサブケースでも test-results.yaml へは書き込まない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | サブケース A: 自動生成した `{payment-gateway}/` 配下の test-plan.md / test-cases.yaml（全ケース draft・新規作成）。サブケース B: なし（特定不可で中断・生成前に停止）。いずれも test-results.yaml へは書き込まない |
| 標準出力（要約） | サブケース A: 自動生成 slug の採用根拠（対象名からの kebab-case 生成・既存 0 件のため新規）を明記した設計結果サマリ（選定レベルと根拠・レベル別ケースサマリ・test-architect 所見・draft 承認が必要な旨）。サブケース B: 「対象名から slug を特定できないため中断した」旨と `target-slug=` 明示指定による再実行の案内 |
| 終了状態 | サブケース A: AskUserQuestion を呼ばず対象名から自動生成した slug を採用して draft 設計を完遂し委譲元へ返却（自己チェックは非対話でも省略しない）。サブケース B: AskUserQuestion を呼ばずエラーで中断（推測で slug を作らない・生成前に停止） |

## 関連ケース

- case-06: 非対話 × 既存 slug 1 件の自動採用（既存の再利用側。本ケース A は既存 0 件からの新規自動生成であり区別する）
- case-05: 非対話 × 既存 slug 複数のエラー中断（同じ非対話でも既存件数が複数の分岐）
- case-09: 対話 × 既存 slug 1 件以上（同じ「既存あり／なし」を対話側で扱う対。本ケースは非対話側）
- case-08: テスト対象の不在による非対話エラー中断（本ケースとは別軸。slug 解決ではなく対象の不在）
