# 結合テスト実行手順（integration-execution）

`test-run-integration` スキル固有の実行手順。IT-a（内部結合）/ IT-b（外部結合）の実行方法・スタブ判断の運用・API 補助確認（curl）・機微情報マスキングを定める。
スタブポリシーの判断基準は `${CLAUDE_PLUGIN_ROOT}/references/test-levels.md` 5 章、Playwright MCP のツール定義・利用規約は `playwright-mcp.md`、共通規範（中間結果フォーマット・status 意味論・タイムアウト・エビデンス要件・マスク形式）はプラグイン共通 references を正とし、本書では複製しない。

---

## 1. IT-a（内部結合 / `integration-internal` / TC-ITA）の実行手順

対象は同一システム内のモジュール間・画面間の連携（定義・観点は test-levels.md 4.3 節）。

### 1.1 ブラウザ操作の基本

- 要素操作は「browser_snapshot で要素 ref を取得 → 操作ツール（browser_click / browser_type 等）に ref を渡す」を基本パターンとし、各ステップ後にスクリーンショットを取得して直後に移送する（5 章）
- 待機は browser_wait_for による条件待機を優先する（固定スリープ禁止。playwright-mcp.md）

### 1.2 画面間遷移フローの確認

1. steps に従い、起点画面から遷移フローを順に実行する（遷移のたびにスクリーンショット取得 → 移送）
2. 遷移先で URL・画面固有要素・引き継ぎパラメータの反映を browser_snapshot で確認する
3. 遷移が想定と異なる場合（エラー画面・想定外の画面）は fail とし、遷移元・遷移先両方の証跡を残す

### 1.3 データ受け渡しの突合

モジュール間のデータ整合（登録 → 参照・更新 → 反映）は、以下の突合手順で確認する。

1. **登録側**: 登録画面で入力した値（ケースの data に定義）を実施記録に残し、登録完了時点のスクリーンショットを取得する
2. **参照側**: 参照画面・一覧画面へ遷移し、browser_snapshot で表示値を取得する（表示が非同期の場合は browser_wait_for で反映を待つ）
3. **突合**: 登録値と参照値を項目ごとに対比し、**突合結果（登録値 / 参照値の対比）を actual に記録する**（test-levels.md 4.3 節の出口基準）
4. 不一致があれば fail とし、登録側・参照側両方のスクリーンショットを defect.evidence に含める（7 章）

### 1.4 状態遷移・エラー伝播の確認

- 業務データの状態遷移（例: 申請 → 承認待ち → 承認済み）は、状態を変更する操作のたびに参照側で状態表示を確認する
- モジュール境界でのエラー伝播は、境界の片側でエラーを発生させ、もう片側での表示・挙動（エラーメッセージ・ロールバック）を確認する

---

## 2. IT-b（外部結合 / `integration-external` / TC-ITB）の実行手順

対象は外部システム・外部 API との連携（定義・観点は test-levels.md 4.4 節）。

### 2.1 外部疎通の事前確認

ケース実行前に外部接続先（テスト用エンドポイント）の疎通を確認する。

| 確認手段 | 方法 |
|---------|------|
| 画面経由 | 外部 IF を呼び出す操作を実行し、browser_network_requests で外部呼び出しの発生・応答ステータスを観測する |
| API 直接（補助） | Bash（curl）で疎通確認する（4 章。認証不要のヘルスチェック等があればそれを優先） |

- 疎通不可が判明した場合は 3 章のスタブ判断へ進む（即座に skipped とせず、まずポリシー判断を行う）

### 2.2 連携確認の実施

1. steps に従い、外部 IF を呼び出す操作を画面から実行する
2. 呼び出し結果の反映を確認する: 画面表示（browser_snapshot）・データ反映（参照画面での確認）・外部呼び出しの応答（browser_network_requests）
3. 異常応答・タイムアウト時の自システムの振る舞い（エラーハンドリング・リトライ）を確認するケースでは、発生させた条件と観測結果を actual に記録する
4. 画面から観測できない応答内容の確認が必要な場合は API 補助確認（4 章）を併用する

---

## 3. 外部接続不可時のスタブ判断（運用手順）

