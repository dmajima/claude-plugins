# case-09 解析対象（対象説明= / 位置引数）が完全未指定 × 対話（AskUserQuestion で確認）

解析対象そのもの（`対象説明=` または位置引数）が完全に未指定で、`spec=` もリポジトリパスも与えられていない場合、解析材料の入力が無いため解析に進まず、**対話時は AskUserQuestion で対象を確認**すること（誤った対象への材料生成を防ぐ）を検証する。target-slug（データ配置領域）の解決分岐（case-07 / 08）とは別軸であることに注意する。非対話モード（エラー中断）は case-10 で扱う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `target-slug=orderapp-web base=<base>`（`対象説明=` も位置引数も `spec=` も無し。対象の実体を示す情報が皆無・`--non-interactive` なし = 対話） |
| 起動形態 | 委譲（オーケストレータ `test` の analyze フェーズ）/ 単独起動でも同一挙動 |
| 前提 | target-slug は解決済み（データ配置先は確定）だが、何を解析対象とするか（アプリ URL・リポジトリパス・対象名・仕様書の所在）の入力が一切ない |

## 分岐の根拠

SKILL.md「前提」の引数表（`対象説明=` または位置引数が未指定時: 対話時は AskUserQuestion で確認）・「実行モード判定」（対話: 対象・target-slug の不足情報を AskUserQuestion で確認）、`${CLAUDE_SKILL_DIR}/references/procedures.md` 2 章（テスト対象〔`対象説明=` または位置引数〕が未指定の場合: 対話時は AskUserQuestion で確認し、非対話時はエラーで中断する）・3 章（source_availability 判定は対象ソース / spec / 公開仕様のいずれかを要する）。

## 期待動作

- 対象の実体を示す情報が無いことを検出し、**AskUserQuestion で解析対象（アプリ URL・リポジトリパス・対象名・仕様書の所在等）を確認**する。憶測で target-slug 名から対象を推定して解析を始めない
- ユーザーが対象を提示したら通常の解析（procedures.md 3〜6 章）へ進む。提示が得られなければ解析に進まない
- 対象未確定のまま analysis.yaml / target-analysis.md を生成・変更しない（誤った対象への材料生成・空材料の生成をしない）
- 材料生成前で停止するため source_availability 判定・source-analyst 自己チェックにも進まない
- target-slug 解決の分岐（既存 slug の有無・複数）とは独立した検証であり、slug が確定していても対象説明が無ければ本分岐に入る
- test-results.yaml / test-cases.yaml / test-plan.md へは書き込まない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（対象未確定のまま analysis.yaml / target-analysis.md を生成・変更しない。test-results.yaml / test-cases.yaml / test-plan.md へも書き込まない） |
| 標準出力（要約） | AskUserQuestion で解析対象（アプリ URL・リポジトリパス・対象名・仕様書の所在等）を確認する問い |
| 終了状態 | 対象確認待ち（提示後に解析継続・対象を推測しない） |

## 関連ケース

- case-10: 同じ「対象説明の不在」の**非対話**版（AskUserQuestion を使えずエラー中断する側。本ケースの対）
- case-07: 非対話 × 既存 target-slug 複数のエラー中断（**target-slug 解決**の分岐。本ケースは**対象説明の不在**の分岐であり別物）
- case-08: 非対話 × 既存 target-slug 1 件の自動採用（同じく target-slug 解決の分岐）
- case-01: 対象・情報が揃った通常のフル解析（本ケースの正常系）
- case-02: `spec=` 指定あり（対象情報が仕様書で与えられ本分岐に入らない対比）
