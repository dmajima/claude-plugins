# ユニットテスト実行手順（unit-execution）

`test-run-unit` スキル固有の実行手順。テストランナーの検出・ランナー別実行・出力解析・ケースマッピング・エビデンス保存の方法を定める。
共通規範（中間結果フォーマット・status 意味論・タイムアウト・エビデンス要件・severity 判定）はプラグイン共通 references（`${CLAUDE_PLUGIN_ROOT}/references/`）を正とし、本書では複製しない。

---

## 1. テストランナー検出

### 1.1 検出規則（SSOT 参照）

検出規則（構成ファイル・テストファイル規約フォールバック・宣言の 3 段評価と、構成ファイル別の判定材料）の SSOT は
`${CLAUDE_PLUGIN_ROOT}/skills/test-setup/references/setup-procedures.md` 4 章であり、本書には複製しない。

### 1.2 実行時の再確認手順

1. test-setup の環境検証レポート（検出ランナー・根拠・実行コマンド例）を引き継いでいる場合は、それを第一入力として採用する
2. 引き継ぎがない・内容が現状と食い違う場合は、SSOT の検出規則（3 段評価）で再検出する
3. 複数候補が該当する場合は、テストコードの存在を確認できたランナーを優先し、混在プロジェクトでは対象ケースのパターン記述（2 章）と照合して選定する
4. 無害なコマンド（`--version` 等）でランナー実体の起動可否を確認する

### 1.3 プロジェクト環境の尊重

| 環境 | 尊重方法 |
|------|---------|
| Python venv | プロジェクト直下の `.venv/` / `venv/` を検出したら、その python 実体（Windows: `Scripts/python.exe`、他: `bin/python`）で `-m pytest` を実行する。poetry / uv / pipenv のロックファイル検出時は `poetry run pytest` 等の環境マネージャ経由を優先する |
| Node.js | プロジェクトの node_modules を利用する（`npx` / `npm test`）。グローバルインストールに依存しない |
| .NET / Go / Java / Rust | プロジェクト標準のビルドツール経由で実行する（dotnet / go / mvn / gradle / cargo） |
| 未導入 | ランナー・依存パッケージを導入しない（環境構築は `test-setup` の責務）。実行不能なら skipped + reason で返却する |

### 1.4 検出不能時の判定

| 状況 | 判定 | reason の例 |
|------|------|------------|
| 検出規則（SSOT の 3 段評価）でランナーを特定できない | scope 全ケース skipped | テストランナー未検出（構成ファイル・テストファイル規約とも該当なし） |
| ランナーは特定できたがテストコードが存在しない | scope 全ケース skipped | テストコード不在（tests/ 配下に対象テストなし） |
| ランナーコマンドが実行不能（コマンド不在・起動エラー） | scope 全ケース skipped | pytest 実行不能（venv 未構築・コマンド不在） |

- 実行を偽装せず、実際の原因を reason に記載する（条件付き動的検証。execution-policy.md 2 章）

---

## 2. ケースとテストの対応付け（マッピング）

### 2.1 対応付けの根拠情報

test-cases.yaml のケースは、`data` または `steps` にテスト名・パターンを記載する前提とする（設計時の推奨は `data` への記載）。

| 記載場所 | 記載例 |
|---------|--------|
| `data`（map） | `test_pattern: "tests/test_calc.py::test_add"` / `test_pattern: "CalcTests.AddTest"` |
| `data`（string） | `対象テスト: tests/test_login.py::TestLogin` |
| `steps` | 「1. tests/test_login.py::TestLogin を pytest で実行する」 |

### 2.2 対応付け手順

1. ケースごとにテスト名・パターンを抽出する（ファイルパス::テスト名 / クラス名.メソッド名 / `-k` 式 / `--filter` 式）
2. 実行結果の個別テスト識別子（pytest の nodeid / jest・vitest のテストフルネーム / dotnet の FQN / go の Test 関数名）と突合する
3. 1 ケース : N テストの対応を許容する。パターンに複数テストが合致する場合、**全テスト pass のときのみ当該ケースを pass** とする。1 件でも fail / error があれば fail、実行されたテストが 0 件なら 2.3 に従う

### 2.3 対応付け不能時の判定

| 状況 | status | reason の例 |
|------|--------|------------|
| ケースにテスト名・パターンの記載がない | blocked | ケース定義にテスト対応付け情報がない（test-design での data / steps 補完が必要） |
| パターンに合致するテストが存在しない（収集 0 件） | skipped | 対象テストコード不在（パターン「…」に合致するテストなし） |

- blocked（テスト論理上の前提不成立）と skipped（実行手段不在）の意味論は yaml-schema-results.md 6 章を正とする

---

## 3. 実行方式とタイムアウト

### 3.1 実行方式の選択

| 方式 | 使いどころ | 実行 |
|------|-----------|------|
| 一括実行（既定） | scope のケース数が多い・全体回帰 | scope 全ケースのパターンを結合（pytest: 複数 nodeid 引数 / dotnet: `--filter` の or 結合 等）して 1 回実行し、結果を各ケースへ振り分ける |
| ケース別実行 | ケース単位の duration_sec を正確に計測したい・タイムアウトをケース単位で制御したい・テスト間の干渉が疑われる | ケースごとにパターン指定で個別に実行する |

