# case-04 テストランナー検出結果の返却形式

対象プロジェクトからテストランナーを検出し、根拠ファイル・実行コマンド例を併記した形式で報告することを検証する（検出のみで実行しないことを含む）。

## 入力

| 項目 | 内容 |
|-----|------|
| 起動フレーズ | 「このリポジトリのテストランナーを検出して」（`checks=runner` 相当） |
| 起動形態 | 単独（ユーザー直接起動） |
| 前提 | 対象リポジトリはモノレポ構成: `api/pyproject.toml`（`[tool.pytest.ini_options]` あり）と `web/package.json`（devDependencies に vitest あり）が存在 |

## 分岐の根拠

SKILL.md「責務」3（検出のみ。実行しない）・「検証」（根拠ファイルと実行コマンド例の併記）・「重要な制約」（検出したテストランナーを本スキルで実行しない）、references/setup-procedures.md 2 章（`checks=` 指定によるチェック対象の限定）・4 章（検出根拠表・複数ランナーの列挙・生成物ディレクトリの除外）・7 章（引き継ぎ事項に test-run-unit が利用できる粒度で記載）。

## 期待動作

- Glob / Read / Grep で設定ファイルを探索・確認する（`node_modules` / `.venv` 等の生成物ディレクトリを探索対象から除外する）
- pytest（根拠: `api/pyproject.toml` の `[tool.pytest.ini_options]`）と vitest（根拠: `web/package.json` の devDependencies）の**両方**を検出し、片方だけで打ち切らない
- 検出したランナーを実行しない（`python -m pytest` / `npx vitest run` 等のコマンドを発行しない）
- 環境検証レポートのテストランナー行を `detected` とし、詳細欄に各ランナーの「ランナー名・根拠ファイル（相対パス）・実行コマンド例・対象ディレクトリ」を列挙する
- `checks=runner` 指定のため、Playwright MCP と venv の行は `not-checked` として残す（行を省略しない）
- 引き継ぎ事項に test-run-unit への引き継ぎ（検出ランナーの詳細）を含める

## 期待出力

| 区分 | 内容 |
|-----|------|
| 生成ファイル | なし（検出のみで実行・構築を行わない。test-results.yaml へは書き込まない） |
| 標準出力（要約） | 環境検証レポート（ランナー = detected〔pytest / vitest を根拠ファイル・実行コマンド例付きで列挙〕/ MCP 登録・ロード・venv = not-checked）+ test-run-unit への引き継ぎ事項 |
| 終了状態 | 総合判定 READY（not-checked は判定を妨げない） |

## 関連ケース

- case-05: levels からのチェック対象導出（runner チェックは unit を含む場合のみ）
