# case-32 P26/P27 残存 active インラインスレッドの確認と完了報告記載（残 2 件 vs 全解消の対比）

再レビューで Pattern C に分類された 2 件が status=active のまま残るとき、Step 7.5 完了前チェックで active なインラインスレッド数を確認し（P26）、Step 8 完了報告に各スレッドの thread_id / file:line / 推奨アクションを明記する（P27）分岐を検証する。active が 0 件（全解消 → サマリーのみ active）の場合との対比も明示する。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | "PR #123 をレビューして"（既存自著インラインスレッド 2 件・いずれも再レビューで未解消と判定＝Pattern C・意図的に status=active 維持。auto-resolve 引数なし＝既定） |
| モード | 非対話 |

## 分岐の根拠

`${CLAUDE_SKILL_DIR}/references/checklist.md` P26「完了時に PR の active なインラインスレッド一覧を取得し、残件数を確認している」/ P27「残スレッドがある場合は thread_id / file:line / 推奨アクションを完了報告に含めている」（SSOT: `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` P26/P27）+ `${CLAUDE_SKILL_DIR}/references/completion-checklist.md` B-1.7（詳細は同ディレクトリ `completion-checklist-execution.md` B-1.7-1〜B-1.7-6）。Pattern C が active スレッドを残す（case-17）ことを前提に、その残件を完了フェーズで検証・報告する側の分岐。

## 期待動作

- Step 7.5（完了前チェックリスト）で PR の active なインラインスレッド一覧を取得し、残件数（= 2 件）を確認する（P26 / completion-checklist-execution.md B-1.7-1）
- active なインラインスレッドが残るため「サマリーのみ active」状態には達していないと判定する（B-1.7-2 の対比条件。全解消時のみ B-1.7-2 を満たす）
- Step 8 完了報告に、残る 2 件それぞれの thread_id / file:line / Finding ID 推定 / 推定適用パターン（C）を一覧で含める（P27 / B-1.7-3）
- 各残スレッドへの推奨アクション（コード修正・ack-fixed 指示・ack-scope-out 指示・手動 resolve）をユーザーに提示する（P27 / B-1.7-4）
- サマリースレッドは PR 全体宛で 1 件のみ active（旧サマリーは status=closed 済み）であることを確認する（B-1.7-5）
- Verdict に関わらず（OK / Needs Attention / Needs Work のいずれでも）サマリースレッドが新規投稿されていることを確認する（B-1.7-6）
- 対比として、全スレッドが Pattern A で解消され active なインラインスレッドが 0 件になった場合は「サマリーのみ active を達成」と完了報告に明記する分岐（B-1.7-2）であり、本ケース（残 2 件）とは報告内容が異なることを区別する
- Pattern A は自動解消済みのため通常 active に残らず、残存 active は Pattern C（および未処理の C/D/E 候補）である旨を報告する（B-1.7-3）

## 関連ケース

- case-17: Pattern C 未解消スレッドへの再観察 reply（本ケースで残る active スレッドを生む前提の分岐）
- case-16: Pattern A 全件解消の auto-resolve（active 0 件・サマリーのみ active に至る対比の分岐）
- case-31: P13 系統別分類と保守的除外（設計・仕様系の未解決維持が active スレッドを残す分岐）