**判断基準の SSOT は test-levels.md 5 章（スタブポリシー）**。本章は判断に必要な情報の集め方と記録方法のみを定める。

### 3.1 判断手順

1. **検証目的の特定**: ケースの title / requirement / expected から、目的が「自システム側の外部 IF 処理（送信データ生成・応答処理・エラーハンドリング）の検証」か「実外部システムとの疎通・契約整合そのものの検証」かを特定する
2. **スタブの存在確認**: プロジェクト内のモックサーバー設定・スタブ構成（設定ファイル・docker-compose のモック定義・テスト用プロファイル等）を Glob / Grep で探索する
3. **判断**: test-levels.md 5.2 の表に照らして「スタブ実行」か「skipped」を決定する
4. **簡易スタブの用意**: 「簡易に用意できる」場合に限り可（ケースの目的達成に必要な最小応答を返すローカルスタブが既存の仕組みで即座に構成できる場合のみ）。大きな工数を要するなら skipped とする。スタブ新設は対象プロジェクトのソース変更を伴わない範囲に限る

### 3.2 スタブ実行時の記録

- actual に「スタブ応答による確認である旨」と「**実接続未検証**」を明記する
- スタブの内容（何を模擬したか・応答定義の場所）を実施記録に残し、返却時の特記事項として報告する（run の environment への反映・報告書の未確認事項への転記はオーケストレータ / test-report が行う）
- スタブ実行で pass しても IT-b レベルの実接続検証が完了したと扱わない（test-levels.md 5.2）

### 3.3 skipped 時の記録

- reason に判断根拠を記録する（例: 「実接続でのみ検証可能な疎通確認のためスタブでは目的を達成できない」「スタブ未整備・実接続不可」）
- skipped は環境整備後の再テスト対象となる（retest-policy.md）

---

## 4. API 補助確認（Bash / curl）

### 4.1 用途

画面経由では確認できない項目の直接確認に用いる（応答ボディの詳細・HTTP ステータスコード・データ反映の裏取り）。ブラウザ操作の代替ではなく補助である。

### 4.2 実行方法

```bash
# 応答ボディとステータスコードを取得する例（一時ファイルはセッション作業領域へ）
curl -sS --max-time 30 \
  -w '\nHTTP_STATUS:%{http_code}\n' \
  -o "<セッション作業領域>/workspace/tmp/{case_id}_api-response.json" \
  "<テスト用エンドポイント URL>"
```

- `--max-time` を必ず設定し、ケースタイムアウトの範囲内で制御する
- 一時出力はセッション作業領域の `workspace/tmp/` に置き、マスキング（4.4）後にエビデンスへ保存する（5 章）

### 4.3 認証が必要な場合

- **credentials-manager 系スキルの利用をユーザーに案内**し、認証情報の解決・適用はそちらに委ねる（本スキルで認証情報を保存・管理しない）
- 認証情報の**フル値**をチャット出力・ログ・reason / actual・エビデンス・コマンド文字列の記録に含めない
- コマンド例をエビデンス・再現手順に残す場合は、Authorization ヘッダ等の値をマスクした形で記載する（マスク形式は evidence-policy.md 5 章）
- マスクにより再現に必要な情報が欠ける場合は、値そのものではなく「値の取得方法・格納場所」を reproduction_steps に記載する（evidence-policy.md）

### 4.4 マスキング手順

1. 保存前に応答・ログ内の機微情報（トークン・パスワード・個人情報。対象分類は evidence-policy.md 5 章）を sed 等で置換する
2. 保存後に Grep でマスク漏れを確認する（`Bearer` / `token` / `password` / `authorization` 等のキー周辺を点検）
3. マスク済みであることを確認してからエビデンスディレクトリへ配置する

---

## 5. エビデンス（画面 + API レスポンス）

| 収集物 | 取得・配置 |
|--------|-----------|
| 画面スクリーンショット | 各ステップ後に browser_take_screenshot（filename: `{case_id}_{NN}_{label}.png`）→ **直後に** `evidence/{run_id}/{case_id}/` へ move し `{NN}_{label}.png` へ揃える（移送規約は data-locations.md 5 章・命名は evidence-policy.md 4 章） |
| API レスポンス | マスキング（4.4）済みのテキストを `evidence/{run_id}/{case_id}/93_api-response.json` 等として Bash で直接保存する |
| ネットワーク観測 | browser_network_requests の結果（外部呼び出しの URL・ステータス）をテキスト保存: `92_network.txt` |
| 失敗時の追加収集 | 失敗時点のスクリーンショット + browser_snapshot（`91_snapshot.txt`）+ browser_console_messages（`90_console-log.txt`） |

