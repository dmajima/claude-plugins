# Case 01: 単独実行モードの基本フロー

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「この CSV 集計関数にオプションを追加して」 |
| 引数 | なし |
| フラグ | なし |
| 既存状態 | Python プロジェクト（`pyproject.toml` あり）。対象は既存の CSV 集計関数 1 ファイル。変更見込み 1〜2 ファイル |

## 期待動作

単独実行モードの実行フロー 5 段を実施する。

### ステップ1: 規約解決
- SSOT `../../../references/conventions-resolution.md` に従い、プロジェクト独自規約（`pyproject.toml` の tool 設定（ruff / mypy 等）・`.editorconfig` / `CLAUDE.md` / 既存慣習）を走査
- 独自規約がない項目は [references/conventions.md](../references/conventions.md) のデファクト規約（PEP 8 / PEP 257）を適用

### ステップ2: FW 確認
- 依存定義（`pyproject.toml` / `requirements.txt`）に `flask` / `django` / `fastapi` が無く、SQLAlchemy 等の ORM も無いため FW プロファイルは非該当と判断し、その旨を記録
- 依存が該当する場合は [references/frameworks/python-web.md](../references/frameworks/python-web.md) / SSOT `../../../references/frameworks/orm.md` を併用

### ステップ3: 実装
- 解決した規約に従い、集計関数へオプション引数を追加。既定値を持たせ既存呼び出しの後方互換を維持
- 既存ファイルの編集のため、周辺コードのスタイル・エンコーディング・改行コードを維持
- CSV 読み書きの `open()` は `encoding` を明示（conventions.md の必須事項）

### ステップ4: 検証
- 利用可能なツールチェーン（`pytest` / `ruff check` / `ruff format` / `mypy` のうち規約解決で確定したもの）を venv 経由で実行
- 実行不能な検証は SKIPPED として報告

### ステップ5: 報告
- 変更ファイル・適用規約の根拠（独自規約 or デファクト）・検証結果を報告
- コミット・push はユーザの明示指示があるまで実行しない

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| ユーザへの確認 | 規約の矛盾・実装方針の拮抗がなければ AskUserQuestion 不発火 |
| 生成ファイル | リポジトリへのコード変更（集計関数 1〜2 ファイル）。セッション成果物 6 種は生成しない |
| 標準出力（要約） | 変更ファイル・適用規約の根拠・検証結果 |
| 終了状態 | 成功 |

## 分岐の根拠

このケースが分岐するトリガーは タスク規模 = 小 かつ 言語 = Python で明確 である。
タスク規模が小さく言語が明確なため、`orchestrator-coding` ではなく言語スキル単独で処理する。
境界: フェーズ統括（6 フェーズの実装ワークフロー）・複数言語・設計判断が必要になる場合は `orchestrator-coding` を使う。

## 関連ケース

- [case-02_scope-escalation.md](case-02_scope-escalation.md)（変更見込みが単独処理の想定規模を超えた場合の切替提案との対比）
