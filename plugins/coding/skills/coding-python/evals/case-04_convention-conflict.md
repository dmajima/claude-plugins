# Case 04: 対話モードで検出規約とユーザ指示が矛盾 → AskUserQuestion 発火

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「この関数を分割して。1 行は 120 文字まで許容して」 |
| 引数 | なし |
| フラグ | なし（対話モード） |
| 既存状態 | Python プロジェクト。`pyproject.toml` の `[tool.ruff]` に `line-length = 88` が定義され、既存コードも 88 で一貫。ユーザの明示指示（120 文字）が機械設定と矛盾する |

## 期待動作

### ステップ1: 規約解決（矛盾の検出）
- SSOT `../../../references/conventions-resolution.md` に従い機械設定（`pyproject.toml [tool.ruff]`: `line-length = 88`）を検出する
- ユーザの明示指示（120 文字）は優先度 1、`pyproject.toml` は優先度 2。両者が同一項目（行長）で矛盾することを把握する

### 矛盾時の確認（対話モード）
- 実行モード判定表の対話行「規約の矛盾・実装方針の拮抗は `AskUserQuestion` で確認する」に従い発火する
- `AskUserQuestion` で提示する: (a) ユーザ指示（120 文字）を優先（優先順位 1・推奨）/ (b) `pyproject.toml`（88 文字）に合わせる
- 回答された方針を確定し、採用理由（優先順位・矛盾があった旨）を報告に記録する

### ステップ3以降: 実装・検証・報告
- 確定した規約で実装する。`open()` の `encoding` 明示など [references/conventions.md](../references/conventions.md) の必須事項を維持する
- 利用可能なツールチェーン（`ruff` 等）を venv 経由で検証し（実行不能は SKIPPED）、矛盾の解決結果を報告する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| ユーザへの確認 | 1 回以上（規約の矛盾を AskUserQuestion で確認） |
| 生成ファイル | 確定方針でのコード変更。報告に矛盾の解決記録あり |
| 終了状態 | 成功（ユーザ確認後に実装） |

## 分岐の根拠

このケースが分岐するトリガーは 対話モード かつ 検出規約（`pyproject.toml`）とユーザ指示の矛盾 である。
実行モード判定表の対話行「規約の矛盾・実装方針の拮抗は `AskUserQuestion` で確認する」を、SSOT `../../../references/conventions-resolution.md` の優先順位（ユーザ指示 = 1 > 機械設定 = 2）と併せて適用する。

## 関連ケース

- [case-01_standalone-basic.md](case-01_standalone-basic.md)（矛盾がなく AskUserQuestion 不発火の基本フローとの対比）
- [case-03_non-interactive.md](case-03_non-interactive.md)（非対話モードでは矛盾を確認せず優先順位で機械的に解決する点が対照的）
