# case-08 対象説明も analysis.yaml 材料も皆無 × 対話（AskUserQuestion で対象/材料を確認）

フィクスチャ基盤を作る対象（`対象説明=` または位置引数）が完全に未指定で、材料 `analysis.yaml` も非存在（`meta` からの補完もできない）・SUT ソースも特定できず case-05 の軽量補完もできない場合、作る対象が皆無のため生成に進まず、**対話時は AskUserQuestion で対象（または先行 test-analyze での材料用意）を確認**すること（誤った対象へのフィクスチャ捏造生成を防ぐ）を検証する。target-slug（データ配置領域）の解決分岐（既存 slug の有無・複数）とは別軸である。非対話モード（エラー中断）は case-07 で扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | 「フィクスチャ基盤を作って」（`対象説明=` も位置引数も無し・`--non-interactive` なし = 対話。材料 `analysis.yaml` も非存在） |
| 起動形態 | 単独（ユーザー直接起動・対話）/ 委譲でも同一挙動 |
| 前提 | target-slug は解決済み or 解決フローで確定可能だが、何のフィクスチャ基盤を作るか（アプリ URL・リポジトリパス・対象名）の入力が一切なく、材料 `analysis.yaml` も非存在で `meta` からの対象補完もできない。SUT ソースも Read で辿れず case-05 の軽量補完もできない |

## 分岐の根拠

SKILL.md「前提」の引数表（`対象説明=` または位置引数が未指定時: 委譲時は analysis.yaml の meta / 引数から補完・それも無ければ）・「実行モード判定」（対話: 不足情報〔target-slug・対象・`.gitignore` 追記可否〕をユーザーに確認する）、`${CLAUDE_SKILL_DIR}/references/fixture-procedures.md` 2 章（対象が未指定でも analysis.yaml の meta から補える場合は継続・**材料も対象情報も皆無なら対話時はユーザーに確認する**）・3.2 章（軽量補完は SUT ソースが Read 可能な場合の話であり、対象自体が不明なら補完対象がない）、`${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` 4 章（target-slug 解決フローは対象説明の解決とは別軸）、同 `execution-policy.md` 9 章（対話は不足情報を確認する方針）。

## 期待動作

- 作る対象の実体を示す情報（`対象説明=` / 位置引数）が無く、材料 `analysis.yaml` も非存在で `meta` からの補完もできず、SUT ソースも特定できず case-05 の軽量補完もできないことを検出する
- **AskUserQuestion で対象（アプリ URL・リポジトリパス・対象名・仕様の所在）または先行する `test-analyze` 実行での `analysis.yaml` 用意を確認**する。憶測で target-slug 名から対象を推定してフィクスチャ生成を始めない
- ユーザーが対象/材料を提示したら通常のフロー（fixture-procedures.md 2〜7 章の消費 or 3.2 軽量補完 → 要否判定 → 生成/拡充）へ進む。提示が得られなければフィクスチャ生成に進まない
- 対象未確定のまま `fixtures.yaml` / SUT テストコードを生成・変更しない（誤った対象への材料生成・空でない fixtures.yaml の捏造をしない）
- 材料/対象確定前で停止するため fixture 要否判定・既存基盤検出・fixture-architect 自己チェックにも進まない
- target-slug 解決の分岐（既存 slug の有無・複数）とは独立した検証であり、slug が確定していても対象・材料が皆無なら本分岐に入る
- **捏造禁止・決定しない・書き込み境界**の不変条件を維持: `analysis.yaml` を逆生成しない・`test-results.yaml` / `test-cases.yaml` / `analysis.yaml` へは書き込まない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（対象確認待ちのため fixtures.yaml / SUT テストコードを生成・変更しない。test-results.yaml / test-cases.yaml / analysis.yaml へも書き込まない） |
| 標準出力（要約） | AskUserQuestion で対象（アプリ URL・リポジトリパス・対象名・仕様の所在）or 先行 test-analyze 実行を確認する問い |
| 終了状態 | 対象確認待ち（提示後にフィクスチャ構築を継続・対象を推測しない・捏造しない） |

## 関連ケース

- case-07: 同じ「対象・材料の皆無」の**非対話**版（AskUserQuestion を使えずエラー中断する側。本ケースが対話の主軸）
- case-04: 非対話で target-slug / base / project 付与済み → 自動進行（本ケースは対話で対象・材料が皆無）
- case-05: analysis.yaml 欠落だが SUT ソースが Read 可能 → 軽量補完（本ケースは SUT も特定できず確認に回す対比）
- case-01: 対象・材料が揃った通常の新規生成（本ケースの正常系）
