# case-11 非対話モード × 既存 target-slug 複数（エラー中断）

`--non-interactive` でのフィクスチャ基盤構築委譲で、target-slug が確定できない（既存 slug が複数存在する）場合のエラー中断を検証する。誤った対象への fixtures.yaml / SUT テストコード生成・実績領域の取り違えを防ぐ。target-slug（データ配置領域）の解決分岐であり、フィクスチャを作る対象そのものの不在（case-07 / 08）とは別軸である。test-analyze case-07 の対応ケース様式に倣う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `対象説明=./ project=./ --non-interactive`（`target-slug=` の指定なし） |
| 起動形態 | 委譲（オーケストレータ `test` の Phase 1.6・非対話）/ 単独起動でも同一挙動 |
| 前提 | 基準ディレクトリ配下に既存 `{target-slug}/` が **2 件**存在する（`orderapp-web/` と `inventory-app/`）/ SUT ソース・`analysis.yaml` は取得可 |

## 分岐の根拠

SKILL.md「実行モード判定」（非対話: target-slug は data-locations.md 4.2 章の非対話規則〔唯一の既存 slug 採用・複数はエラー中断〕）・「前提」の引数表（`target-slug=` 未指定時は単独時 data-locations.md 4 章の解決フロー）、SKILL.md「実行フロー」1（入力解決・target-slug 確定）、`${CLAUDE_SKILL_DIR}/references/fixture-procedures.md` 2 章（target-slug 未受領時は data-locations.md 4 章の解決フロー）、`${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` 4.2 章（非対話時は唯一の既存 slug を採用。複数存在時はエラーで中断・slug の明示指定を案内）、同 `execution-policy.md` 9 章（非対話既定値表: target-slug 複数はエラー中断・自動選択しない）。

## 期待動作

- AskUserQuestion を一切呼ばない（非対話モード）
- target-slug が未受領のため data-locations.md 4 章の解決フローに入り、**既存 slug が 2 件あるためフィクスチャ生成前にエラーで中断**する（どちらかを自動選択しない・新規作成もしない）
- 中断時の返却に「複数の既存 target-slug が存在するため中断した」旨と、`target-slug=` の明示指定による再実行の案内を含める
- 中断までに `fixtures.yaml` / SUT テストコードを生成・変更しない（誤った対象への材料生成防止。空 fixtures.yaml も書かない = case-03 の no-op とは異なりエラー中断）
- 生成前に停止するため analysis.yaml 消費・fixture 要否判定・既存基盤検出・fixture-architect 自己チェックにも進まない
- target-slug 解決の分岐であり、フィクスチャ対象の不在（case-07 / 08）とは独立した検証である。対象説明・材料が与えられていても slug 解決が非対話で確定できなければ本分岐に入る
- 書き込み境界を維持: `test-results.yaml` / `test-cases.yaml` / `analysis.yaml` へは書き込まない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（中断までに fixtures.yaml / SUT テストコードを生成・変更しない。空 fixtures.yaml も書かない。test-results.yaml / test-cases.yaml / analysis.yaml へも書き込まない） |
| 標準出力（要約） | 「複数の既存 target-slug が存在するため中断した」旨と `target-slug=` 明示指定による再実行の案内 |
| 終了状態 | AskUserQuestion を呼ばずエラーで中断（slug の自動選択・新規作成をしない・生成前に停止） |

## 関連ケース

- case-12: 同じ target-slug 解決を対話で扱う対（既存一覧を提示して選択させる側。本ケースは非対話でエラー中断）
- case-04: 非対話で target-slug / base / project 付与済みの自動進行（slug 解決が不要な側）
- case-07: フィクスチャ対象・材料の不在による非対話エラー中断（本ケースとは別軸。slug 解決ではなく対象の不在）
