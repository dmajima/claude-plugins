# case-15 対話モードで既存 target-slug が複数（一覧 + 新規作成の提示）

対話モードで基準ディレクトリに既存 target-slug が複数存在する場合に、自動選択せず AskUserQuestion で既存一覧と「新規作成」を提示して選択させることを検証する。

## 入力

| 項目 | 内容 |
|-----|------|
| ユーザー発話 | 「このアプリをテストして」（フルフロー・対話モード） |
| 前提 | 基準ディレクトリ配下に既存 `{target-slug}/` が 2 件存在する（`orderapp-web/` と `inventory-app/`。いずれも過去の実績あり） |

## 分岐の根拠

`${CLAUDE_SKILL_DIR}/references/flow.md` 2.1 章「Phase 別の要点」Phase 0（既存 slug は AskUserQuestion で選択。非対話は唯一の既存 slug・複数はエラー中断）、references/flow-resume.md 6 章 Phase 0 手順 2（既存 `{target-slug}/` があれば AskUserQuestion で既存一覧 +「新規作成」を提示して選択させる）、プラグイン共通 references/data-locations.md 4.1（1 対象 1 slug。同一対象の再テストでは既存 slug を再利用する）・4.2（解決フロー: 既存 1 件以上 × 対話 → AskUserQuestion で既存一覧と「新規作成」を提示 / 既存を選択 → その slug を採用 / 新規作成 → 新規 slug 名を確認して作成）。

## 期待動作

- Phase 0 で既存 slug 2 件を検出したら、**AskUserQuestion で「orderapp-web」「inventory-app」「新規作成」の選択肢を提示**する（一覧の一部を省略しない）
- 依頼文言・ディレクトリ名からの推測で slug を自動選択しない（誤った対象の実績への追記を防ぐ。data-locations.md 4.2）
- 対話モードではエラー中断しない（エラー中断は非対話時の挙動）
- 既存 slug が選択された場合: その slug を採用し、既存の test-cases.yaml / test-results.yaml へ継続する（1 対象 1 slug の再利用。新しい slug を作らない）
- 「新規作成」が選択された場合: 新規 slug 名を確認して kebab-case（小文字英数字とハイフン）で作成する
- 選択確定後に venv 準備 → `results_manager.py init` を実行してから Phase 1 以降へ進む
- 同一セッション中に基準ディレクトリを切り替えない

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | 既存選択時は選択 slug 配下の既存データを継続利用（init は既存を壊さない）。新規作成選択時は新規 `{target-slug}/` を初期化。いずれも選択確定前にはファイルを生成・変更しない |
| 標準出力（要約） | AskUserQuestion（既存 2 件 + 新規作成の選択肢）→ 選択結果に応じた Phase 0 完了の報告 → 以降は通常フロー |
| 終了状態 | ユーザー選択で slug を確定して Phase 1 以降へ進行（自動選択・エラー中断のいずれもしない） |

## 関連ケース

- case-17: 同じ前提（既存 slug 複数）の非対話版（自動選択せずエラー中断する側）
- case-01: 既存 slug 0 件で新規 slug 名を確認して作成する分岐
- case-05: 非対話で既存 slug 1 件を自動採用する分岐
