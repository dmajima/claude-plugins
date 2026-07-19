<!-- R13-EVAL-FUNC-14-SENTINEL-v1 -->
# case-14 manual-assist ケース × 対話で pass 申告 + エビデンス未提供（申告に基づく記録の明記と high 優先度の取得促し）

`automation: manual-assist` の functional スコープのケースについて、対話の結果聴取でユーザーが **pass を申告するがエビデンスを提供しない**場合に、`priority: high` のため取得を促したうえで、それでも未提供なら pass を記録しつつ `actual` に**「人間の申告に基づく（エビデンスなし）」を明記**することを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=sample-web` / `run_id=R20260719-114000` / ケース: `[TC-FUNC-010]`（`automation: manual-assist`・`priority: high`。人の目視でのみ判定できる表示品質確認）/ 対象 URL |
| 起動形態 | 委譲（オーケストレータ test の run フェーズ・対話） |
| 前提 | 対話モード。結果聴取でユーザーは **pass** を申告するが、スクリーンショット等のエビデンスを提供しない（取得を促しても「なし」で確定する） |

## 分岐の根拠

SKILL.md「実行モード判定」の manual-assist / exploratory 分岐（対話時は `${CLAUDE_PLUGIN_ROOT}/references/manual-execution.md` に従いユーザーに確認を依頼し `executed_by: human-assisted` で記録）、`${CLAUDE_PLUGIN_ROOT}/references/manual-execution.md` 3 章（結果聴取の選択肢 **pass** = 期待どおり。actual に確認内容を記録）・4 章（pass 時のエビデンスは**任意**〔必須は fail 時のみ〕。エビデンスなしで pass を記録する場合は actual に「人間の申告に基づく（エビデンスなし）」を明記する。`priority: high` のケースは取得を促す）・1.2（人間の申告を脚色・補完しない）、`${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` 6 章（pass ケースのエビデンス要件・high の pass エビデンス欠落は最終バリデーションで警告）。

## 期待動作

- 提示 3 要素（確認対象・手順・判断基準）を提示のうえ結果を聴取し、pass 申告を受けて `status: pass`・`executed_by: human-assisted` で記録する
- `priority: high` のケースのため、エビデンス（スクリーンショット等）の**取得を促す**（manual-execution.md 4 章 / evidence-policy.md 6 章。強制はしない）
- 促してもエビデンスが提供されない場合、pass の記録は行うが `actual` に**「人間の申告に基づく（エビデンスなし）」を明記**する（manual-execution.md 4 章）
- エビデンス未提供を理由に pass を拒否したり blocked / skipped に振り替えたりしない（pass 時のエビデンスは任意。必須は fail 時のみ）
- エビデンスをでっち上げない（存在しないファイルパスを `evidence` に記載しない。`evidence` は空のままとする）
- 人間の申告を脚色・補完しない（聴取していない確認内容を actual に追記しない）
- scope 全件について 1 エントリを返す
- test-results.yaml を Edit / Write しない（返却のみ）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（エビデンス未提供のため evidence/ への移送なし。test-results.yaml へも書き込まない） |
| 標準出力（要約） | 中間結果 JSON（skill: "test-run-functional" / 受領 run_id / results 1 件が pass・executed_by: human-assisted・actual に「人間の申告に基づく（エビデンスなし）」を含む・evidence は空） |
| 終了状態 | pass を記録して返却（エビデンスなしの旨が actual から判別可能。high の pass エビデンス欠落は最終バリデーションの警告対象） |

## 関連ケース

- case-07: manual-assist × 対話の主系（pass / fail 聴取の基本形。エビデンス未提供の pass 分岐が本ケース）
- case-13: 同じ聴取で blocked 選択（前提不成立側の分岐）
- case-02: 自動実行 fail のエビデンス必須（fail 時 defect 3 点セット）との対比（pass = 任意 / fail = 必須の非対称）