- raw 出力先は既定で `.claude/.local/plugins/deep-test/playwright/` だが、既存 MCP 登録の output-dir 設定に従い異なる場合がある（playwright-mcp.md 2 章）。移送規約の適用は不変
- duration_sec はケース開始から結果確定までの経過時間を記録する

---

## 6. status 判定の分岐（実行不能・中断系）

| 状況 | status | 備考 |
|------|--------|------|
| MCP ツール未ロード（初回操作前・実行中の喪失） | skipped + reason | 二重防御。オーケストレータの MCP ゲートで通常は事前遮断（execution-policy.md 2 章） |
| 対象アプリの URL へ接続不能が即時判明 | skipped + reason | 実行手段（対象アプリケーション）不在（execution-policy.md 2 章） |
| IT-a: 連携対象モジュールが環境に未統合 | blocked + reason | 入口基準未充足・前提不成立（test-levels.md 5.1: 統合完了まで blocked） |
| IT-b: 外部接続不可 + スタブで目的達成可能 | スタブ実行して pass / fail 判定 | actual にスタブ利用・実接続未検証を明記（3.2） |
| IT-b: 外部接続不可 + 実疎通そのものの検証 / スタブ未整備 | skipped + reason | test-levels.md 5.2 |
| 操作・応答なしのままケースタイムアウト超過 | blocked + reason | 経過時間・最後に完了したステップを記録（execution-policy.md 8 章） |
| `depends_on` の依存先が同一 run 内で fail / blocked | blocked + reason | 依存先ケース ID とその結果を記録（execution-policy.md 5 章） |
| preconditions のデータ前提が満たせない | blocked + reason | 前提不成立の内容を記録 |

- blocked / skipped / na の意味論は yaml-schema-results.md 6 章を正とする

---

## 7. defect の組み立て（fail 時）

fail 判定の確定直後（次ケースへ進む前）に、以下をその場で収集する。3 点セットの必須要件は evidence-policy.md 1 章を正とする。

| 3 点セット | 本スキルでの内容 |
|-----------|----------------|
| `reproduction_steps` | 環境情報（OS・ブラウザ・対象 URL・ビルド・外部接続先 or スタブの別）を先頭に、複数画面にまたがる操作列全体（入力値含む）を番号付きで再構成し、発生条件を付す |
| `test_data` | データ受け渡し不一致では「入力値（登録値）・期待値（参照画面での期待表示）・実際値（実表示）」を項目ごとに明記する。API 連携ではリクエスト内容（マスク済み）と期待 / 実際の応答 |
| `evidence` | 登録側・参照側（または呼び出し前後）のスクリーンショット + 必要に応じマスク済み API レスポンス（`93_api-response.json`）の相対パス |

- `defect.severity` は severity-policy.md の判定フローに従う（迷ったら高い側に倒す）
- postconditions（作成データの削除・状態復元）は fail 時も実行し、失敗した場合は隠蔽せず記録する

---

## 8. automation: playwright-test の実走経路（`npx playwright test`・MCP 経路と併存）

本章は `automation: playwright-test` のケースを実走する経路を定める。1〜7 章の Playwright MCP + API 補助確認の経路（`automation: playwright` / `api`）とは**併存**し、既存の MCP・API 補助確認・manual-assist 経路を置き換えない。各ケースの `automation` 値で経路を選ぶ。

### 8.1 前提（実走のみ・テストコードは生成しない）

- `fixtures.yaml`（`{base}/{target-slug}/fixtures.yaml`）と SUT テストコード（`test_root` 配下の `.spec.ts` / `playwright.config.ts` / フィクスチャ）が既に存在すること。これらの**生成は test-fixture（Phase 1.6）の責務**であり、本スキルは**実走のみ**を行い SUT テストコードを生成・改変しない
- ケースの `fixtures:` が参照する `fixtures.yaml` の `fixtures[].name` が実在すること（スキーマ・実行規約は `${CLAUDE_PLUGIN_ROOT}/references/playwright-test.md`）

