# case-01: 正常系 — 共有リンクからデータ取得

## 入力

```
ailead の共有リンクからデータを取得して
https://dashboard.ailead.app/share/GCsCUNU4G4s1UxUxloJ0CQbapqQ5hGrai_aAlEP2VXA
```

## 前提条件

- 共有リンクが有効（期限内）
- 文字起こし・AI要約が完了済み

## 期待される動作

### Phase 1: URL 確認
- 引数から `dashboard.ailead.app/share/` パターンの URL を検出
- share key を抽出

### Phase 2: セッション作業領域準備
- `.claude/.local/work/{yyyyMMdd_nn_ailead_fetch}/workspace/` を作成
- venv 構築（`setup_venv.sh`）

### Phase 3: データ取得
- `fetch_share.py` を venv の Python で実行
- 正常にデータ取得し、4ファイル出力:
  - `workspace/response.json`
  - `workspace/transcript.txt`
  - `workspace/summary.md`
  - `workspace/metadata.json`

### Phase 4: 結果報告
- 会議タイトル・日時・所要時間を報告
- 参加者一覧と発言割合を報告
- 文字起こしセグメント数・トピック数を報告
- 各ファイルの保存先パスを報告

### Phase 5: クリーンアップ
- venv 削除（`teardown_venv.sh`）

## 期待される出力

- `transcript.txt`: `[HH:MM:SS - HH:MM:SS] 発話者: テキスト` 形式
- `summary.md`: Markdown形式の要約（概要・キーワード・トピック）
- `metadata.json`: JSON形式のメタデータ

## 分岐根拠

正常系の基本フロー。全ステップがエラーなく完了するケース。
