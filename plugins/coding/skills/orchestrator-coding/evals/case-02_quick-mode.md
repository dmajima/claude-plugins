# Case 02: 小規模修正 → クイックモード判定

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「日付フォーマットが `YYYY/MM/DD` になるべき箇所が `YYYY-MM-DD` になっているバグを直して」 |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | Flask プロジェクト（`requirements.txt` あり）。原因ファイルは 1 つ、修正方針が自明 |

## 期待動作

### Phase 1: Intake
- タスクが明確なため確認なしで `implementation-plan.md` を生成

### Phase 2+3: Analyze（統合・クイックモード）
- クイックモード判定（1〜3 ファイル・方針自明）を成果物に記録
- 言語検出（Python → `python.md`、Flask → `frameworks/python-web.md`）と規約解決は **省略せず** 実施
- `impact-analysis.md` 1 つに設計セクションを統合（`implementation-design.md` は作らない）

### Phase 4: Implement
- PEP 8（またはプロジェクト規約）準拠で修正、関連テストを実行

### Phase 5: Self-Review（簡略化）
- `coding:impl-reviewer` 1 体のみでレビュー

### Phase 6: Report
- 通常どおり `implementation-report.md` を生成

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | implementation-plan.md / impact-analysis.md（設計込み）/ file-list.md / self-review-result.md / implementation-report.md |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは タスク規模 = 小（変更 1〜3 ファイル・方針一意）である。クイックモードでも言語検出・規約解決・Phase 1/4/6 は省略されない。

## 関連ケース

- `case-01_standard-full-workflow.md`（標準モードとの対比）