### 8.2 IT-a / IT-b の再現可能実走

- **IT-a（内部結合）**: 複数画面にまたがる遷移・データ受け渡しの検証を `.spec.ts` として実走する。シード / 認証フィクスチャ（fixtures.yaml の `seed` / `auth`）で前提データ・ログイン状態を再現する
- **IT-b（外部結合）**: 外部依存を fixtures.yaml の**モックフィクスチャ**（`type: mock`・`route.fulfill` / network interception）で差し替え、実外部接続なしに再現可能な連携検証を行う。成功 / 失敗 / タイムアウト応答をモックで切り替え、自システムのエラーハンドリングを検証する（3 章のスタブ判断は MCP 経路の運用。playwright-test 経路ではモックフィクスチャがその役割を担う）
- モックで差し替えた IT-b は**実接続を検証していない**ため、実疎通・契約整合の検証が目的のケースは MCP 経路 + 実接続、またはモック未整備として `skipped` + reason とする（実接続検証をモック pass で代替しない。test-levels.md 5 章の趣旨を継承）

### 8.3 実行（Bash）とエビデンス化

- `npx playwright test` を Bash で実行する（`--project` / spec パス指定）。Bash 実行の書式は既存 Bash 呼び出し規約（4 章の `curl` 補助確認等）に合わせる。Playwright は node/npx 実行であり `run_via_job.sh` ラッパーは不要

```bash
# SUT の project= ルートで対象 spec を実走する例（モックフィクスチャ利用・JUnit + line レポート）
cd "<SUT の project= ルート>" && npx playwright test tests/<対象>.spec.ts --project=authenticated --reporter=line,junit
```

| runner の結果 | ケース status |
|--------------|--------------|
| 対象テストが全 pass | `pass`（IT-b がモック実行なら actual に「モック応答・実接続未検証」を明記） |
| 対象テストに fail が含まれる | `fail`（JUnit・トレースから 7 章の 3 点セットを組み立てる） |
| 設定エラー等でテスト自体が実行されなかった | `blocked` + reason |

- エビデンス: stdout / stderr ログ・JUnit XML・HTML レポート・失敗時トレースを `evidence/{run_id}/{case_id}/` へ保存する（テストランナー実行時のエビデンス収集は `${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 7 章に準ずる。命名例: `80_playwright-stdout.txt` / `81_junit.xml`）。API レスポンスをログに含む場合は保存前に機微情報をマスクする（4.4）
- `executed_by` は `playwright-test` を記録する（`playwright-mcp` / `api` と混同しない）

### 8.4 SKIPPED 規範（実行手段不在時・偽装禁止）

- Playwright 本体・テストランナー（`npx playwright test`）が未導入、または `fixtures.yaml` / SUT テストコードが不在の場合は、実行を偽装せず当該ケースを `skipped` + reason で返す（`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 2 章・`playwright-test.md`）。「未実施」を「問題なし」と書かない

---

## 9. 関連 references

| 参照先 | 内容 |
|-------|------|
| `${CLAUDE_PLUGIN_ROOT}/references/test-levels.md` | IT-a / IT-b の定義・入口基準の違い・スタブポリシー（5 章。唯一の判断基準） |
| `${CLAUDE_PLUGIN_ROOT}/references/playwright-mcp.md` | 正本ツールリスト・filename 指定・待機規範・raw 出力先 |
| `${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` | 中間結果返却フォーマット・条件付き動的検証・タイムアウト・環境安全 |
| `${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` | raw 出力からの移送規約・エビデンス配置パス |
| `${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` | fail 時 3 点セット・機微情報のマスク形式と対象・エビデンス命名 |
| `${CLAUDE_PLUGIN_ROOT}/references/severity-policy.md` | severity 判定基準（唯一の SSOT） |
| `${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` | status enum・defect フィールド定義 |
| `${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-cases.md` | automation と executed_by の対応 |
| `${CLAUDE_PLUGIN_ROOT}/references/playwright-test.md` | `npx playwright test` + fixtures.yaml（モックフィクスチャ）の実行規約（8 章の playwright-test 実走経路） |
