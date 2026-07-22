# 単体（機能）テスト実行手順（functional-execution）

`test-run-functional` スキル固有の実行手順。ケース steps と Playwright 操作の対応付け・expected の照合方法・エビデンス取得/移送・status 判定の分岐を定める。
Playwright MCP のツール定義・利用規約（正本ツールリスト・filename 指定・待機規範・出力先）は `${CLAUDE_PLUGIN_ROOT}/references/playwright-mcp.md` を、共通規範（中間結果フォーマット・status 意味論・タイムアウト・エビデンス要件）はプラグイン共通 references を正とし、本書では複製しない。

---

## 1. steps と Playwright 操作の対応付け

### 1.1 基本パターン

要素操作は「**browser_snapshot で要素 ref を取得 → 操作ツールに ref を渡す**」を基本とする（ref は直近 snapshot から取得）。
各ステップ実行後にスクリーンショットを取得し（3 章）、次ステップへ進む。

### 1.2 対応表

| ケース steps の記述例 | 対応する操作 |
|---------------------|-------------|
| 「〜画面を開く」「〜へアクセスする」 | browser_navigate |
| 「前の画面へ戻る」 | browser_navigate_back |
| 「〜ボタンを押下する」「〜リンクをクリックする」 | browser_snapshot（ref 取得）→ browser_click |
| 「〜に〜を入力する」 | browser_snapshot → browser_type |
| 「フォームに一括入力する」（複数項目） | browser_fill_form |
| 「〜を選択する」（ドロップダウン） | browser_select_option |
| 「Enter キーを押す」等のキー操作 | browser_press_key |
| 「〜にマウスオーバーする」 | browser_hover |
| 「確認ダイアログで OK を押す」 | browser_handle_dialog |
| 「新しいタブで〜を開く」「タブを切り替える」 | browser_tabs |
| 「画面幅を〜にする」（レスポンシブ確認） | browser_resize |
| 「〜が表示されるまで待つ」 | browser_wait_for（固定スリープ禁止） |
| 「ページ内の値を取得する」（表示値の詳細確認） | browser_evaluate |

- steps の記述が上表に直接対応しない場合は、操作の意図（クリック / 入力 / 確認）に分解して対応付け、分解結果を実施記録（再現手順の基礎）に残す

## 2. expected の照合方法

| expected の種別 | 照合手段 |
|----------------|---------|
| 表示テキスト・メッセージ | browser_snapshot のアクセシビリティツリーに期待テキストが存在するか |
| 画面遷移 | 遷移後の browser_snapshot のページ URL・タイトル・画面固有要素の存在 |
| 要素の状態（活性 / 非活性・チェック状態・選択値） | browser_snapshot の要素属性 |
| 非同期反映（動的表示） | browser_wait_for で出現・消滅を待機後に snapshot で確認 |
| レイアウト・視覚的確認 | browser_take_screenshot の画像確認（目視相当の判断であることを actual に明記する） |
| コンソールエラーの有無 | browser_console_messages |

- 照合結果は「期待値 / 実際値」を対比できる形で actual に記録する
- 期待テキストが見つからない場合は、browser_wait_for での待機を 1 回試してから判定する（描画途中の誤判定防止）。それでも不一致なら fail とする

## 3. エビデンス取得・移送手順

1. **取得**: 各ステップ実行後に browser_take_screenshot を **filename 指定**で実行する: `{case_id}_{NN}_{label}.png`（NN はステップ番号 2 桁・label は内容を表す英数字。命名は playwright-mcp.md 6 章の推奨形式）
2. **移送**: 取得の**直後**（次ステップに進む前）に、Bash で raw 出力先から `evidence/{run_id}/{case_id}/` へ move する（移送規約は data-locations.md 5 章。コピーではなく移動とし raw 出力先に残骸を残さない）
3. **移送時のリネーム**: ケースディレクトリ内ではケース ID プレフィクスが冗長なため、`{NN}_{label}.png` へリネームして evidence-policy.md 4 章の命名（ステップ番号 2 桁プレフィクス）に揃える（例: `TC-FUNC-001_01_login-page.png` → `01_login-page.png`）
4. **テキスト系**: browser_console_messages / browser_snapshot / browser_network_requests の取得結果は、Bash（heredoc / リダイレクト・UTF-8）で `evidence/{run_id}/{case_id}/` へ直接保存する（raw 出力を経ないため移送不要）。命名例: `90_console-log.txt` / `91_snapshot.txt` / `92_network.txt`

