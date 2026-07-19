# フェーズ遷移詳細（test オーケストレータ）

オーケストレータ `test` のフェーズ遷移・各フェーズの入出力・ゲート判定手順・NEEDS REVISION 時の遡行ループ・resume の途中復帰位置判定を定義する。
ゲートそのものの定義（4 種）と非対話既定値は `${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` が SSOT であり、本書は**オーケストレータ側の運用手順**（判定の実施方法・遷移制御）のみを定義する。

---

## 1. フェーズ状態遷移図

```mermaid
stateDiagram-v2
    [*] --> Phase0: 起動（モード判定済み）
    Phase0 --> Phase1: フル / 再テスト / run-only（環境未検証時）
    Phase0 --> Phase1_5: フル（環境検証済み）
    Phase0 --> Phase2: design-only（環境検証済み・解析スキップ）
    Phase0 --> Phase4: 再テスト / run-only（環境検証済み）
    Phase0 --> Phase7: report-only
    Phase0 --> Resume判定: resume
    Phase1 --> 停止_ハンドオフ: 新規 MCP 登録あり
    Phase1 --> Phase1_5: フル
    Phase1 --> Phase4: 再テスト / run-only
    Phase1_5 --> Phase1_6: fixture 有効（web-app・認証EP / 外部依存あり）
    Phase1_5 --> Phase2: fixture 不要（unit のみ・非 web・材料なし）でスキップ
    Phase1_6 --> Phase2: fixtures.yaml 生成完了
    Phase2 --> Phase3
    Phase3 --> Phase2: NEEDS REVISION（ループ 3 回まで）
    Phase3 --> Phase4: PASS（design-only はここで完了）
    Phase3 --> 中断: ループ超過（非対話）/ ユーザー中断選択
    Phase4 --> Phase3: 承認済みケースゲート（draft 混入）
    Phase4 --> 中断: 人間承認ゲート否認
    Phase4 --> 停止_ハンドオフ: MCP ゲート未ロード
    Phase4 --> Phase5: 全ゲート通過
    Phase5 --> Phase6: finish-run 完了（run-only はここで完了）
    Phase6 --> Phase5: NEEDS REVISION（ids 再実行。ループ 3 回まで）
    Phase6 --> Phase7: PASS
    Phase7 --> Phase5: validate 違反（欠落補完の再実行）
    Phase7 --> [*]: 報告書生成・引き渡し
    Resume判定 --> Phase5: 中断 run の残ケースから継続
    Resume判定 --> Phase4: 中断 run なし・approved ケースあり（run-only 相当を提案）
    Resume判定 --> Phase2: test-cases.yaml なし（フルフローを案内）
    停止_ハンドオフ --> [*]: 再起動後 resume で復帰
```

## 2. フェーズ入出力一覧

各フェーズの受け渡しデータの詳細構造は `state-handoff.md` を参照。

| フェーズ | 入力 | 処理（委譲先） | 出力 |
|---------|------|--------------|------|
| Phase 0: target 解決 | 起動引数・依頼内容 | 基準ディレクトリ解決 → slug 選択（AskUserQuestion）→ venv 準備 → `init` | `{base}` / `{target-slug}` / 解決済みパス集合 |
| Phase 1: setup 確認 | target-slug・必要レベルの見込み | `Skill: test-setup` | 環境検出結果（MCP / ランナー / venv） |
| Phase 1.5: 解析 | target-slug・（`spec=` / `diff=` があれば）仕様 / 差分 | `Skill: test-analyze` | `analysis.yaml` / `target-analysis.md`（read-only の対象理解材料） |
| Phase 1.6: フィクスチャ基盤（条件付き） | target-slug・`analysis.yaml`（材料）・SUT `project` ルート | `Skill: test-fixture` | `fixtures.yaml`（マニフェスト）+ SUT テストコード（フィクスチャ / config）。fixture 不要時は空マニフェストで no-op |
| Phase 2: 設計 | 対象説明・要件情報・（差し戻し時）レビュー指摘 | `Skill: test-design` | `test-plan.md` / `test-cases.yaml`（draft） |
| Phase 3: 設計レビュー | test-cases.yaml のパス・対象説明 | `Skill: test-review`（設計文脈） | PASS / NEEDS REVISION + 指摘リスト |
| Phase 4: 対象確定 + ゲート | モード・（ids 時）ケース ID | `select` → 3 ゲート判定 | 確定 scope（approved のみ）・ゲート通過記録 |
| Phase 5: 実行 | scope・run_id・環境情報 | `start-run` → `Skill: test-run-*`（逐次）→ `record` → `finish-run` | 確定 run（test-results.yaml 反映済み） |
| Phase 6: 結果レビュー | run_id・fail 概要・集計 | `Skill: test-review`（結果文脈） | PASS / NEEDS REVISION + 指摘リスト |
| Phase 7: 報告 | target-slug・（形式指定があれば）形式 | `validate` → `Skill: test-report` | 報告書パス（セッション作業領域直下） |

