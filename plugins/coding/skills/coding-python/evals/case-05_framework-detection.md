# Case 05: Flask 検出 → python-web.md プロファイル併用

## 入力

| 項目 | 値 |
|-----|---|
| 起動フレーズ | 「この Flask アプリに health check の API エンドポイントを追加して」 |
| 引数 | なし |
| フラグ | なし（対話モード） |
| 既存状態 | Python プロジェクト。依存定義（`requirements.txt` / `pyproject.toml`）に `flask` があり、既存の `app.py` に Flask アプリが定義済み。変更見込みは 1〜2 ファイル |

## 期待動作

### ステップ1: 規約解決
- SSOT `../../../references/conventions-resolution.md` に従いプロジェクト独自規約（`pyproject.toml` の `[tool.ruff]` 等・`.editorconfig`・`CLAUDE.md`・既存慣習）を走査し、無い項目は [references/conventions.md](../references/conventions.md) のデファクト規約（PEP 8 / PEP 257）を適用する

### ステップ2: FW 確認（本ケースの分岐点）
- 実行フロー step2「FW 確認」に従い、依存定義に `flask` を検出する
- [references/frameworks/python-web.md](../references/frameworks/python-web.md)（Flask / Django / FastAPI プロファイル）を規約・構造の一次情報源として併用対象に加える
- ルーティング・リクエスト検証・エラーハンドリング等の Flask 固有の書き方は python-web.md に従う（言語自体の規約は [references/conventions.md](../references/conventions.md)）

### ステップ3以降: 実装・検証・報告
- 解決した言語規約 + Flask プロファイルに従ってエンドポイントを実装する。`open()` の `encoding` 明示など [references/conventions.md](../references/conventions.md) の必須事項を維持する
- 利用可能なツールチェーン（`pytest` / `ruff` 等）を venv 経由で検証する（実行不能は SKIPPED として報告）
- 変更ファイル・適用したプロファイル（Flask = python-web.md）と規約の根拠・検証結果を報告する

## 期待出力

| 項目 | 期待値 |
|-----|-------|
| 適用プロファイル | python-web.md（Flask）を [references/conventions.md](../references/conventions.md) と併用 |
| 生成ファイル | Flask 規約準拠のコード変更。報告に適用プロファイルを明記 |
| 終了状態 | 成功（単独実行モードの軽量フロー） |

## 分岐の根拠

このケースが分岐するトリガーは 依存定義に FW マーカー（`flask`）が存在する ことである。
実行フロー step2「依存定義に `flask` / `django` / `fastapi` があれば [references/frameworks/python-web.md](../references/frameworks/python-web.md) を併用する」に従い、FW プロファイルを判定基準に加える経路を検証する（FW マーカーが無ければ言語規約のみで進む case-01 と対照的）。

## 関連ケース

- [case-01_standalone-basic.md](case-01_standalone-basic.md)（FW 非検出・言語規約のみの基本フローとの対比）
- [case-02_scope-escalation.md](case-02_scope-escalation.md)（変更が 4 ファイル以上に膨らむ場合の orchestrator-coding 切替提案）
