# Case 03: 入力ファイル不在（データ取得スキルの起動提案）

## 入力

| 項目 | 値 |
|-----|---|
| 起動条件 | minutes-composer が直接起動される（パイプライン外での手動起動等） |
| 前提ファイル | `workspace/transcript.txt` が存在しない（`workspace/` が空、または `transcript.txt` が未生成） |
| 判定根拠 | 必須入力ファイル `transcript.txt` の不在により対話モードに遷移する |

## 期待動作

1. `workspace/` 配下のファイルを確認する
2. `workspace/transcript.txt` が存在しないことを検出する
3. 対話モードに遷移し、データ取得スキルの起動を提案する:
   - ailead の共有リンクがある場合 → `meeting-minutes:ailead-fetcher` の実行を提案する
   - VTT/SRT ファイルや文字起こしテキストがある場合 → `meeting-minutes:transcript-converter` の実行を提案する
4. ユーザーの回答を待って中断する（自動的にパイプラインを続行しない）

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| ユーザーへの提示 | 入力ファイル（transcript.txt）が存在しない旨の報告と、データ取得スキル（ailead-fetcher または transcript-converter）の起動提案 |
| `workspace/minutes.json` | 生成されない |
| 終了状態 | 中断（ユーザーの回答待ち） |

## 分岐の根拠

SKILL.md「実行モード判定」表: 「入力ファイル不在 → 対話 → データ取得スキル（ailead-fetcher / transcript-converter）の起動を提案」に該当。`workspace/transcript.txt` と `workspace/metadata.json` の存在が非対話モードの前提条件であり、これらが不在の場合は対話モードで上流スキルの起動をユーザーに提案する。

## 関連ケース

- `case-01_ailead_flow.md`（入力ファイルが全て揃っている場合の ailead フロー）
- `case-02_generic_flow.md`（入力ファイルが揃っている場合の汎用フロー）
