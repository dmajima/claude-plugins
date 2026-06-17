# Case 04: テキスト直接貼り付けによるパイプライン実行

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | `/minutes-md 田中: おはようございます。本日の定例会議を始めます。\n鈴木: よろしくお願いします。...` または `/minutes-docx` に同様のテキスト |
| `$ARGUMENTS` | 文字起こしテキスト内容（ailead 共有 URL でもファイルパスでもない文字列） |
| 引数の種類 | テキスト直接貼り付け（VTT/SRT 形式またはプレーンテキスト） |

## 期待動作

### 1. データ取得（引数判定 → transcript-converter）

1. `$ARGUMENTS` の内容を判定する
2. ailead 共有 URL（`dashboard.ailead.app/share/`）を含まないことを確認する
3. ファイルパスとして存在しないことを確認する（または明らかにテキスト内容と判断する）
4. テキスト内容と判定し、`meeting-minutes:transcript-converter` を起動する
5. transcript-converter がテキスト内容を解析し、`workspace/transcript.txt` と `workspace/metadata.json` を出力する

### 2. 議事録構造化

6. `meeting-minutes:minutes-composer` を起動する
7. `workspace/response.json` が存在しないため汎用フローで構造化する
8. `workspace/minutes.json` を出力する

### 3. 突合レビュー

9. `meeting-minutes:minutes-reviewer` をフレッシュなサブエージェントとして起動する
10. 修正提案がある場合は `minutes.json` に反映する

### 4. 最終出力

11. `/minutes-md` の場合: `meeting-minutes:md-renderer` を起動し `$SESSION_DIR/minutes.md` を生成する
12. `/minutes-docx` の場合: `meeting-minutes:docx-renderer` を起動し `$SESSION_DIR/minutes.docx` を生成する

### 5. ユーザーへの提示

13. 生成された最終ファイルのパスをユーザーに提示する

## 期待出力

| 項目 | 期待値（minutes-md） | 期待値（minutes-docx） |
|-----|-------|-------|
| 中間ファイル | `workspace/` に transcript.txt, metadata.json, minutes.json, verification-log.md, review-result.json（response.json は生成されない） | 同左 |
| 最終成果物 | `$SESSION_DIR/minutes.md` | `$SESSION_DIR/minutes.docx` |
| 終了状態 | 成功 | 成功 |

## 分岐の根拠

`commands/minutes-md.md` および `commands/minutes-docx.md` の「1. データ取得」セクション: 「引数の内容を判定し、適切なスキルを起動する」表の「VTT/SRT ファイルパス or テキスト → `meeting-minutes:transcript-converter`」行に該当。`$ARGUMENTS` が ailead URL でもファイルパスでもない場合、テキスト内容として transcript-converter に渡される。

## 関連ケース

- `case-01_command_with_ailead_url.md`（ailead URL 引数の場合）
- `case-02_command_with_file.md`（ファイルパス引数の場合）
- `case-03_command_no_args.md`（引数なしの場合）
