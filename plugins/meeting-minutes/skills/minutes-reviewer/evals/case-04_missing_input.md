# Case 04: 入力ファイル不在（minutes-composer の起動提案）

## 入力

| 項目 | 値 |
|-----|---|
| 起動条件 | minutes-reviewer が直接起動される（パイプライン外での手動起動等） |
| 前提ファイル | `workspace/minutes.json` が存在しない（`workspace/` に transcript.txt のみ、または `workspace/` が空） |
| 判定根拠 | 必須入力ファイル `minutes.json` の不在により対話モードに遷移する |

## 期待動作

1. メインコンテキストが Agent ツールでフレッシュインスタンスを起動する
2. `workspace/minutes.json` の存在を確認する
3. `workspace/minutes.json` が存在しないことを検出する
4. 対話モードに遷移し、`meeting-minutes:minutes-composer` の実行を提案する
5. ユーザーの回答を待って中断する（自動的にパイプラインを続行しない）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| ユーザーへの提示 | 入力ファイル（minutes.json）が存在しない旨の報告と、minutes-composer の起動提案 |
| `workspace/verification-log.md` | 生成されない |
| `workspace/review-result.json` | 生成されない |
| 終了状態 | 中断（ユーザーの回答待ち） |

## 分岐の根拠

SKILL.md「実行モード判定」表: 「入力ファイル不在 → 対話 → minutes-composer の実行を提案」に該当。`workspace/minutes.json` と `workspace/transcript.txt` の存在が非対話モードの前提条件であり、`minutes.json` が不在の場合は対話モードで上流スキル（minutes-composer）の起動をユーザーに提案する。

## 関連ケース

- `case-01_with_corrections.md`（入力ファイルが揃っている場合の修正ありパス）
- `case-02_no_corrections.md`（入力ファイルが揃っている場合の修正なしパス）
- `case-03_ailead_source_review.md`（ailead ソースの時刻ベース突合検証パス）
