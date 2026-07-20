# case-14 対話モード × 既存 target-slug 1 件以上（既存一覧提示による slug 選択分岐）

対話モードでのソース解析で、target-slug 未受領かつ既存 slug が 1 件以上存在する場合の挙動を検証する。非対話では既存件数で分岐する（1 件=自動採用〔case-08〕/ 複数=エラー中断〔case-07〕）が、**対話では既存件数によらず AskUserQuestion で既存一覧と「新規作成」を提示し、ユーザー選択で分岐**する（data-locations.md 4.2 の E 分岐）。既存を選べば再利用、新規作成を選べば新規 slug を作成する。target-slug（データ配置領域）の解決分岐であり、解析対象そのものの不在（case-09 / 10）とは別軸である。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `対象説明=./`（`target-slug=` の指定なし・`--non-interactive` なし = 対話） |
| 起動形態 | 単独（ユーザー直接起動・対話）/ 委譲でも target-slug 未受領なら同一挙動 |
| 前提 | 基準ディレクトリ配下に既存 `{target-slug}/` が **1 件以上**存在する（例: `orderapp-web/` と `inventory-app/` の 2 件。1 件のみでも同じ分岐）/ リポジトリソースは full で取得可 / `spec=` `diff=` 指定なし |

## 分岐の根拠

SKILL.md「実行モード判定」（対話: 対象・target-slug の不足情報を AskUserQuestion で確認）・「前提」の引数表（`target-slug=` 未指定時は単独時 data-locations.md 4 章の解決フロー）、references/procedures.md 2 章（単独起動時は data-locations.md 4 章の解決フロー: 既存一覧の提示 → 選択 or 新規作成）、`${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` 4.1 章（1 対象 1 slug・再テスト / 追加テストでは既存 slug を再利用）・4.2 章（**対話時は既存 `{target-slug}/` の一覧を AskUserQuestion で提示し、既存選択 or 新規作成とする** = フロー図 E 分岐。既存を選択→採用、新規作成→新規 slug 名を確認して作成）。

## 期待動作

- 既存 slug が 1 件以上あり、かつ対話モードのため、data-locations.md 4.2 の **E 分岐**に入り、**AskUserQuestion で既存 `{target-slug}/` の一覧（例: `orderapp-web` / `inventory-app`）と「新規作成」を提示**する。憶測で既存 slug を自動選択しない（対話では必ず確認する）
- 既存が複数でも 1 件のみでも、対話なら同じ E 分岐に入る（非対話のように 1 件=自動採用・複数=エラー中断へは分岐しない）
- **応答 A（既存を選択・再利用）**: ユーザーが既存一覧から 1 つ（例: `orderapp-web`）を選択したら、その slug を採用し `{orderapp-web}/` 配下へ **再解析（材料の上書き更新）**を行う。1 対象 1 slug の再利用（data-locations.md 4.1 章）で実績の継続性を保つ
- **応答 B（新規作成を選択）**: ユーザーが「新規作成」を選択したら、新規 slug 名を確認して作成し（フロー図 I へ合流）、新規 slug 配下に材料を生成する
- どちらの応答でも、slug 確定後は通常の解析（procedures.md 3〜6 章）へ進む: source_availability=full の責務 1〜12 を材料化し（複雑度計測ツール無しは `measured: false` + `null`・`spec=` `diff=` 未指定で spec_divergence / change_impact 非出力・`suggested_focus` は hint 止まり）、analysis.yaml / target-analysis.md を生成 → `deep-test:source-analyst` を単独起動して自己チェック → 重大指摘を反映して返却する（解析内容は case-01 と同等）
- ユーザー応答が得られるまで slug を確定せず解析に進まない（選択待ちで停止）
- target-slug 解決の分岐であり、解析対象そのものの不在（case-09 / 10）とは独立である。本ケースは対象説明が与えられている前提で、既存 slug が 1 件以上・対話という **slug 解決**の分岐を扱う
- read-only に徹し test-results.yaml / test-cases.yaml / test-plan.md へは書き込まない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | 選択された slug 配下の analysis.yaml / target-analysis.md（応答 A: 既存 `{orderapp-web}/` へ上書き更新 / 応答 B: 新規 slug 配下へ生成）。spec_divergence / change_impact は出力しない。test-results.yaml / test-cases.yaml / test-plan.md へは書き込まない |
| 標準出力（要約） | まず AskUserQuestion（既存一覧 `orderapp-web` / `inventory-app` ＋「新規作成」）の問い。選択後は解析結果サマリ（対象種別・source_availability・件数表・source-analyst 所見・open_questions・次フェーズは test-design がレベル / 技法 / 優先度 / ケースを決定する旨） |
| 終了状態 | AskUserQuestion で既存一覧＋新規作成を提示し、ユーザー選択で分岐（既存再利用 or 新規作成）。選択後に材料 2 ファイルを生成・自己チェックして返却。対話のため自動選択しない（応答が得られるまで slug 未確定で停止） |

## 関連ケース

- case-08: 非対話 × 既存 slug 1 件の自動採用（同じ「既存 1 件」を非対話側で扱う対。対話の本ケースは 1 件でも確認する側）
- case-07: 非対話 × 既存 slug 複数のエラー中断（同じ「既存複数」を非対話側で扱う対。対話の本ケースは選択させる側）
- case-13: 非対話 × 既存 slug 0 件（対象名から自動生成 / 特定不可はエラー中断。同じ「既存あり／なし」を非対話側で扱う）
- case-01: 対話 × 既存 slug 0 件の新規 slug 解決（本ケースの応答 B「新規作成」が合流する先。既存が無い場合の対話新規作成）
- case-09: 解析対象（対象説明=）の不在による対話確認（本ケースとは別軸。slug 解決ではなく対象の不在）
