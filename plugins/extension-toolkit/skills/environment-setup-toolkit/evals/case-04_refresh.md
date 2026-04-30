# Case 04: refresh（再構築）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "venv を作り直して" |
| 引数 | `refresh --work-dir .../workspace --requirements .../requirements.txt` |
| フラグ | なし |
| 既存状態 | venv 既存（古い） |

## 期待動作

### Phase 1: ユーザ確認

AskUserQuestion で再構築確認（既存 venv 削除を伴うため）。

### Phase 2: teardown

case-03 と同じ手順で削除。

### Phase 3: setup

case-01 と同じ手順で新規構築。

### Phase 4: 検証 + 引き渡し

新 venv の状態確認。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 削除 + 生成 | 旧 venv 削除 + 新 venv 作成 |
| 標準出力 | refresh 手順の進行状況 + 新 venv 情報 |
| 終了状態 | 成功（or キャンセル） |

## 分岐の根拠

動作 = refresh。

## 関連ケース

- `case-02_setup_reuse.md`（再利用選択時）
- `case-03_teardown.md`（撤去のみ）
