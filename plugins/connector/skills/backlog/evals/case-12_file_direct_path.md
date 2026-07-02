# Case 12: ファイル情報取得（ダイレクトパス URL・ファイル指定）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "Backlog のこのファイルの情報を見せて https://example.backlog.jp/file/PROJ/docs/meeting/report.pdf" |
| 引数 | ダイレクトパス URL（ファイル指定・末尾がファイル名で `/` なし） |
| フラグ | なし（対話モード） |
| 既存状態 | `~/.claude/credentials.json` に `domains` に `example.backlog.jp` を含む API キーエントリが存在する |

## 期待動作

### Phase 1: 認証事前確認

- URL からスペースホストを `example.backlog.jp` に確定する
- credentials.json で API キーの存在を確認する

### Phase 2: 操作種別判定

- URL パスに `/file/` を含むため **共有ファイル操作**（読み取り）と判定する
- URL 末尾が `/` ではなくファイル名（`report.pdf`）であるため **ファイル指定** と判定する

### Phase 3: URL パース

- パターン A（ダイレクトパス URL）と判定する
- スペースホスト: `example.backlog.jp`
- プロジェクトキー: `PROJ`
- ファイルパス: `docs/meeting/report.pdf`（末尾がファイル名 → ファイル）
- 親ディレクトリパス: `docs/meeting/`（最後の `/` までの部分を抽出）

### Phase 4: API 呼び出し

- `files/metadata` はファイルパスを直接受け付けない（400 エラー）ため、**親ディレクトリパス** で呼び出す
- `GET /api/v2/projects/PROJ/files/metadata/docs/meeting/?apiKey=***&count=100` を呼び出す
- レスポンス配列から `name` フィールドが `report.pdf` と一致するエントリを抽出する

### Phase 5: 整形報告

- 抽出したファイルのメタデータを提示する:
  - ファイル名 / サイズ（KB/MB 変換）/ 作成者 / 作成日時 / 更新日時
- ファイル URL `https://example.backlog.jp/file/PROJ/docs/meeting/report.pdf` を添える

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | なし |
| 標準出力（要約） | ファイルのメタデータ（名前・サイズ・作成者・日時）と URL の整形報告 |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは URL 末尾がファイル名（`/` なし）であること。case-10（末尾 `/` のディレクトリ指定）とは異なり、`files/metadata` の 400 エラー回避のため親ディレクトリ一覧 + 名前フィルタの経路を通る。

## 関連ケース

- `case-10_file_list.md`（ダイレクトパス URL だがディレクトリ指定。API に直接パスを渡せる）
- `case-11_file_alias.md`（エイリアス URL からのファイル情報取得。download API ヘッダ方式）
