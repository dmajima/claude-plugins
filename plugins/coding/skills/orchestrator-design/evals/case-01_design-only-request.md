# Case 01: 設計のみの依頼（標準 4 フェーズ）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「通知機能の設計をして。実装はまだ」 |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | Python（Flask）プロジェクト（`requirements.txt` に flask） |

## 期待動作

### Phase 1: Intake
- 設計ゴール（通知方式・データ構造・API 契約のどこまでを決めるか）を明文化
- `implementation-plan.md` を生成

### Phase 2: Analyze
- Python / Flask を検出 → `coding-python` + `references/frameworks/python-web.md` を適用スキルに確定
- 規約解決（SSOT conventions-resolution.md）と現状構造の把握
- `impact-analysis.md` を生成

### Phase 3: Design
- SSOT design-principles.md の設計観点・リスク分類・データフロー原則に従い設計
- 通知方式の代替案（同期送信 / キュー経由等）を比較し、推奨案を `AskUserQuestion` で確認
- `implementation-design.md` を生成

### Phase 4: Report
- `design-report.md` を生成（設計要点・代替案の採否・実装への引き継ぎ）
- **コードは一切変更しない**。実装はユーザの明示指示があるまで開始しない

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | implementation-plan.md / impact-analysis.md / implementation-design.md / design-report.md |
| コード変更 | なし（0 ファイル） |
| 終了状態 | 成功。実装希望時は orchestrator-coding への引き継ぎを案内 |

## 分岐の根拠

このケースが分岐するトリガーは 依頼内容 = 設計のみ（実装を伴わない）である。

## 関連ケース

- `case-02_implementation-request-redirect.md`（実装込み依頼との対比）
