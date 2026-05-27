# Case 02: ファイルパスを引数に指定

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | `/minutes-md C:\Users\user\Documents\meeting_2026-05-27.vtt` または `/minutes-docx C:\Users\user\Documents\meeting.srt` |
| `$ARGUMENTS` | VTT/SRT ファイルのフルパス |
| 引数の種類 | ファイルパス（ailead URL ではない） |

## 期待動作

### 1. データ取得（引数判定 → transcript-converter）

1. `$ARGUMENTS` が `dashboard.ailead.app/share/` を含まないことを確認する
2. `$ARGUMENTS` がファイルパスであることを判定する（拡張子 `.vtt` / `.srt` / `.txt` 等、またはパス形式の文字列）
3. `meeting-minutes:transcript-converter` スキルを起動する
4. transcript-converter が入力ファイルの形式を自動判定し、`workspace/transcript.txt` と `workspace/metadata.json` を出力する

### 2. 議事録構造化

5. `meeting-minutes:minutes-composer` を起動する
6. `workspace/response.json` が存在しないため汎用フローで構造化する
7. `workspace/minutes.json` を出力する

### 3. 突合レビュー

8. `meeting-minutes:minutes-reviewer` をフレッシュなサブエージェントとして起動する
9. 修正提案がある場合は `minutes.json` に反映する

### 4. 最終出力

10. `/minutes-md` の場合: `meeting-minutes:minutes-md` を起動し `$SESSION_DIR/minutes.md` を生成する
11. `/minutes-docx` の場合: `meeting-minutes:minutes-docx` を起動し `$SESSION_DIR/minutes.docx` を生成する

### 5. ユーザーへの提示

12. 生成された最終ファイルのパスをユーザーに提示する

## 期待出力

| 項目 | 期待値（minutes-md） | 期待値（minutes-docx） |
|-----|-------|-------|
| 中間ファイル | `workspace/` に transcript.txt, metadata.json, minutes.json, verification-log.md, review-result.json | 同左 |
| 最終成果物 | `$SESSION_DIR/minutes.md` | `$SESSION_DIR/minutes.docx` |
| 終了状態 | 成功 | 成功 |

## 分岐の根拠

`commands/minutes-md.md` および `commands/minutes-docx.md` の「1. データ取得」セクション: 「引数の内容を判定し、適切なスキルを起動する」表の「VTT/SRT ファイルパス or テキスト → meeting-minutes:transcript-converter」行に該当。

## 関連ケース

- `case-01_command_with_ailead_url.md`（ailead URL 引数の場合）
- `case-03_command_no_args.md`（引数なしの場合）