## 3. ゲート判定手順（オーケストレータ側の運用）

ゲートの定義・配置・非対話時挙動は `${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 1 章が SSOT。本節は判定の実施方法のみを定める。

| ゲート | 判定材料 | 判定手順 | 不通過時の遷移 |
|-------|---------|---------|---------------|
| 設計レビューゲート | test-review（設計文脈）の返却（PASS / NEEDS REVISION） | 返却 JSON の `verdict` を読む。判定があいまいな返却（verdict 欠落）は NEEDS REVISION として扱う | 4 章の修正ループへ |
| 承認済みケースゲート | `select` 出力の `draft_cases` | `draft_cases` が空 → 通過。非空 → test-review（設計文脈）を draft ケースに対して実施（PASS 時の approved 化は test-review が実施）→ `select` を再実行して確認 | Phase 3（対象は draft ケースのみ） |
| 人間承認ゲート | `select` 出力の `cases` / `details` | AskUserQuestion で提示（ケース数・レベル別内訳・想定所要時間 = details の timeout_sec 合計を上限とする概算・破壊的操作ケース数 = select 出力の `destructive` 集計）。非対話時はスキップ | 中断（scope・実績は未変更のまま） |
| MCP ゲート | scope のレベル構成 + ToolSearch 結果 | scope が unit のみ → 判定不要で通過。それ以外 → ToolSearch で `mcp__playwright__` 系を検索（手順・判定基準は `${CLAUDE_PLUGIN_ROOT}/references/playwright-mcp.md` 4 章） | 再起動ハンドオフを出力して停止（run 開始前なら start-run しない。run 中の喪失は skipped 記録で継続） |

ゲート判定の順序は固定: `select` → 承認済みケースゲート → 人間承認ゲート → MCP ゲート → `start-run`。
`start-run` は**全ゲート通過後**にのみ実行する（未実行の run レコードを残さないため）。

## 4. NEEDS REVISION 時の遡行ループ

### 4.1 設計文脈（Phase 3 → Phase 2）

```mermaid
flowchart TD
    R["test-review（設計文脈）"] -->|PASS| OK["approved 化 → Phase 4"]
    R -->|"NEEDS REVISION"| C{"ループ回数 < 3 ?"}
    C -->|Yes| D["test-design へ差し戻し\n（指摘リスト + 対象ケース ID を引き渡す）"]
    D --> R
    C -->|No 対話| Q["AskUserQuestion:\n続行（追加ループ）/ 中断 / 指摘を許容して進行"]
    C -->|No 非対話| E["エラー中断"]
