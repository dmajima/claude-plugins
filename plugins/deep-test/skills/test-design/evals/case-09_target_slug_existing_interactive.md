# case-09 対話モード × 既存 target-slug 1 件以上（既存一覧提示による slug 選択分岐）

対話モードでのテスト設計で、target-slug 未受領かつ既存 slug が 1 件以上存在する場合の挙動を検証する。非対話では既存件数で分岐する（1 件=自動採用〔case-06〕/ 複数=エラー中断〔case-05〕）が、**対話では既存件数によらず AskUserQuestion で既存一覧と「新規作成」を提示し、ユーザー選択で分岐**する（data-locations.md 4.2 の E 分岐）。target-slug（データ配置領域）の解決分岐であり、テスト対象そのものの不在（case-07 / 08）とは別軸である。test-analyze case-14 の対応ケース様式に倣う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `対象説明=./`（`target-slug=` の指定なし・`--non-interactive` なし = 対話） |
| 起動形態 | 単独（ユーザー直接起動・対話）/ 委譲でも target-slug 未受領なら同一挙動 |
| 前提 | 基準ディレクトリ配下に既存 `{target-slug}/` が **1 件以上**存在する（例: `orderapp-web/` と `inventory-app/` の 2 件。1 件のみでも同じ分岐）/ 対象情報（リポジトリ / URL）は取得可 |

## 分岐の根拠

SKILL.md「実行モード判定」（対話: target-slug・対象の不足を AskUserQuestion で確認）・「受け取る引数」（`target-slug=` 未指定時は単独時 data-locations.md 4 章の解決フロー）、`${CLAUDE_SKILL_DIR}/references/design-procedures.md` 2 章（単独起動時は data-locations.md 4 章の解決フロー: 既存一覧の提示 → 選択 or 新規作成）、`${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` 4.1 章（1 対象 1 slug・再テスト / 追加テストでは既存 slug を再利用）・4.2 章（**対話時は既存 `{target-slug}/` の一覧を AskUserQuestion で提示し、既存選択 or 新規作成とする** = フロー図 E 分岐）。

## 期待動作

- 既存 slug が 1 件以上あり、かつ対話モードのため、data-locations.md 4.2 の **E 分岐**に入り、**AskUserQuestion で既存 `{target-slug}/` の一覧（例: `orderapp-web` / `inventory-app`）と「新規作成」を提示**する。憶測で既存 slug を自動選択しない
- 既存が複数でも 1 件のみでも、対話なら同じ E 分岐に入る（非対話のように 1 件=自動採用〔case-06〕・複数=エラー中断〔case-05〕へは分岐しない）
- **応答 A（既存を選択・再利用）**: ユーザーが既存一覧から 1 つ（例: `orderapp-web`）を選択したら、その slug を採用し `{orderapp-web}/` 配下を対象に設計フロー（design-procedures.md 3〜6 章: 分析 → レベル選定 → test-plan.md / test-cases.yaml 生成 → test-architect 自己チェック）へ進む。既存 test-cases.yaml があれば revision 規則で更新（case-04 と同型）、無ければ新規設計
- **応答 B（新規作成を選択）**: ユーザーが「新規作成」を選択したら、新規 slug 名を確認して作成し、新規 slug 配下に新規設計を行う
- どちらの応答でも、生成・変更したケースは `review_status: draft`、test-architect の自己チェックを経てから返却する
- ユーザー応答が得られるまで slug を確定せず設計に進まない（選択待ちで停止）
- target-slug 解決の分岐であり、テスト対象そのものの不在（case-07 / 08）とは独立である。本ケースは対象情報が与えられている前提で、既存 slug が 1 件以上・対話という **slug 解決**の分岐を扱う
- test-results.yaml へは書き込まない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | 選択された slug 配下の test-plan.md・test-cases.yaml（全ケース `review_status: draft`。応答 A: 既存 `{orderapp-web}/` へ更新〔既存あれば revision 規則〕 / 応答 B: 新規 slug 配下へ生成）。test-results.yaml へは書き込まない |
| 標準出力（要約） | まず AskUserQuestion（既存一覧 `orderapp-web` / `inventory-app` ＋「新規作成」）の問い。選択後は設計結果サマリ（選定レベルと根拠・レベル別ケースサマリ・test-architect 所見・draft 承認が必要な旨） |
| 終了状態 | AskUserQuestion で既存一覧＋新規作成を提示し、ユーザー選択で分岐（既存再利用 or 新規作成）。選択後に draft 設計を完遂して後続レビューへ。対話のため自動選択しない（応答が得られるまで slug 未確定で停止） |

## 関連ケース

- case-05: 非対話 × 既存 slug 複数のエラー中断（同じ「既存複数」を非対話側で扱う対。対話の本ケースは選択させる側）
- case-06: 非対話 × 既存 slug 1 件の自動採用（同じ「既存 1 件」を非対話側で扱う対。対話の本ケースは 1 件でも確認する側）
- case-10: 非対話 × 既存 slug 0 件（同じ「既存あり／なし」を非対話側で扱う）
- case-07: テスト対象（対象説明=）の不在による対話確認（本ケースとは別軸。slug 解決ではなく対象の不在）