- 一括実行時の `duration_sec` は、ランナー出力の個別テスト時間を採用できればそれを記録し、取得不能なら全体時間を案分せず null とする（値を偽装しない）

### 3.2 タイムアウト制御

| 方式 | 上限 | 超過時 |
|------|------|--------|
| ケース別実行 | 当該ケースの `timeout_sec`（既定 120 秒。yaml-schema-cases.md） | 当該ケースを blocked + reason（タイムアウト発生の旨・経過時間・最後に完了したステップ）とし、次ケースへ進む |
| 一括実行 | scope 内ケースの `timeout_sec` 合計を上限の目安として Bash の timeout パラメータで制御 | 完了済みテストに対応するケースは結果を採用し、未完了のケースは blocked + reason（一括実行タイムアウト）とする |

### 3.3 実行時の注意

- 解析精度を上げるため、ランナーの機械可読出力を併用する（pytest: `--junitxml=<一時ファイル>` / jest: `--json --outputFile=<一時ファイル>` / vitest: `--reporter=json` / dotnet: `--logger trx` 等）。一時ファイルはセッション作業領域の `workspace/tmp/` に出力し、解析後に必要分をエビデンスへ保存する
- watch モード・対話モードを無効化する（jest: `--ci` / vitest: `run` サブコマンド）
- リトライ・再実行で結果を上書きしない。フレーク（不安定テスト）検出時は実際の結果と再現率を actual に記録する

---

## 4. 出力解析

### 4.1 抽出項目

| 項目 | 用途 |
|------|------|
| pass / fail / error / skip 件数 | scope 突合・サマリ確認 |
| 失敗テスト識別子（nodeid / FQN 等） | ケースマッピング（2 章） |
| 失敗理由・アサーションメッセージ | actual・defect（test_data）の記述 |
| スタックトレース | `defect.extras.stack_trace` への記録 |
| 個別テストの実行時間 | duration_sec（取得できる場合） |

### 4.2 ランナー別の解析ポイント

| ランナー | テキスト出力の目印 | 機械可読出力 |
|---------|-------------------|-------------|
| pytest | `PASSED` / `FAILED` / `ERROR` 行、`=== FAILURES ===` セクション、末尾サマリ行（`X passed, Y failed`） | junitxml（testcase 要素の failure / error 子要素） |
| jest / vitest | チェックマーク / バツ印の行、`● <テスト名>` の失敗詳細ブロック | `--json` 出力の testResults |
| dotnet test | `Passed!` / `Failed!` サマリ、`Failed <FQN>` 行とスタックトレース | trx（UnitTestResult 要素） |
| go test | `--- FAIL: <Test名>` 行、パッケージごとの `ok` / `FAIL` 行 | `-json` フラグの出力 |

### 4.3 error と fail の扱い

- 対象テストのアサーション不一致（failure）と実行時エラー（error: 例外・当該テストの収集エラー等）は、いずれも該当ケースの **fail** として扱い、種別を actual に明記してスタックトレースを記録する
- ランナー自体が起動不能（コマンドエラー・構成破損で 1 件もテストを収集できない）な場合は、実行手段の問題として scope 全ケースを skipped + reason とし、起動失敗ログをエビデンス保存する

---

## 5. エビデンス保存

| 収集物 | 保存先・命名 |
|--------|-------------|
| ランナー実行ログ（当該ケース関連の抜粋。全体サマリ行を含める） | `evidence/{run_id}/{case_id}/90_runner-log.txt` |
| fail 時スタックトレース | `evidence/{run_id}/{case_id}/91_stack-trace.txt`（`defect.extras.stack_trace` にも転記） |
| 機械可読出力の該当部分（任意） | `evidence/{run_id}/{case_id}/92_junit-extract.xml` 等 |

- 保存先の基準ディレクトリ解決・パス規約は data-locations.md、命名原則（ステップ番号 2 桁プレフィクス）は evidence-policy.md 4 章に従う
- ユニットは Playwright raw 出力（`playwright/`）を経由しないため移送は不要。エビデンスディレクトリへ直接保存してよい（Bash の heredoc / リダイレクトで UTF-8 保存）
- 可能な場合は `pytest --junitxml=<evidence 配下のパス>` や出力リダイレクトで、生ログ・機械可読出力を evidence ディレクトリへ**直接出力**する（LLM の手を経由しない証跡を優先する）。抜粋転記は直接出力が困難な場合の代替とする
- 1 ケースのエビデンスは当該ケースのディレクトリに集約する。一括実行の全体ログを複数ケースで共有参照せず、ケース関連の抜粋を各ケースのディレクトリへ保存する

---

## 6. defect の組み立て（fail 時）

fail 判定の確定直後（次ケースへ進む前）に、以下をその場で収集する。3 点セットの必須要件は evidence-policy.md 1 章を正とする。