```

- **ループ回数の数え方**: 「test-design への差し戻し」を 1 回と数える（初回設計は 0 回目。test-review の実行回数 − 1 に一致する）
- 差し戻し時は test-review の指摘リスト（指摘内容・根拠・対象ケース ID・信頼度）をそのまま test-design に引き渡す（要約で情報を落とさない）
- test-design は指摘対象ケースのみ更新する（revision +1 → draft 戻り。規則は `${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-cases.md` 3 章）
- 差し戻し後の再レビューの構成（指摘元エージェントのみ / フル並列 / 本体差分チェック）は `${CLAUDE_PLUGIN_ROOT}/skills/test-review/references/review-procedures.md` の差し戻し再レビュー規定に従う
- ユーザーが「指摘を許容して進行」を選んだ場合、未解消の指摘を results_manager.py の `annotate` サブコマンドで**必ず注釈として登録**する（例: `annotate --source test-review/design --text "..."`）。登録した注釈は報告書の「所見・注記」に機械出力される（手動転記はしない）
- ループ超過時の AskUserQuestion 選択肢の文言例（各選択肢に帰結を 1 行で添える）:
  - 「続行（追加ループ）: 指摘の修正と再レビューをもう 1 回実施します」
  - 「中断: ここで処理を終了します（test-cases.yaml は draft のまま保存済み。resume 対象ではなく design-only 等での再開になります）」
  - 「指摘を許容して進行: 未解消の指摘は annotate で注釈登録され、報告書の所見・注記に出力されます」

### 4.2 結果文脈（Phase 6 → Phase 5）

結果は append-only（上書き不可）のため、遡行は「再実行による上書きではなく追加 run」で行う。

| 指摘の種類 | 遡行方法 |
|-----------|---------|
| 再現手順・検証データ・エビデンスの不備（fail の 3 点セット品質） | 該当ケースを `ids` モードで再実行（新規 run）し、充足した defect で再記録する |
| severity の妥当性への疑義 | defect-analyst の指摘（`${CLAUDE_PLUGIN_ROOT}/references/severity-policy.md` 基準）を採用する場合も、実績の書き換えはせず該当ケースを `ids` 再実行で再記録する |
| 分析・所見レベルの指摘（実績の変更不要） | オーケストレータが results_manager.py の `annotate` サブコマンドで注釈として登録する（例: `annotate --source test-review/results --text "..."`）。報告書の所見・注記に機械出力される（遡行しない） |

- ループ上限は設計文脈と同じ **3 回**。超過時の挙動も 4.1 と同一（対話 = ユーザー判断 / 非対話 = エラー中断）

## 5. resume の途中復帰位置判定

resume 対象・run_id 引き継ぎ・複数中断時の整理の規約は `${CLAUDE_PLUGIN_ROOT}/references/retest-policy.md` 6 章が SSOT。オーケストレータは以下の手順で復帰位置を決める。

### 5.1 判定手順

1. Phase 0 を実施する（target-slug 解決。resume でも省略しない）
2. `summary` を実行し、`runs[]` から `status` が `in_progress` または `interrupted` の run を抽出する
3. 復帰位置を判定する:

| 状態 | 復帰位置 |
|------|---------|
| 中断 run が 1 件以上ある | 最新の 1 件（run_id 降順の先頭）を対象に **Phase 5** から再開。それより古い中断 run は AskUserQuestion で確認のうえ `finish-run --status aborted` で整理する |
| 中断 run がなく、approved ケースがある | 実行可能な状態のため、run-only 相当（Phase 4 から）を提案する |
| 中断 run がなく、test-cases.yaml が存在しない | resume 対象なし。フルフロー（Phase 2 から）を案内する |

4. 中断 run から再開する場合、残ケースを機械的に確定する: `validate` の `resumable_runs` フィールド（`{run_id, status, missing}` の構造化リスト）から当該 run の `missing` を resume scope として採用する（副作用なしで取得できる。`finish-run` の仮実行や件数のみでの推定は行わない）
5. resume scope に Playwright 必要レベルが含まれる場合は **MCP ゲートを再判定**する（resume の主用途が MCP 未ロード停止からの復帰であるため必須）
6. **run_id は新規採番しない**。中断 run の run_id をそのまま実行スキルへ引き渡し、残ケースの record を追記する
7. 全ケース記録後に `finish-run` で `completed` に確定し、Phase 6 → Phase 7 へ進む

### 5.2 注意事項

- resume では `start-run` を実行しない（新規 run を作らない）
- 中断時点までの record 済み結果は永続化済みであり、再実行・再記録しない（重複 record は exit 2 で拒否される）
- 中断 run が MCP ゲート停止由来か（scope に Playwright 必要レベルが残っているか）を確認してから実行スキルを起動する

## 6. 実行コマンド集（Phase 別）

SKILL.md の実行フロー表に対応する具体的な実行コマンド・Skill args。`<venv>` はセッション作業領域の venv、`{base}` は data-locations.md の基準ディレクトリを指す。

### Phase 0: target-slug 解決 + init

1. 基準ディレクトリ `{base}` を解決する（`${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` 1 章・4 章）
2. 既存 `{target-slug}/` があれば AskUserQuestion で既存一覧 +「新規作成」を提示して選択させる。非対話時は唯一の既存 slug を採用（複数存在はエラー中断）
3. venv を準備し、初期化する:

   ```bash
   "<venv>/Scripts/python.exe" "${CLAUDE_SKILL_DIR}/references/scripts/results/results_manager.py" init      --base "{base}" --target "{target-slug}"
   ```

### Phase 1: setup 確認（必要時）

run を含むモードで実行環境が未検証の場合に起動する（`levels=` には依頼内容・既存ケースから見込んだテストレベルの CSV を渡す）:

```text
Skill(skill: "deep-test:test-setup", args: "target={target-slug} base={base} levels={見込みレベルCSV}")
```

- レベル見込みが unit のみの場合、playwright チェックは not-checked となり MCP 登録に進まない（levels 未指定は全チェックになるため、見込みがあれば必ず渡す）

検出結果（MCP ロード状況・テストランナー・venv）を受領する。対象アプリへの到達可否は実行フェーズで判定する（execution-policy.md の条件付き動的検証）。新規に MCP 登録を行った場合は再起動ハンドオフ（`${CLAUDE_PLUGIN_ROOT}/references/playwright-mcp.md` 3 章）を出力して停止する。

### Phase 1.5: 解析（test-analyze）

フルフローで `test-setup`（Phase 1）の後・`test-design`（Phase 2）の前に起動する。テスト対象ソースを read-only で静的に理解し、下流が消費する解析材料（`analysis.yaml` / `target-analysis.md`）を生成する:

```text
Skill(skill: "deep-test:test-analyze", args: "target={target-slug} base={base} 対象説明={...} spec={仕様パス} diff={差分ref} --non-interactive")
```

- `spec=` / `diff=` は指定がある場合のみ付与する（未指定時は仕様乖離検出 / 変更影響分析をスキップ）。`--non-interactive`（モード指定）は非対話時のみ付与する
- 出力の `analysis.yaml`（機械可読・`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-analysis.md` 準拠）を Phase 2 の `test-design` が消費し、レベル / 技法 / 優先度 / ケースを決定する（材料の単方向消費）
- test-analyze は決定を行わず read-only の材料生成に徹する（逆呼び出し禁止・2 段委譲を厳守）。将来の `test-fixture`（Phase 1.6）/ `test-environment` も本材料を消費するが、本フェーズでは新設しない

### Phase 1.6: フィクスチャ基盤（test-fixture・条件付き）

フルフローで `test-analyze`（Phase 1.5）の後・`test-design`（Phase 2）の前に、**fixture が有効な場合のみ**起動する（見込みレベルが unit のみ、または design-only / run-only / retest / report-only ではスキップ）。`analysis.yaml` を単方向消費し、再現可能な Playwright Test 基盤（`fixtures.yaml` + SUT テストコード）を生成 / 拡充する:

```text
Skill(skill: "deep-test:test-fixture", args: "target={target-slug} base={base} project={SUT プロジェクトルート} 対象説明={...} --non-interactive")
```

- 材料 `analysis.yaml`（`{base}/{target-slug}/analysis.yaml`）は引数で渡さず、test-fixture が Read で解決する（非存在時は test-fixture 側で軽量補完する）
- 出力の `fixtures.yaml`（機械可読・`${CLAUDE_PLUGIN_ROOT}/references/playwright-test.md` 1 章準拠）を Phase 2 の `test-design` が消費し、各ケースの `fixtures:` と `automation: playwright-test` を決定する（材料の単方向消費）
- 起動されても fixture 対象なし（非 web・認証も外部依存もなし）と判断した場合は、SUT に何も書かず空の `fixtures.yaml`（`fixtures: []`）+ 理由を返して正常終了する（no-op。既存の探索的 MCP フローは Phase 1.5 → Phase 2 に直行する）
- test-fixture は SUT のテストディレクトリにのみ書き込む（プロダクションコード不変・逆呼び出し禁止・2 段委譲を厳守）

### Phase 2: 設計

```text
Skill(skill: "deep-test:test-design", args: "target={target-slug} base={base} 対象説明={...}")
```

出力: `{base}/{target-slug}/test-plan.md` と `test-cases.yaml`（全ケース `review_status: draft`）。

### Phase 3: 設計レビュー + 設計レビューゲート

```text
Skill(skill: "deep-test:test-review", args: "context=design target={target-slug} base={base}")
```

- PASS → test-review が承認反映（`review_status: approved` 化）まで実施して返却する。承認確定時に、test-plan.md のスコープ外宣言（未検証領域・対象外レベルと理由）を `annotate --source test-plan` で**必ず登録**する（未登録時のみ。報告書の「所見・注記」へ機械出力され、Phase 7 での再登録は不要）。その後 Phase 4 へ進む:

  ```bash
  "<venv>/Scripts/python.exe" "${CLAUDE_SKILL_DIR}/references/scripts/results/results_manager.py" annotate      --base "{base}" --target "{target-slug}" --source test-plan --text "スコープ外: {宣言内容}"
  ```

- NEEDS REVISION → 指摘リストを添えて test-design へ差し戻す修正ループ（上限 3 回）。超過時: 対話 = AskUserQuestion でユーザー判断（続行 / 中断 / 指摘許容）、非対話 = エラー中断（execution-policy.md 1.1）

### Phase 4: run 対象確定とゲート

1. select で scope を機械的に確定する（LLM の判断で対象を確定しない）:

   ```bash
   "<venv>/Scripts/python.exe" "${CLAUDE_SKILL_DIR}/references/scripts/results/results_manager.py" select      --base "{base}" --target "{target-slug}" --mode ng-only
   # フル/再テスト full → --mode full / 再テスト ids → --mode ids --ids "TC-FUNC-002,TC-SYS-001"
   ```

2. 承認済みケースゲート: 出力の `draft_cases` が空でなければ、先に test-review（設計文脈）を実施して approved 化してから進む（approved 化は test-review が実施）
3. 人間承認ゲート: AskUserQuestion で「実行に進むか」を確認する。提示必須項目（ケース数 / 対象レベル / 想定所要時間 / 破壊的操作ケース数 = select の `destructive` 集計）は execution-policy.md 1.3。非対話時はスキップ
4. MCP ゲート: scope に Playwright 必要レベルが含まれる場合のみ、ToolSearch で `mcp__playwright__*` の実利用可否を判定する（playwright-mcp.md 4 章）。未ロード → 再起動ハンドオフを出力して停止（利用可を装った続行は禁止）。unit のみの scope は判定不要で通過

### Phase 5: 実行（レベル順逐次 → record → finish-run）

1. run を開始し run_id を取得する:

   ```bash
   run_id=$("<venv>/Scripts/python.exe" "${CLAUDE_SKILL_DIR}/references/scripts/results/results_manager.py" start-run      --base "{base}" --target "{target-slug}" --mode full      --scope "TC-UNIT-001,TC-FUNC-001,TC-FUNC-002"      --environment "Windows 11 / Chromium headless / https://localhost:5001（build 1.4.2）" | python -c "import sys,json; print(json.load(sys.stdin)['run_id'])")
   ```

   `start-run` は `{run_id, mode, scope_size, active_runs_warning}` の JSON を stdout に出力する。上記のように `run_id` を取り出して以降で使う。`active_runs_warning` が空でなければ未完了の run が残っているため、resume 要否を確認する。

2. scope をレベル別にグループ化し、レベル→実行スキル対応（test-levels.md）に従ってレベル順に逐次 Skill 起動する（並列起動禁止）:

   ```text
   Skill(skill: "deep-test:test-run-unit",       args: "target={target-slug} base={base} run-id={run_id} cases=TC-UNIT-001")
   # 完了後に次レベル:
   Skill(skill: "deep-test:test-run-functional", args: "target={target-slug} base={base} run-id={run_id} cases=TC-FUNC-001,TC-FUNC-002")
   ```

   各レベルの実行完了時（当該レベル全ケースの record 完了後）、簡潔な進捗サマリ（レベル名・実行件数・pass / fail 内訳）を出力してから次レベルの実行スキルを起動する

3. 実行スキルの中間結果 JSON（execution-policy.md 4 章）を受領し、results[] の要素を 1 件ずつ `--result-json -`（標準入力）で record する。中間結果 JSON の完全な構造は execution-policy.md 4 章・yaml-schema-results.md 参照:

   ```bash
   echo '{"case_id":"TC-FUNC-001","case_revision":1,"status":"pass","executed_by":"playwright-mcp","duration_sec":12.4,"actual":"ダッシュボードへ遷移した","evidence":["evidence/{run_id}/TC-FUNC-001/03_dashboard.png"],"defect":null}' \
     | "<venv>/Scripts/python.exe" "${CLAUDE_SKILL_DIR}/references/scripts/results/results_manager.py" record      --base "{base}" --target "{target-slug}" --run-id "$run_id" --result-json -
   ```

   record が exit 2（fail の defect 3 点セット欠落等）を返した場合は、stderr の欠落フィールドを添えて当該実行スキルへ追加取得を指示し、充足後に再 record する（一次バリデーション。evidence-policy.md 2 章）
4. 全レベル完了後に run を確定する:

   ```bash
   "<venv>/Scripts/python.exe" "${CLAUDE_SKILL_DIR}/references/scripts/results/results_manager.py" finish-run      --base "{base}" --target "{target-slug}" --run-id "$run_id"
   ```

   欠落ケースが stdout に出力された場合（status=interrupted）は原因を確認し、続行可能なら該当ケースを実行・record して再度 finish-run する

### Phase 6: 結果レビュー

```text
Skill(skill: "deep-test:test-review", args: "context=results target={target-slug} base={base} run-id={run_id}")
```

- PASS → 結果レビューの報告書注記事項（fail の原因分類・ユーザー影響所見など、実績の変更を伴わない総括的な所見）を `annotate --source test-review/results` で**必ず登録**する（Phase 3 のスコープ外宣言 annotate と対称。未登録時のみ）。登録した注記は報告書の「所見・注記」へ機械出力され、Phase 7 での再登録は不要。その後 Phase 7 へ進む:

  ```bash
  "<venv>/Scripts/python.exe" "${CLAUDE_SKILL_DIR}/references/scripts/results/results_manager.py" annotate      --base "{base}" --target "{target-slug}" --source test-review/results --text "原因分類・ユーザー影響所見: {総括内容}"
  ```

- NEEDS REVISION（再現手順不備・severity 不当等）の場合の遡行は 4 章に従う（上限 3 回。分析・所見レベルの指摘も annotate --source test-review/results で登録する）。

### Phase 7: 報告

スコープ外宣言の annotate は Phase 3 PASS（承認確定）時に登録済みのため、本フェーズでは繰り返さない。report-only 起動でスコープ外宣言が未登録の場合のみ、Phase 3 と同じ `annotate --source test-plan` を最終バリデーション前に実行する。

1. 最終バリデーション（違反があれば報告書生成へ進まず差し戻す）:

   ```bash
   "<venv>/Scripts/python.exe" "${CLAUDE_SKILL_DIR}/references/scripts/results/results_manager.py" validate      --base "{base}" --target "{target-slug}"
   ```

2. `Skill(skill: "deep-test:test-report", args: "target={target-slug} base={base}")` を起動する。報告形式（Excel / Markdown）の選択は test-report が AskUserQuestion で行う（非対話時の既定は Markdown）。報告書はセッション作業領域直下に出力される

## 7. 関連 references

| 参照先 | 内容 |
|-------|------|
| `${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` | ゲート 4 種の定義・修正ループ上限・非対話既定値表（SSOT） |
| `${CLAUDE_PLUGIN_ROOT}/references/retest-policy.md` | resume 規約・対象判定マトリクス・承認済みケースゲートの規約（SSOT） |
| `${CLAUDE_PLUGIN_ROOT}/references/playwright-mcp.md` | MCP 実利用可否判定手順・再起動ハンドオフの文面 |
| `state-handoff.md` | フェーズ間の受け渡しデータ構造 |
