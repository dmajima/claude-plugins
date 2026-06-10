---
description: 議事録を Markdown 形式で作成する（フルパイプライン実行）
argument-hint: "[ailead共有URL or VTT/SRTファイルパス]"
---

# 議事録作成（Markdown 出力）

議事録をフルパイプラインで作成し、**Markdown 形式**で出力する。

## 引数

`$ARGUMENTS` には以下のいずれかを指定可能:

- ailead 共有 URL（`https://dashboard.ailead.app/share/...`）
- VTT/SRT ファイルパス
- 空（対話的に入力方法を選択）

## 実行フロー

以下のスキルを順番に実行する。中間成果物はすべて `workspace/` に保存し、
最終出力（`minutes.md`）のみセッション直下に配置する。

### 1. データ取得

引数の内容を判定し、適切なスキルを起動する:

| 入力の種類 | 起動するスキル |
|-----------|---------------|
| ailead 共有 URL | `meeting-minutes:ailead-fetcher` |
| VTT/SRT ファイルパス or テキスト | `meeting-minutes:transcript-converter` |
| 空 | ユーザーに入力方法を確認 |

出力先: `$SESSION_DIR/workspace/`（transcript.txt, metadata.json）

### 2. 議事録構造化

`meeting-minutes:minutes-composer` を起動する。

- 入力: `workspace/transcript.txt` + `workspace/metadata.json`（+ `workspace/response.json`（ailead の場合））
- 出力: `workspace/minutes.json`

### 3. 突合レビュー

`meeting-minutes:minutes-reviewer` を **フレッシュなサブエージェント** として起動する。

- 入力: `workspace/minutes.json` + `workspace/transcript.txt`
- 出力: `workspace/verification-log.md` + `workspace/review-result.json`
- 修正提案がある場合は minutes.json に反映する

### 4. Markdown 出力

`meeting-minutes:md-renderer` を起動する。

- 入力: `workspace/minutes.json`
- 出力: `$SESSION_DIR/minutes.md`（セッション直下）

### 5. ユーザーへの提示

生成された `minutes.md` をユーザーに提示する。
