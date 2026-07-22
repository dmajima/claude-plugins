<!-- MANUAL-EXECUTION-SENTINEL-v1 -->
# 手動実行規範（manual-execution）

`automation: manual-assist` / `exploratory` ケースの処理規範 SSOT。
提示 3 要素・AskUserQuestion 聴取設計・人間提供エビデンスの受領/移送/マスキング適用・中断/resume・探索的セッション規範（SBTM）・非対話の手順書縮退・手順書/チャーターシート様式を一元定義する。

---

## 1. 適用範囲と原則

| 項目 | 内容 |
|------|------|
| 対象ケース | `automation: manual-assist`（人手の確認が不可欠な個別ケース）/ `exploratory`（チャーターベースの人間探索セッション。6 章） |
| 適用主体 | 実行スキル 6 種（`test-run-unit` / `test-run-functional` / `test-run-integration` / `test-run-scenario` / `test-run-performance` / `test-run-security`）のケース処理と、オーケストレータ `test`（人間承認ゲートでの手動件数提示・手順書生成の起動） |
| 構図 | `playwright-test.md` と同型の「共通 references + 各 SKILL.md から参照 1 行」 |

### 1.1 記録は自動実行と完全同一経路（MANDATORY）

- 実行スキルは手動ケースの結果も**中間結果 JSON**（`execution-policy.md` 4 章の既存フォーマットのまま。フィールドの追加・変更なし）でオーケストレータへ返却し、オーケストレータが `results_manager.py`（record）で記録する（執行順も自動実行と同じ）
- `executed_by` は **`human-assisted`**（`manual-assist` / `exploratory` 共通。人の実施・申告に基づく検証のため）
- fail 時は defect 3 点セット必須（`evidence-policy.md`）。`reproduction_steps` は**人間の観察 + AI が把握する環境情報**で構成する

### 1.2 実行を偽装しない（既存規範の手動固有再掲）

- 人間の申告を**脚色・補完しない**。聴取していない実測値・結果・エビデンスをでっち上げない（`execution-policy.md` 2 章の偽装禁止の手動適用）
- 手動・探索的の pass も「人の実施・申告に基づく検証結果」であり、受入判断は人間が行う（UAT 免責は `test-levels.md` 6 章のまま不変）
- AI が補助可能な前段操作（画面遷移・テストデータ投入・スクリーンショット取得）は提示前に実施してよい（AI の補助操作と人間の申告を混同して記録しない）

### 1.3 用語の区別

| 表現 | 意味 | executed_by |
|------|------|-------------|
| `automation: playwright` | AI による Playwright MCP のそのば操作（従来から「探索的」と呼ばれる **AI 探索**。既存経路のまま不変） | `playwright-mcp` |
| `automation: exploratory` | **人間**が主導するチャーターベースの探索セッション（本ファイル 6 章） | `human-assisted` |

## 2. 提示 3 要素

対話時、実行スキルは聴取の**前に**以下 3 要素をユーザーへ提示する。

| # | 要素 | 内容 |
|---|------|------|
| 1 | 確認対象 | ケース ID・タイトル・レベル・`preconditions` の充足状態 |
| 2 | 手順 | `steps` を番号付きで転記し、環境情報・対象 URL を補足する |
| 3 | 判断基準 | `expected` と `data` の期待値 |

## 3. 聴取設計（AskUserQuestion）

1 ケース 1 質問を原則とし、各選択肢に帰結を 1 行で添える（人間承認ゲートの既存文言例と同型。`execution-policy.md` 1.3）。