| 3 点セット | 本スキルでの内容 |
|-----------|----------------|
| `reproduction_steps` | 環境情報（OS・ランタイムバージョン・ランナー名とバージョン・実行ディレクトリ）を先頭に、実行コマンド・失敗テスト識別子・発生条件（毎回再現 / フレークなら再現率）を番号付きで記述する |
| `test_data` | 失敗テストの入力値・期待値・実際値（アサーションメッセージ・テストコードから抽出） |
| `evidence` | `90_runner-log.txt` / `91_stack-trace.txt` 等の相対パス（1 件以上・実在するファイル） |

- `defect.severity` は severity-policy.md の判定フローに従う（判定に迷ったら高い側に倒す）
- `extras.stack_trace`: スタックトレースの主要部（原因箇所を含む）を記録する。長大な場合の全文は `91_stack-trace.txt` に保存し、パスを evidence に含める

---

## 7. コンテナ内 exec 実行経路（environment.yaml の exec_forms[]・ホスト実行と併存）

本章は、ホストにランタイム / テストランナーが無い場合の**代替経路**として、test-environment（Phase 1.7）が environment.yaml に記録した `exec_forms[]`（コンテナ内ランナー実行形）で実行する経路を定める。1〜6 章のホスト実行経路とは**併存**し、既存のホスト実行・manual-assist 経路を置き換えない（environment.yaml のスキーマ SSOT は `${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-environment.md`）。

### 7.1 実行経路の優先順位

| 優先 | 条件 | 経路 |
|------|------|------|
| 1（既定・不変） | ホストでランナーを検出・実行可能（1 章） | 従来どおりホスト実行 |
| 2（代替） | ホストにランタイム / ランナーが無く、environment.yaml（`{base}/{target-slug}/environment.yaml`）の `exec_forms[]` に該当ランナーの実行形（`purpose: unit`。`runner_hint` / ケースのパターン記述と整合）があり、環境が稼働状態（`status.state: up / healthy`） | コンテナ内 exec 実行 |
| 3 | どちらの手段も無い | 従来どおり skipped + reason（1.4 の判定・意味論・文言のまま） |

- environment.yaml が存在しない、または `meta.applicability` が `applicable` 以外（`not-applicable` / `unavailable`）の場合は、本経路自体が存在しない（従来動作のまま 1.4 で判定する）
- 環境が未起動（`status.state: provisioned / down / unknown`）の場合は本経路を選択しない（up は test-environment / オーケストレータの責務。本スキルは環境を起動しない）
- health 未達の環境（`status.state: degraded`）で実行前提が成立しない場合は blocked + reason（環境はあるがテスト論理上の前提不成立。skipped との使い分けは yaml-schema-results.md 6 章・yaml-schema-environment.md 12 章に整合）

### 7.2 実行形（記録値をそのまま用いる）

- `exec_forms[].command_template`（lifecycle の `-f` 群 + `-p {slug}-test` を含む完全形。例: `docker compose -f <SUT compose> -f environment/compose.test.yml -p {slug}-test exec -T <service> <runner コマンド>`）の記録値をそのまま Bash で用い、`<runner コマンド>` 部にランナーの実行引数（対象パターン・機械可読出力オプション）を与える
- `-f` 群・`-p`・サービス名を自分で組み立て直さない（分離名前空間の破壊・SUT 側 override の自動読込混入を防ぐ）。environment.yaml は読み取りのみとし、environment.yaml / SUT の docker 資産へ書き込まない

### 7.3 結果解釈（ホスト実行と同一規範）

- exit code・出力解析（4 章）・ケースマッピング（2 章）・実行方式とタイムアウト（3 章）・エビデンス保存（5 章）・defect 組み立て（6 章）は**ホスト実行と同一規範**で行う
- 機械可読出力（junitxml 等）はコンテナ内パスに出力されるため、ボリューム共有で取得できない場合は stdout 経由（`exec -T` の標準出力・リダイレクト）で回収してエビデンス保存する
- `executed_by` は `test-framework` のまま変えない（新しい enum 値を追加しない）。実行場所がコンテナ内 exec である旨（用いた実行形・サービス名）を actual / defect の reproduction_steps（環境情報）に記録する

---

## 8. 関連 references

| 参照先 | 内容 |
|-------|------|
| `${CLAUDE_PLUGIN_ROOT}/skills/test-setup/references/setup-procedures.md` | テストランナー検出規則の SSOT（4 章） |
| `${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` | 中間結果返却フォーマット・条件付き動的検証・タイムアウト・テストデータ分離 |
| `${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` | status enum・defect フィールド定義 |
| `${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-cases.md` | automation と executed_by の対応 |
| `${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` | fail 時 3 点セット・reason 必須・エビデンス命名 |
| `${CLAUDE_PLUGIN_ROOT}/references/severity-policy.md` | severity 判定基準（唯一の SSOT） |
| `${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` | エビデンス配置パス・基準ディレクトリ解決 |
| `${CLAUDE_PLUGIN_ROOT}/references/test-levels.md` | ユニットテストの定義・入口/出口基準（4.1 節） |
| `${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-environment.md` | environment.yaml（`exec_forms[]` / `status` / `applicability`）のスキーマ SSOT（7 章のコンテナ内 exec 代替経路の入力） |
