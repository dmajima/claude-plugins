# case-12 対話モード × 既存 target-slug 1 件以上（既存一覧提示による slug 選択分岐）

対話モードでのフィクスチャ基盤構築で、target-slug 未受領かつ既存 slug が 1 件以上存在する場合の挙動を検証する。非対話では既存件数で分岐する（1 件=自動採用 / 複数=エラー中断〔case-11〕）が、**対話では既存件数によらず AskUserQuestion で既存一覧と「新規作成」を提示し、ユーザー選択で分岐**する（data-locations.md 4.2 の E 分岐）。target-slug（データ配置領域）の解決分岐であり、フィクスチャを作る対象そのものの不在（case-07 / 08）とは別軸である。test-analyze case-14 の対応ケース様式に倣う。

## 入力

| 項目 | 内容 |
|-----|------|
| 委譲 args | `対象説明=./ project=./`（`target-slug=` の指定なし・`--non-interactive` なし = 対話） |
| 起動形態 | 単独（ユーザー直接起動・対話）/ 委譲でも target-slug 未受領なら同一挙動 |
| 前提 | 基準ディレクトリ配下に既存 `{target-slug}/` が **1 件以上**存在する（例: `orderapp-web/` と `inventory-app/` の 2 件。1 件のみでも同じ分岐）/ SUT ソース・`analysis.yaml` は取得可 |

## 分岐の根拠

SKILL.md「実行モード判定」（対話: 不足情報〔target-slug・対象・.gitignore 追記可否〕をユーザーに確認）・「前提」の引数表（`target-slug=` 未指定時は単独時 data-locations.md 4 章の解決フロー）、SKILL.md「実行フロー」1（入力解決・target-slug 確定）、`${CLAUDE_SKILL_DIR}/references/fixture-procedures.md` 2 章（単独起動時は data-locations.md 4 章の解決フロー: 既存一覧の提示 → 選択 or 新規作成）、`${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` 4.1 章（1 対象 1 slug・追加テストでは既存 slug を再利用）・4.2 章（**対話時は既存 `{target-slug}/` の一覧を AskUserQuestion で提示し、既存選択 or 新規作成とする** = フロー図 E 分岐）。

## 期待動作

- 既存 slug が 1 件以上あり、かつ対話モードのため、data-locations.md 4.2 の **E 分岐**に入り、**AskUserQuestion で既存 `{target-slug}/` の一覧（例: `orderapp-web` / `inventory-app`）と「新規作成」を提示**する。憶測で既存 slug を自動選択しない
- 既存が複数でも 1 件のみでも、対話なら同じ E 分岐に入る（非対話のように 1 件=自動採用・複数=エラー中断へは分岐しない）
- **応答 A（既存を選択・再利用）**: ユーザーが既存一覧から 1 つ（例: `orderapp-web`）を選択したら、その slug を採用し `{orderapp-web}/` 配下を対象にフィクスチャ基盤構築フロー（fixture-procedures.md 2〜7 章: analysis.yaml 消費 → 要否判定 → 既存基盤検出 → 生成 / 拡充 → fixture-architect 自己チェック）へ進む
- **応答 B（新規作成を選択）**: ユーザーが「新規作成」を選択したら、新規 slug 名を確認して作成し、新規 slug 配下を対象に同じフィクスチャ構築フローへ進む
- ユーザー応答が得られるまで slug を確定せず生成に進まない（選択待ちで停止）
- target-slug 解決の分岐であり、フィクスチャ対象そのものの不在（case-07 / 08）とは独立である。本ケースは対象説明・材料が与えられている前提で、既存 slug が 1 件以上・対話という **slug 解決**の分岐を扱う
- 書き込み境界を維持: slug 確定後の書き込みは SUT のテストディレクトリと選択 slug 配下の fixtures.yaml のみ。`test-results.yaml` / `test-cases.yaml` / `analysis.yaml` へは書き込まない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | 選択された slug 配下の fixtures.yaml + SUT テストディレクトリのフィクスチャ / config（応答 A: 既存 `{orderapp-web}/` 配下 / 応答 B: 新規 slug 配下）。fixture 不要なら空 fixtures.yaml + 理由（case-03 の no-op）。test-results.yaml / test-cases.yaml / analysis.yaml へは書き込まない |
| 標準出力（要約） | まず AskUserQuestion（既存一覧 `orderapp-web` / `inventory-app` ＋「新規作成」）の問い。選択後はフィクスチャ構築結果サマリ（消費した analysis.yaml・生成 / 拡充したフィクスチャ・fixture-architect 所見） |
| 終了状態 | AskUserQuestion で既存一覧＋新規作成を提示し、ユーザー選択で分岐（既存再利用 or 新規作成）。選択後にフィクスチャ構築を実施して返却。対話のため自動選択しない（応答が得られるまで slug 未確定で停止） |

## 関連ケース

- case-11: 同じ target-slug 解決を非対話で扱う対（既存複数はエラー中断する側。本ケースは対話で選択させる側）
- case-04: 非対話 × target-slug 付与済みの自動進行（slug 解決が不要な側）
- case-08: フィクスチャ対象の不在による対話確認（本ケースとは別軸。slug 解決ではなく対象の不在）
