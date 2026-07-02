# Case 10: 共有ファイル一覧取得（ダイレクトパス URL）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "Backlog のこのフォルダの中身を見せて https://example.backlog.jp/file/PROJ/docs/meeting/" |
| 引数 | ダイレクトパス URL（フォルダ指定・末尾 `/`） |
| フラグ | なし（対話モード） |
| 既存状態 | `~/.claude/credentials.json` に `domains` に `example.backlog.jp` を含む API キーエントリが存在する |

## 期待動作

### Phase 1: 認証事前確認

- URL からスペースホストを `example.backlog.jp` に確定する
- credentials.json で API キーの存在を確認する

### Phase 2: 操作種別判定

- URL パスに `/file/` を含むため **共有ファイル一覧取得**（読み取り）と判定し、SKILL.md Step 3 へ進む
- render-check・AskUserQuestion 承認は発火しない（書き込みではないため）

### Phase 3: URL パース

- パターン A（ダイレクトパス URL）と判定する
- スペースホスト: `example.backlog.jp`
- プロジェクトキー: `PROJ`
- ファイルパス: `docs/meeting/`（末尾 `/` → ディレクトリ）

### Phase 4: API 呼び出し

- URL 末尾が `/` のためディレクトリと判定する
- `GET /api/v2/projects/PROJ/files/metadata/docs/meeting/?apiKey=***&count=100` を呼び出す
- safe-api-access.md の原則に従う: `curl --max-time 30`、apiKey は `--config` ファイル経由
- HTTP 2xx を受領し、一時ファイルは trap で削除する
- ファイル URL（末尾がファイル名で `/` なし）の場合は、親ディレクトリパスで API を呼び出し、レスポンスからファイル名で抽出する（`files/metadata` はファイルパス直接指定で 400 エラーを返すため）

### Phase 5: 整形報告

- レスポンスの配列を一覧表で提示する:
  - 名前 / 種別（ファイル or [フォルダ]）/ サイズ / 更新日時
  - ディレクトリは `[フォルダ]`、サイズは `-`
  - ファイルサイズは KB/MB 単位に変換
- フォルダの URL `https://example.backlog.jp/file/PROJ/docs/meeting/` を添える
- レスポンスの生 JSON をそのまま貼らない

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし（一時ファイルは処理終了時に削除済み） |
| 標準出力（要約） | フォルダ内のファイル・サブフォルダの一覧表と対象フォルダ URL の整形報告 |
| 終了状態 | 成功（続けて関連操作が必要かを確認して終了） |

## 分岐の根拠

このケースが分岐するトリガーは URL パスの `/file/` パターン検出 → 操作種別（SKILL.md Step 2）= 読み取り（共有ファイル一覧取得）。Step 3 の読み取り経路で api-read.md 操作 8 を実行する。

## 関連ケース

- `case-11_file_alias.md`（エイリアス URL からのファイル情報取得。エイリアス解決フェーズを経由する）
- `case-01_issue_get.md`（同じ読み取り系だが、課題取得。URL パスは `/view/` で区別される）
