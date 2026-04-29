# Case 02: 新規スキル作成（非対話モード）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "skill-creator code-formatter を非対話で作成" |
| 引数 | `code-formatter --description "コード整形支援" --triggers "「整形して」,「フォーマット」,「lint」" --location standalone` |
| フラグ | `--non-interactive` |
| 既存状態 | `code-formatter` スキルが未存在 |

## 期待動作

### Phase 1: モード判定

`--non-interactive` フラグありのため、対話せず引数値で確定する。

### Phase 2: テンプレート展開

引数値でプレースホルダ置換。Python 利用・外部依存・動作分岐は引数になければデフォルト（false / false / true）。

### Phase 3: 検証

新規・対話モード（case-01）と同じチェックリスト。

### Phase 4: 引き渡し

生成ファイル一覧のみ提示。確認は省略。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | case-01 と同じ |
| 標準出力（要約） | 完了報告のみ（質問なし） |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは `--non-interactive` フラグの有無 である。

## 関連ケース

- `case-01_new_skill_interactive.md`（同じ新規だが対話）