| 場面 | 質問 / 選択肢 |
|------|--------------|
| 結果聴取（manual-assist 共通） | 質問「TC-XXX-nnn の手動確認結果を選択してください（手順・判断基準は直前提示）」。選択肢: **pass**（期待どおり。actual に確認内容を記録）/ **fail**（期待と不一致。続けて実際の結果・再現状況・エビデンスを伺う）/ **blocked**（前提不成立で確認不能。理由を伺う）/ **後で実施**（手順書を生成し skipped で記録・後日 ng-only 再テスト対象） |
| fail 時の追加聴取 | 自由記述で (1) 実際に観察された結果（`actual` / `reproduction_steps` の材料）(2) 使用した入力値（`test_data` の材料）(3) エビデンスの所在（スクリーンショット等のパス。受領できない場合は 4 章の代替手順） |
| performance の実測値聴取 | 計測方法・閾値を提示のうえ実測値を数値で聴取する。実測値・閾値は status を問わず results[] 直下の `extras`（`measured_value` / `threshold`）に記録する（pass 時も含む。`yaml-schema-results.md` 4 章）。fail（閾値超過）時に `defect.extras.measured_value` / `defect.extras.threshold` へ併記するのは従来互換として任意 |
| security の聴取 | 承認済みケース記載範囲のみ確認を依頼し、聴取内容・エビデンスにマスキング（`evidence-policy.md` 5 章）を適用する |
| exploratory セッション開始 | チャーター（`steps`）・タイムボックス（`timeout_sec`）・記録方法を提示し、開始可否を確認する。選択肢: **開始** / **後で実施**（チャーターシート縮退。7 章）/ **中止** |
| exploratory セッション終了 | (1) セッションノート（何を試したか）(2) 発見事象（バグ・気付き。件数分）(3) PROOF 観点の振り返り（Past / Results / Obstacles / Outlook / Feelings）を聴取してセッションシートへ整理し、総合結果を選択肢で確定する: **pass**（重大発見なし・完遂）/ **fail**（欠陥発見）/ **blocked**（探索不能） |

- exploratory セッション開始の「**中止**」= 当該セッションを実施せず**記録もしない**（result エントリを作らない。当該ケースは scope からは外れず、後続 run で再対象化される）
- 中止時は、ユーザーへ再実行手段（`ids` 指定での再テスト。`retest-policy.md`）を案内する

## 4. 人間提供エビデンスの受領・移送・マスキング

| 項目 | 規範 |
|------|------|
| 受領・移送 | ユーザーが提示したファイルパスは `{target-slug}/evidence/{run_id}/{case_id}/` へ**コピー移送**する（**原本は消さない**。Playwright raw 出力の move とは異なる。配置規約は `data-locations.md`）。実績には移送後パスを記録する |
| pass 時 | エビデンスは**任意**（必須は fail 時のみ）。エビデンスなしで pass を記録する場合は `actual` に「人間の申告に基づく（エビデンスなし）」を明記する。`priority: high` のケースは取得を促す（`evidence-policy.md` 6 章の既存推奨） |
| fail 時 | エビデンスを受領できない場合、AI が**代替取得**を試みる（Playwright MCP 到達可能時の画面再取得等）。それも不可なら聴取した申告内容をテキストファイル `human-report.md` として `evidence/{run_id}/{case_id}/` へ保存し evidence 化する（record の fail 時 evidence 必須制約を満たすため） |
| マスキング | 受領・保存・転載時は `evidence-policy.md` 5 章のマスク形式・対象に従う |

## 5. タイムアウト・中断・resume

| 状況 | 動作 |
|------|------|
| `timeout_sec`（manual-assist） | 既存規約のまま（超過 = `blocked`。`execution-policy.md` 8 章）。`exploratory` のタイムボックス例外は 6 章 |
| 「後で実施」を選択 | その場で手順書生成へ縮退し（7 章と同型のオンデマンド生成）、`skipped` + reason（手順書パス）で記録する |
| 応答が得られず続行不能 | 残りの手動ケースの扱い（手順書縮退で続行 / 中断）をユーザーに確認する。確認も不能な場合は手順書縮退で続行する（`skipped` + reason） |
| 記録後の再挑戦 | `skipped` は人員・環境の整備後に ng-only 再テストの対象となり（`retest-policy.md`）、resume の残ケースにも自然に含まれる |