補足:

- raw 出力先は既定で `.claude/.local/plugins/deep-test/playwright/` だが、既存 MCP 登録の output-dir 設定に従い異なる場合がある（playwright-mcp.md 2 章）。実際の保存先はスクリーンショット取得結果の実パスで確認し、移送規約の適用（evidence への move）は不変とする
- duration_sec はケース開始から結果確定までの経過時間を計測して記録する

## 4. 失敗時の追加収集（defect 3 点セットの組み立て）

fail 判定の確定直後（次ケースへ進む前）に、以下をその場で収集する。3 点セットの必須要件は evidence-policy.md 1 章を正とする。

1. 失敗時点のスクリーンショット（当該ステップで未取得なら追加取得: `{case_id}_{NN}_fail.png` → 移送）
2. browser_snapshot の結果をテキスト保存（`91_snapshot.txt`）
3. browser_console_messages の結果をテキスト保存（`90_console-log.txt`）
4. `reproduction_steps`: 環境情報（OS・ブラウザ・対象 URL・ビルド情報）を先頭に、**実際に実施した操作列**（対応付け後の操作・入力値を含む）を番号付きで再構成し、発生条件（毎回再現か・特定条件下か）を付す
5. `test_data`: 入力値・期待値・実際値の 3 つを明記する
6. `defect.severity` を severity-policy.md の判定フローで付与する（迷ったら高い側に倒す）

- スクリーンショットに機微情報（パスワード・トークン等）が写り込まないよう手順を設計し、テキストログは保存前にマスキングする（マスク形式・対象は evidence-policy.md 5 章）

## 5. status 判定の分岐（実行不能・中断系）

| 状況 | status | 備考 |
|------|--------|------|
| MCP ツール未ロード（初回操作前の確認で不可・実行中の喪失） | skipped + reason | オーケストレータの MCP ゲートで通常は事前遮断されるが、二重防御として自スキルでも判定する（execution-policy.md 2 章） |
| 対象 URL への接続不能が即時判明（接続拒否・名前解決不能等） | skipped + reason | 実行手段（対象アプリケーション）不在（execution-policy.md 2 章） |
| 対象 URL・操作が応答なしのままケースタイムアウト超過 | blocked + reason | 経過時間・最後に完了したステップを reason に記録する（execution-policy.md 8 章） |
| `depends_on` の依存先ケースが同一 run 内で fail / blocked | blocked + reason | 依存先ケース ID とその結果を reason に記録し、当該ケースは実行しない（execution-policy.md 5 章） |
| preconditions のデータ前提・状態前提が満たせない | blocked + reason | 前提不成立の内容を reason に記録する |

- blocked / skipped / na の意味論（使い分け）は yaml-schema-results.md 6 章を正とする
- scope 外のケースへの依存が指定されている場合は、latest の結果を前提とした scope 決定（オーケストレータの責務）を信頼し、判断材料が渡されていない場合のみ blocked + reason（依存結果不明）とする

## 6. postconditions・後片付け

- ケースの postconditions（作成データの削除・ログアウト・状態復元）を実行し、失敗した場合は隠蔽せず actual / reason に記録する（execution-policy.md 5 章）
- scope 全ケース完了後、`playwright/`（raw 出力先）に残留ファイルがないか確認する。帰属不明ファイルがあれば警告として返却メッセージに含める（data-locations.md 5 章）
- 実行終了時の後片付けとして browser_close を実行する（後続の実行スキルは自ら browser_navigate して開始するため影響しない）

---

## 7. automation: playwright-test の実走経路（`npx playwright test`・MCP 経路と併存）

本章は `automation: playwright-test` のケースを実走する経路を定める。1〜6 章の Playwright MCP 経路（`automation: playwright`）とは**併存**し、既存の MCP・manual-assist 経路を置き換えない。各ケースの `automation` 値で経路を選ぶ。

