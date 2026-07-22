---
name: coding-python
description: Python のコード実装・構造設計を PEP 8 とプロジェクト規約優先で支援する言語スキル。「Python で実装して」「この Python を直して」「pytest を追加して」等で起動する。Use when implementing or structuring Python code. SKIP if 4+ files/full phases (orchestrator-coding), design-only (orchestrator-design), or other languages (coding-*).
---

# Coding Python（Python 言語スキル）

Python のデファクト規約（PEP 8 / PEP 257）・コード構造・フレームワーク知識（Flask / Django / FastAPI）を提供する言語スキル。
オーケストレーター参照と単独起動時の軽量実装フローに対応する。

## 責務

- Python の規約・イディオム・ツールチェーン知識の提供（[references/conventions.md](references/conventions.md) が SSOT）
- Python Web フレームワーク固有規約の提供（[references/frameworks/python-web.md](references/frameworks/python-web.md)）
- 単独起動時の軽量実装フロー（規約解決 → 実装 → 検証）
- 設計モードでのコード構造ガイダンス（モジュール構成・パッケージ配置・レイヤ分割）

## 責務外（他が担当）

| 業務 | 担当 |
|-----|------|
| 6 フェーズの実装ワークフロー統括 | `orchestrator-coding` |
| 設計ワークフロー統括 | `orchestrator-design` |
| 規約の優先順位解決ルール | SSOT `../../references/conventions-resolution.md` |
| ORM（SQLAlchemy 等）の横断知識 | SSOT `../../references/frameworks/orm.md` |
| 他言語のコード | 対応する言語スキル（`../../references/skill-index.md`） |

## トリガー条件（単独実行モード）

- 「Python で実装して」「この Python コードを修正して」
- 「Flask の API を書いて」「pytest のテストを追加して」

起動しないケース:

- タスクが大きく全フェーズの統括が必要（→ `orchestrator-coding`）
- 設計書の作成のみ（→ `orchestrator-design`）
- Python 以外の言語（→ 該当する言語スキル）

## 前提

呼び出し前に以下が決まっていること:

1. 対象コードの言語が Python である（オーケストレーター経由では言語検出済み）
2. 対象リポジトリ（カレントディレクトリ基準）

言語が異なれば該当言語スキルを使う（対応表: `../../references/skill-index.md`）。

## 利用モード

| モード | 起動元 | 動作 |
|-------|-------|------|
| 参照モード | `orchestrator-coding` / `orchestrator-design` / サブエージェント | [references/conventions.md](references/conventions.md) と FW プロファイルを規約・構造の判定基準として提供する（本スキルはフェーズ制御を行わない） |
| 単独実行モード | ユーザの直接依頼（「Python で〜を実装して」） | 下記の軽量実装フローを実施する |

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| `--non-interactive` フラグあり | 非対話 | 確認をスキップし、最も保守的な解釈を採用して進行する（採用した判断は報告に記録） |
| 上記以外 | 対話 | 規約の矛盾・実装方針の拮抗は `AskUserQuestion` で確認する |

## 実行フロー（単独実行モード）

1. **規約解決**: SSOT `../../references/conventions-resolution.md` に従い、プロジェクト独自規約（`pyproject.toml` の tool 設定・`.editorconfig`・`CLAUDE.md`・既存慣習）を走査する。独自規約がない項目は [references/conventions.md](references/conventions.md) のデファクト規約を適用する
2. **FW 確認**: 依存定義に `flask` / `django` / `fastapi` があれば [references/frameworks/python-web.md](references/frameworks/python-web.md) を、SQLAlchemy 等の ORM があれば SSOT `../../references/frameworks/orm.md` を併用する
3. **実装**: 解決した規約とコード構造ガイダンスに従って実装する。既存ファイルの編集では周辺コードのスタイル・エンコーディング・改行コードを維持する
4. **検証**: 利用可能なツールチェーン（`pytest` / `ruff check` / `ruff format` / `mypy` 等、規約解決で確定したもの）で検証する。実行不能な検証は SKIPPED として報告する
5. **報告**: 変更ファイル・適用規約の根拠（独自規約 or デファクト）・検証結果を報告する。変更見込みが 4 ファイル以上に膨らむ場合は `orchestrator-coding` への切替を提案する

## 重要な制約

- 適用規約はプロジェクト独自規約を必ず優先する（デファクトによる上書き禁止。詳細: SSOT `../../references/conventions-resolution.md`）
- `open()` の `encoding` 明示・venv 経由実行など、[references/conventions.md](references/conventions.md) の必須事項を省略しない
- コミット・push はユーザの明示指示があるまで実行しない

## 参照

| 用途 | ファイル |
|-----|---------|
| Python 言語規約（PEP 8 / ツールチェーン / 典型エラー） | [references/conventions.md](references/conventions.md) |
| Flask / Django / FastAPI | [references/frameworks/python-web.md](references/frameworks/python-web.md) |
| 規約優先順位の解決（SSOT） | `../../references/conventions-resolution.md` |
| ORM 横断知識（SSOT） | `../../references/frameworks/orm.md` |
| 設計原則（SSOT） | `../../references/design-principles.md` |