- 手動ケースの `skipped` は「実行手段不在 = 人間の応答可能性の不在」として扱う（`blocked` はテスト論理起因に限る既存意味論を維持。`yaml-schema-results.md` 6 章）
- run 中に Playwright MCP を喪失しても、手動ケースは MCP 不要のため**実施可能なら続行**する（自動ケースのみ skipped になる既存規約と併存）

## 6. exploratory セッション規範（SBTM）

チャーターベースの人間探索セッション。**1 チャーター = 1 ケース**として `test-cases.yaml` に表現する（フィールド意味論の注記は `yaml-schema-cases.md` 2 章）。

### 6.1 チャーター表現

| フィールド | exploratory での意味 |
|-----------|---------------------|
| `title` | チャーター名 |
| `steps` | 探索指針（対象領域・試すこと・使うデータ。チャーター文の番号付き展開。手順書式ではない） |
| `expected` | 発見目標・完了条件 |
| `data` | 探索に使う検証データ |
| `requirement` | 対応する要件・リスク領域 |
| `timeout_sec` | セッションのタイムボックス（計画時間） |

- レベルは 8 レベルのどこにも置ける（`level` 必須・ケース ID プレフィクスも既存レベル準拠。**新プレフィクスは作らない**）。推奨配置（functional / system / uat）と担当実行スキルの対応は `test-levels.md` の運用注記に従う

### 6.2 タイムボックス

- `timeout_sec` はタイムボックス（計画時間）であり、**超過 = blocked の既存規約（`execution-policy.md` 8 章）を適用しない**
- タイムボックス満了 = セッションの正常終了として結果判定へ進む
- セッション開始不能（対象未起動等の前提不成立）はテスト論理上のブロックとして `blocked` + reason で記録する

### 6.3 セッションの進め方

1. チャーター提示（3 章「セッション開始」の聴取で開始可否を確認する）
2. 人間が探索する（AI は**書記 + 操作補助**: セッションノートの記録・画面遷移・データ投入・スクリーンショット取得を補助してよい）
3. セッションノート・発見事象を聴取する（3 章「セッション終了」）
4. PROOF 観点（Past / Results / Obstacles / Outlook / Feelings）の振り返りを聴取する
5. セッションシートを作成・保存し（6.4）、総合結果を確定する

### 6.4 セッションシート（evidence）

- AI が聴取内容を Markdown へ整形し、`evidence/{run_id}/{case_id}/session-sheet.md` として保存して結果の `evidence` に含める
- 見出し構成は 8.3 に固定する（対話文脈の要約整形のためスクリプト化はしない。整形ブレは見出し固定で抑える）

### 6.5 発見事象の記録

| 記録先 | 内容 |
|-------|------|
| `defect`（総合結果 fail 時） | 最重要の発見 **1 件**を 3 点セット（`evidence-policy.md`。severity は `severity-policy.md`）で記録する |
| `defect.extras.session_findings`（list） | セッション中の**全発見事象**（事象・再現性・defect 化有無）を記録する（`yaml-schema-results.md` 4 章） |
| `extras.session_findings`（results[] 直下・list） | defect 化する発見がないセッション（fail に至らない場合）の全発見事象を記録する（記録構造は `defect.extras.session_findings` と同一。`yaml-schema-results.md` 4 章） |
| セッションシート | 発見事象一覧（再現手順メモ付き）を残す |
| 再現ケースの起票（推奨規範） | 発見事象ごとに再現用の通常ケース（`review_status: draft`）の起票を**推奨**する（起票は test-design の責務・revision 規則の既存経路） |

## 7. 非対話縮退（手順書生成）

