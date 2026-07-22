# Case 01: 標準モード・全 6 フェーズ実施

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「ユーザ一覧画面に検索フィルタ機能を実装して」 |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | React 19 + TypeScript + Vite プロジェクト（`package.json` + `tsconfig.json` あり）。変更見込み 4〜6 ファイル |

## 期待動作

### Phase 1: Intake
- セッション作業領域 `.claude/.local/work/{yyyyMMdd_nn_summary}/` を作成
- フィルタ対象項目が曖昧なため `AskUserQuestion` で確認
- ブランチ方針を確認する（現在のブランチで作業してよいか。デフォルトブランチ上なら新規ブランチ作成を提案）
- `implementation-plan.md` を生成（完了条件・作業分解・ブランチ方針を含む）

### Phase 2: Analyze
- `tsconfig.json` + `package.json` から TypeScript / React を検出し、`coding-typescript` + SSOT `frameworks/react.md` を適用スキルに確定
- `.editorconfig` / `eslint.config.js` / `.prettierrc` / `CLAUDE.md` を走査して適用規約サマリを生成
- ツールチェーン（ビルド / テスト / Lint コマンド）が対象環境で利用可能か確認する（利用不可なら SKIPPED として記録）
- `impact-analysis.md` に検出結果・規約サマリ・影響範囲を記録

### Phase 3: Design
- 実装方針・変更ファイルリスト・リスクを `implementation-design.md` に記録
- 単一モジュール内に閉じた変更（複数モジュール横断ではない）のため、design-principles.md 節 2.3 の architect 起動条件「5 ファイル以上かつ複数モジュール横断」（AND 条件）に該当せず architect レビューは非該当
- 実装方針が拮抗する場合は推奨案を添えて `AskUserQuestion` で確認する（本ケースでは方針が一意のため非発火）

### Phase 4: Implement
- 適用規約サマリ（camelCase・2 スペース等の解決結果）に準拠して実装
- `npm run lint` / `tsc --noEmit` 等の検証を実行し `file-list.md` に記録

### Phase 5: Self-Review
- `coding:impl-reviewer` + `coding:test-engineer` を並列起動
- 指摘を統合し `self-review-result.md` に記録

### Phase 6: Report
- `implementation-report.md` を生成、機密情報チェックを実施
- ユーザへ変更概要を報告。コミットは実行しない

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 生成ファイル | セッション作業領域に成果物 6 種 + リポジトリへのコード変更 |
| 標準出力（要約） | 変更ファイル・検証結果・残課題の要約 |
| 終了状態 | 成功（全フェーズ PASS） |

## 分岐の根拠

このケースが分岐するトリガーは タスク規模 = 標準（クイックモード条件を満たさない）である。

## 関連ケース

- `case-02_quick-mode.md`（小規模時の簡略化との対比）
