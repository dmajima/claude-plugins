# case-14 非対話モード × 既存 target-slug 0 件（対象名フォールバック slug 生成 / 特定不可はエラー中断）

`--non-interactive` でのフィクスチャ基盤構築委譲で、target-slug 未受領かつ既存 slug が 0 件の場合の挙動を検証する。対話であれば新規 slug 名を確認できる（case-12）が、非対話では確認できないため、data-locations.md 4.2 の J 分岐に従い **対象名から kebab-case で slug を自動生成**して新規採用する。ただし対象名を一意に特定できない/曖昧な場合は **捏造回避エラー中断**とする（推測で slug をでっち上げない）。target-slug（データ配置領域）の解決分岐であり、フィクスチャ対象そのものの不在（case-07 / 08）とは別軸である。test-analyze case-13 の対応ケース様式に倣う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `対象説明=<対象> project=<対象> --non-interactive`（`target-slug=` の指定なし）。サブケース A: `対象説明=./payment-gateway`（リポジトリ名 / 対象名が一意に特定できる）/ サブケース B: `対象説明=./`（リポジトリ名も取得できず対象名が一意に定まらない） |
| 起動形態 | 委譲（オーケストレータ `test` の Phase 1.6・非対話）/ 単独起動でも同一挙動 |
| 前提 | 基準ディレクトリ配下に既存 `{target-slug}/` が **0 件**（新規対象）/ SUT ソースは取得可 / 当該 slug 配下に `analysis.yaml` は未生成（先行 test-analyze なし） |

## 分岐の根拠

SKILL.md「実行モード判定」（非対話: target-slug は data-locations.md 4.2 章の非対話規則）・「前提」の引数表（`target-slug=` 未指定時は data-locations.md 4 章の解決フロー）、SKILL.md「実行フロー」1（入力解決・target-slug 確定）、`${CLAUDE_SKILL_DIR}/references/fixture-procedures.md` 2 章（target-slug 未受領時は data-locations.md 4 章の解決フロー）、`${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` 4.1 章（命名規約: 対象名の kebab-case・1 対象 1 slug）・4.2 章（**非対話かつ既存 0 件は対象名から kebab-case で自動生成。対象名を特定できない場合はエラーで中断**する = フロー図 J 分岐）、同 `execution-policy.md` 9 章（非対話既定値表: 推測が必要な情報不足は自動補完せずエラー中断する方針）。`analysis.yaml` 欠落時の軽量補完規範は case-05（`analysis_consumed: false`・confidence を下げる・能動プローブしない）。

## 期待動作

- AskUserQuestion を一切呼ばない（非対話モード）
- target-slug が未受領のため data-locations.md 4 章の解決フローに入り、既存 slug が 0 件かつ非対話のため **J 分岐（対象名からの自動生成 / 特定不可はエラー中断）**に入る
- **サブケース A（対象名フォールバック slug 生成）**: リポジトリ名 / 対象名（例: `payment-gateway`）を一意に特定できる場合、data-locations.md 4.1 章の命名規約に従い kebab-case slug（`payment-gateway`）を **新規生成して採用**する。採用根拠（対象名からの自動生成・既存 0 件のため新規作成）を返却に明記する。唯一の既存 slug の再利用（case-13）ではなく **新規作成**である点で区別する。生成した slug 配下に `analysis.yaml` が無いため、case-05 の軽量補完（Read/Glob/Grep で最小限補完・`analysis_consumed: false`・confidence を下げる・稼働アプリへの能動プローブはしない）に基づいてフィクスチャ要否を判定し、下地を生成する
- **サブケース B（捏造回避エラー中断）**: 対象名を一意に特定できない/曖昧な場合（例: 対象説明が `./` のみでリポジトリ名も取得できない・モノレポルートで対象が絞れない）は、**推測で slug をでっち上げず**フィクスチャ生成前にエラーで中断する。中断時の返却に「対象名から slug を特定できないため中断した」旨と、`target-slug=` の明示指定（または対象名の明確化）による再実行の案内を含める
- サブケース A でも書き込み境界を維持し、生成は SUT のテストディレクトリに限定する。生成後に `fixture-architect` を単独起動して自己チェックし、重大指摘を反映してから返却する（非対話でも省略しない）。no-op 条件に該当する場合は空 fixtures.yaml + 理由で正常終了する
- サブケース B は材料生成前に停止するため fixture-architect 自己チェックも実施しない
- どちらのサブケースでも read-only 境界を守り、`test-results.yaml` / `test-cases.yaml` / `analysis.yaml` へは書き込まない
- フィクスチャ対象・材料の不在（case-07 / 08）とは独立した検証である。本ケースは対象説明が与えられている（少なくともサブケース A）前提で、既存 slug が 0 件・非対話という **slug 解決**の分岐を扱う

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | サブケース A: 自動生成した `{payment-gateway}/` を配置領域とする fixtures.yaml + SUT テストコード（新規作成。fixture 有効時。no-op 時は空 fixtures.yaml + 理由。analysis 欠落のため `analysis_consumed: false`）。サブケース B: なし（特定不可で中断・生成前に停止）。いずれも test-results.yaml / test-cases.yaml / analysis.yaml へは書き込まない |
| 標準出力（要約） | サブケース A: 自動生成 slug の採用根拠（対象名からの kebab-case 生成・既存 0 件のため新規）と軽量補完（`analysis_consumed: false`・confidence 低）を明記した構築結果サマリ。サブケース B: 「対象名から slug を特定できないため中断した」旨と `target-slug=` 明示指定による再実行の案内 |
| 終了状態 | サブケース A: AskUserQuestion を呼ばず対象名から自動生成した slug を採用してフィクスチャ下地を構築し委譲元へ返却（自己チェックは非対話でも省略しない）。サブケース B: AskUserQuestion を呼ばずエラーで中断（推測で slug を作らない・生成前に停止） |

## 関連ケース

- case-13: 非対話 × 既存 slug 1 件の自動採用（既存の再利用側。本ケース A は既存 0 件からの新規自動生成であり区別する）
- case-11: 非対話 × 既存 slug 複数のエラー中断（同じ非対話でも既存件数が複数の分岐）
- case-12: 対話 × 既存 slug 1 件以上（同じ「既存あり／なし」を対話側で扱う対。本ケースは非対話側）
- case-05: analysis.yaml 欠落時の軽量補完（サブケース A の新規 slug 配下で適用される補完規範）
- case-07 / 08: フィクスチャ対象・材料の不在（本ケースとは別軸。slug 解決ではなく対象の不在）
