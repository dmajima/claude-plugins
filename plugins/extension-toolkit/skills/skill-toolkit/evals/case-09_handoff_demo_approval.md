# Case 09: 引き渡し前の動作デモ + AskUserQuestion 承認取得（A-1 / ADR-032）

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | "`hello-skill` を新しく作って" |
| 引数 | `hello-skill` |
| フラグ | なし（対話モード） |
| 既存状態 | 通常の新規スキル作成シナリオ。スキル本体・README・evals が生成済みで「引き渡し」フェーズ直前 |

## 期待動作

### Phase 1〜3: 標準フロー（case-01 と同様）

[case-01](case-01_new_skill_interactive.md) と同じ手順で SKILL.md / README.md / references / evals 一式を生成し、評価フェーズまで完了する。

### Phase 4: 引き渡し前の動作デモ（A-1 必須）

[`completion-checklist.md`](../../../references/checklists/completion-checklist.md) 節 2.4 に従い、以下を実施する:

| ステップ | 内容 |
|---------|------|
| (a) デモシナリオ準備 | `evals/demo.sh`（B-3 テンプレート）を新規スキル用に置換し配置 |
| (b) 代表的な正常系を実行 | `bash evals/demo.sh --execute` で dry-run シナリオを実機実行 |
| (c) 主要分岐 1 件以上を実行 | demo.sh の Step 2 で別分岐を起動 |
| (d) AskUserQuestion 実発火 | スキルが対話 UI を含む場合、実際に AskUserQuestion を発火して選択フローを通す |
| (e) エラーパス 1 件 | 不正引数等のエラー経路を実行 |
| (f) 結果提示 | 標準出力・生成ファイル・実行コマンドをユーザに提示 |

### Phase 5: AskUserQuestion による承認取得

```text
AskUserQuestion({
  questions: [{
    question: "デモ結果を確認しました。引き渡しに進んでよいですか？",
    header: "デモ承認",
    options: [
      { label: "承認・完了報告へ進む",
        description: "結果が想定どおりであり、引き渡しを完了する" },
      { label: "追加デモ・別シナリオを実施",
        description: "未確認の動作分岐や別の入力パターンを追加で実行する" },
      { label: "不具合あり・修正へ戻る",
        description: "デモ結果に問題があり、修正フェーズに戻る" }
    ],
    multiSelect: false
  }]
})
```

### Phase 6: ユーザ選択別の動作

| ユーザ選択 | 後続動作 |
|----------|---------|
| 承認・完了報告へ進む | 引き渡しセクション本体（生成ファイル一覧 + 後続スキル接続提案）に進む |
| 追加デモ・別シナリオを実施 | Phase 4 に戻り別シナリオを実行、再度 Phase 5 で承認確認 |
| 不具合あり・修正へ戻る | 該当スキルの修正フェーズに戻る（実装エンジニアの再起動 or テキスト対話） |

### Phase 7: progress.md 記録

`completion-checklist.md` 節 2.4.3 ステップ 4 に従い、セッションの `progress.md`（または同等記録）に「デモ実施日時 / 実行コマンド / 結果 / 承認結果」を残す。

### Phase 8: 引き渡し本体

承認取得後、生成ファイル一覧を提示し、`extension-review` 接続を提案する（標準の case-01 Phase 4 と同じ）。

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | `evals/demo.sh`（テンプレートから置換配置） |
| 標準出力 | `[Step 1] 代表的な正常系 (dry-run)` 〜 `[Step 4] エラーパス` の進捗 + 承認確認 UI 発火 + 引き渡し本体 |
| 終了状態 | 承認後にスキル完了報告。不具合選択時は修正フェーズ継続（完了報告未実施） |

## 分岐の根拠

ADR-032 で「実コード変更を伴うスキル変更は作業完了報告前に動作デモ + AskUserQuestion 承認を必須」と決定。本ケースは A-1 で `completion-checklist.md` 節 2.4 に「動作デモ + ユーザ承認（MANDATORY）」が追加された後の標準フロー。免責ケース（README/コメントのみ変更 / ADR/SSOT のみ変更 / 緊急セキュリティ修正 / 利用者の明示スキップ指示）に該当しない場合は本ケースの手順を必ず通る。

## 関連ケース

- `case-01_new_skill_interactive.md`（基本フロー、Phase 4 引き渡しは旧仕様）
- `case-02_new_skill_non_interactive.md`（`--non-interactive` 時の挙動、デモ承認は別ルート）
- `case-06_no_branching.md`（動作分岐なし = 単純スキル、デモ要件は最小限）
- ADR-032 / completion-checklist.md 節 2.4