- 非対話時、`manual-assist` / `exploratory` ケースは**実行せず**、オーケストレータが `generate_manual_sheet.py` で scope 内の手動系ケースの手順書（`exploratory` はチャーターシート様式）を一括生成し、実行スキルは `skipped` + reason に**手順書パス**を含めて記録する（`execution-policy.md` 9 章の非対話既定値表）
- reason の形式: 「非対話のため未実施。手順書: manual/manual-sheet_{yyyyMMdd-HHmmss}.md」
- **フェイルオープン**: 手順書生成に失敗した場合（venv 不備・test-cases.yaml 不整合等）は生成を諦め、従来どおり理由のみの `skipped` で続行する（フローを止めない。失敗理由はオーケストレータが annotate で所見化してよい）
- スクリプトの起動主体は**オーケストレータのみ**。実行スキルはスクリプトを起動せず、オーケストレータから Skill args `manual-sheet={path}` で受領したパスを reason に転記するだけとする
- 対話時の「後で実施」選択も同型のオンデマンド生成で縮退する（5 章）
- 手順書・チャーターシートは record による実績記録の代替ではない（手順書への記入 = 実績記録ではない。8 章参照）

## 8. 手順書・チャーターシートの様式

### 8.1 生成・配置

| 項目 | 規範 |
|------|------|
| 生成主体 | `generate_manual_sheet.py`（オーケストレータ `test` が起動する決定論生成。LLM の手動転記では作らない） |
| 出力先 | `{base}/{target-slug}/manual/manual-sheet_{yyyyMMdd-HHmmss}.md`（タイムスタンプ命名で上書きしない。配置は `data-locations.md` 2 章） |
| ヘッダ | 対象・生成日時・絞込条件・ケース revision 一覧・注意書き「記入結果は deep-test へ回付し record 経由で実績記録する。本書への記入は実績記録ではない」 |
| マスキング | 転載する `data` / `preconditions` 等に `evidence-policy.md` 5 章の既知パターン決定論マスキングを適用する |

### 8.2 manual-assist ケース節の様式（規範例）

```markdown
## TC-FUNC-010: 一覧画面の表示品質（目視確認）

| ケース ID | revision | レベル | 優先度 | automation | タイムアウト |
|---|---|---|---|---|---|
| TC-FUNC-010 | 2 | 単体（functional） | high | manual-assist | 120 秒 |

- 前提条件: （preconditions を番号なしリストで転記）
- 手順: （steps を番号付きで転記）
- 期待結果: （expected を転記）
- 検証データ: （data を転記。マスキング適用済み）
- 事後処理: （postconditions を転記）

### 記入欄（実施後に deep-test へ回付してください。本書への記入は実績記録ではありません）

| 項目 | 記入 |
|---|---|
| 結果（いずれかに丸） | pass / fail / blocked |
| 実施者 / 実施日時 | ____________ / ____________ |
| 実測値（性能ケースのみ） | ____________ |
| 実際の結果（fail 時は必須） | ____________ |
| エビデンスの所在（ファイル名・保存先） | ____________ |
```

### 8.3 exploratory チャーターシート様式・セッションシート見出し構成

- チャーターシート（非対話縮退の生成物）: 8.2 の様式に代えて、チャーター（`steps`）・発見目標（`expected`）・タイムボックス・記入欄（セッションノート / 発見事象一覧〔再現手順メモ付き〕/ PROOF 振り返り / 総合結果）で構成する
- セッションシート（対話実施時に AI が作成する evidence。6.4）: 見出し構成を「チャーター / タイムボックス実績 / セッションノート / 発見事象一覧 / PROOF 振り返り / 総合結果」に固定する

## 9. 関連 references

| 参照先 | 内容 |
|-------|------|
| `execution-policy.md` | 中間結果返却フォーマット・人間承認ゲートの手動件数提示・タイムアウト（exploratory 適用除外）・非対話既定値表 |
| `yaml-schema-cases.md` | `automation` enum（`manual-assist` / `exploratory`）・exploratory の意味論注記・記入例 |
| `yaml-schema-results.md` | status / executed_by / defect / `extras.session_findings` のフィールド定義・status の使い分け |
| `evidence-policy.md` | fail 時 3 点セット・pass エビデンス要件・機微情報マスキング（受領・転載時） |
| `data-locations.md` | `manual/` 配置・エビデンス移送・target-slug 解決 |
| `report-format.md` | 未確認事項（skipped 一覧）・報告書への転載定義 |
