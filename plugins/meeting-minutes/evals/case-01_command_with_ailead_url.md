# Case 01: ailead 共有 URL を引数に指定

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | `/minutes-md https://dashboard.ailead.app/share/GCsCUNU4G4s1UxUxloJ0CQbapqQ5hGrai_aAlEP2VXA` または `/minutes-docx https://dashboard.ailead.app/share/GCsCUNU4G4s1UxUxloJ0CQbapqQ5hGrai_aAlEP2VXA` |
| `$ARGUMENTS` | `https://dashboard.ailead.app/share/<share-key>` |
| 引数の種類 | ailead 共有 URL（`dashboard.ailead.app/share/` を含む） |

## 期待動作

### 1. データ取得（引数判定 → connector:ailead）

1. `$ARGUMENTS` に `dashboard.ailead.app/share/` を含む URL が含まれることを検出する
2. `connector:ailead` スキルを起動する
3. connector:ailead が `workspace/` に 4 ファイルを出力する（response.json, transcript.txt, summary.md, metadata.json）

### 2. 議事録構造化

4. `meeting-minutes:minutes-composer` を起動する
5. `workspace/response.json` の存在により ailead フローで構造化する
6. `workspace/minutes.json` を出力する

### 3. 突合レビュー

7. `meeting-minutes:minutes-reviewer` をフレッシュなサブエージェントとして起動する
8. 修正提案がある場合は `minutes.json` に反映する

### 4. 最終出力

9. `/minutes-md` の場合: `meeting-minutes:md-renderer` を起動し `$SESSION_DIR/minutes.md` を生成する
10. `/minutes-docx` の場合: `meeting-minutes:docx-renderer` を起動し `$SESSION_DIR/minutes.docx` を生成する

### 5. ユーザーへの提示

11. 生成された最終ファイルのパスをユーザーに提示する

## 期待出力

| 項目 | 期待値（minutes-md） | 期待値（minutes-docx） |
|-----|-------|-------|
| 中間ファイル | `workspace/` に response.json, transcript.txt, summary.md, metadata.json, minutes.json, verification-log.md, review-result.json | 同左 |
| 最終成果物 | `$SESSION_DIR/minutes.md` | `$SESSION_DIR/minutes.docx` |
| 終了状態 | 成功 | 成功 |

## 分岐の根拠

`commands/minutes-md.md` および `commands/minutes-docx.md` の「1. データ取得」セクション: 「引数の内容を判定し、適切なスキルを起動する」表の「ailead 共有 URL → connector:ailead」行に該当。

## 関連ケース

- `case-02_command_with_file.md`（ファイルパス引数の場合）
- `case-03_command_no_args.md`（引数なしの場合）
