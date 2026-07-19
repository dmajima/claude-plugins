# case-07 対象説明も analysis.yaml 材料も皆無 × 非対話（エラー中断・捏造しない）

フィクスチャ基盤を作る対象（`対象説明=` または位置引数）が完全に未指定で、材料 `analysis.yaml` も非存在（`meta` からの補完もできない）・SUT ソースも特定できず case-05 の軽量補完もできない場合の**非対話モード**の挙動を検証する。作る対象が皆無のため、**AskUserQuestion を発行できず、エラーで中断**し、憶測で対象を推定してフィクスチャを捏造生成しないことを扱う。target-slug（データ配置領域）の解決分岐（既存 slug の有無・複数）とは別軸であることに注意する。対話モード（AskUserQuestion で確認）は case-08 が主軸として扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=orderapp-web base=<base> --non-interactive`（`対象説明=` も位置引数も無し・`project=` 起点に SUT ソースを特定できない〔存在しない/空/到達不能〕・`{base}/{target-slug}/analysis.yaml` も非存在。作る対象の実体を示す情報が皆無） |
| 起動形態 | 委譲（オーケストレータ `test` の Phase 1.6）/ 単独起動でも同一挙動 |
| 前提 | target-slug は解決済み（データ配置先は確定）だが、何のフィクスチャ基盤を作るか（アプリ URL・リポジトリパス・対象名）の入力が一切なく、材料 `analysis.yaml` も非存在で `meta` からの対象補完もできない。SUT ソースも Read で辿れず case-05 の軽量補完もできない |

## 分岐の根拠

SKILL.md「前提」の引数表（`対象説明=` または位置引数が未指定時: 委譲時は analysis.yaml の meta / 引数から補完・それも無ければ）・「実行モード判定」（非対話: 曖昧確認をせず進行するが対象不明時は進めない）、`${CLAUDE_SKILL_DIR}/references/fixture-procedures.md` 2 章（対象が未指定でも analysis.yaml の meta から補える場合は継続・**材料も対象情報も皆無なら非対話時はエラーで中断する**）・3.2 章（軽量補完は SUT ソースが Read 可能な場合の話であり、対象自体が不明なら補完対象がない）、`${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` 4 章（target-slug 解決フローは対象説明の解決とは別軸）、同 `execution-policy.md` 9 章（非対話既定値表: 推測が必要な情報不足は自動補完せずエラー中断する方針）。

## 期待動作

- 作る対象の実体を示す情報（`対象説明=` / 位置引数）が無く、材料 `analysis.yaml` も非存在で `meta` からの補完もできず、SUT ソースも特定できず case-05 の軽量補完もできないことを検出する
- **非対話モードのため AskUserQuestion を発行できず、エラーで中断**する。憶測で target-slug 名から対象を推定してフィクスチャ生成を始めない
- 中断時の返却に「**対象・材料が未指定/非存在のためフィクスチャ基盤構築に進めない**」旨と、`対象説明=`（アプリ URL / リポジトリパス / 対象名）の明示指定 or 先行する `test-analyze` 実行による `analysis.yaml` 生成での再実行案内を含める
- 対象未確定のまま `fixtures.yaml` / SUT テストコードを生成・変更しない（誤った対象への材料生成・空でない fixtures.yaml の捏造をしない）
- 生成前に停止するため fixture 要否判定・既存基盤検出・fixture-architect 自己チェックにも進まない
- **捏造禁止**: 材料も対象も無い状態で認証/モック/base のフィクスチャを推定生成しない・`analysis_consumed` を true と偽らない
- target-slug 解決の分岐（既存 slug の有無・複数 = data-locations.md 4.2 章）とは独立した検証であり、slug が確定していても対象・材料が皆無なら本分岐に入る
- 書き込み境界を維持: `test-results.yaml` / `test-cases.yaml` / `analysis.yaml` へは書き込まない。`analysis.yaml` を逆生成もしない（一次解析は test-analyze の責務）

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（対象・材料が皆無のため fixtures.yaml / SUT テストコードを生成しない。空 fixtures.yaml も書かない〔no-op = case-03 と異なりエラー中断〕。test-results.yaml / test-cases.yaml / analysis.yaml へも書き込まない） |
| 標準出力（要約） | 「対象・材料が未指定/非存在のためフィクスチャ基盤構築に進めない」旨と `対象説明=` 明示指定 or 先行 test-analyze 実行での再実行案内 |
| 終了状態 | AskUserQuestion を呼ばずエラーで中断（対象を推測しない・生成前に停止・捏造しない） |

## 関連ケース

- case-08: 同じ「対象・材料の皆無」の**対話**版（AskUserQuestion で確認する側・本ペアの主軸。本ケースはその非対話の対）
- case-04: 非対話だが target-slug / base / project 付与済みで自動進行する対比（本ケースは対象・材料が皆無で中断）
- case-05: analysis.yaml 欠落だが SUT ソースが Read 可能で軽量補完する対比（本ケースは SUT も特定できず補完不可）
- case-03: 材料ありで fixture 不要 → 空 fixtures.yaml + 理由で**正常終了**する no-op（本ケースはエラー中断で空 fixtures.yaml も書かない）