### 7.1 前提（実走のみ・テストコードは生成しない）

- `fixtures.yaml`（`{base}/{target-slug}/fixtures.yaml`）と SUT テストコード（`test_root` 配下の `.spec.ts` / `playwright.config.ts` / フィクスチャ）が既に存在すること。これらの**生成は test-fixture（Phase 1.6）の責務**であり、本スキルは**実走のみ**を行う。SUT のテストコード・`playwright.config.ts` を生成・改変しない
- ケースの `fixtures:` が参照する `fixtures.yaml` の `fixtures[].name` が実在すること（スキーマ・実行規約は `${CLAUDE_PLUGIN_ROOT}/references/playwright-test.md`）

### 7.2 実行（Bash）

- `npx playwright test` を Bash で実行する。対象の絞り込みはプロジェクト単位で `--project`、単一ケースは末尾に `.spec.ts` のパス（必要に応じ `-g <title>`）を指定する

```bash
# SUT の project= ルートで対象 spec を実走する例（認証済みプロジェクト・JUnit + line レポート）
cd "<SUT の project= ルート>" && npx playwright test tests/<対象>.spec.ts --project=authenticated --reporter=line,junit
```

- ヘッドレス・`ignoreHTTPSErrors`・`baseURL`・`storageState` 等は fixtures 基盤側の `playwright.config.ts` で定義済みの前提（playwright-test.md 2 章）。本スキルはこれらを上書きしない
- Bash 実行の書式は本プラグインの既存 Bash 呼び出し規約（4 章の `curl` 補助確認等）に合わせる。Playwright は node/npx 実行であり Python 子プロセスではないため `run_via_job.sh` ラッパーは不要

### 7.3 結果マッピングとエビデンス化

| runner の結果 | ケース status |
|--------------|--------------|
| 対象テストが全 pass | `pass` |
| 対象テストに fail が含まれる | `fail`（defect 3 点セットは 4 章に準じて JUnit / トレースから組み立てる） |
| 設定エラー等でテスト自体が実行されなかった | `blocked` + reason（原因を記録） |

- エビデンス: `npx playwright test` の stdout / stderr ログ・JUnit XML・HTML レポート（`playwright-report/`）・失敗時のトレース / スクリーンショットを `evidence/{run_id}/{case_id}/` へ保存する（テストランナー実行時のエビデンス収集は `${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 7 章に準ずる。命名例: `80_playwright-stdout.txt` / `81_junit.xml`）
- `executed_by` は `playwright-test` を記録する（`playwright-mcp` と混同しない）。`duration_sec` は runner の実行時間を用いる

### 7.4 SKIPPED 規範（実行手段不在時・偽装禁止）

- Playwright 本体・テストランナー（`npx playwright test`）が未導入、または `fixtures.yaml` / SUT テストコードが不在の場合は、実行を偽装せず当該ケースを `skipped` + reason で返す（`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 2 章・`playwright-test.md`）。「未実施」を「問題なし」と書かない

---

## 8. 関連 references

| 参照先 | 内容 |
|-------|------|
| `${CLAUDE_PLUGIN_ROOT}/references/playwright-mcp.md` | 正本ツールリスト・filename 指定・待機規範・raw 出力先・プレフィクス読み替え |
| `${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` | 中間結果返却フォーマット・条件付き動的検証・タイムアウト・テストデータ分離・環境安全 |
| `${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` | raw 出力からの移送規約・エビデンス配置パス・基準ディレクトリ解決 |
| `${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` | fail 時 3 点セット・エビデンス命名・pass ケースの要件・機微情報マスキング |
| `${CLAUDE_PLUGIN_ROOT}/references/severity-policy.md` | severity 判定基準（唯一の SSOT） |
| `${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-results.md` | status enum・defect フィールド定義 |
| `${CLAUDE_PLUGIN_ROOT}/references/test-levels.md` | 単体テストの定義・入口/出口基準・主な確認観点（4.2 節） |
| `${CLAUDE_PLUGIN_ROOT}/references/playwright-test.md` | `npx playwright test` + fixtures.yaml の実行規約・認証/モック/シードのパターン（7 章の playwright-test 実走経路） |
