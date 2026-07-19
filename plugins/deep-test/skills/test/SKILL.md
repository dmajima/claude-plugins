---
name: test
description: テストライフサイクル全体（設計→レビュー→実行→結果レビュー→報告→再テスト）を制御するオーケストレータスキル。「テストして」「テスト設計して」「再テストして」「テスト報告して」等の依頼や /deep-test:test 系コマンドで起動する。モード判定・target-slug 解決・フェーズ委譲・ゲート判定・実績記録（results_manager.py 経由）のみを担い、設計・レビュー・実行・報告書生成の実務は test-design / test-review / test-run-* / test-report へ Skill 委譲する。
allowed-tools:
  - Read
  - Grep
  - Glob
  - AskUserQuestion
  - Skill
  - ToolSearch
  - Bash
---

> **権限ポリシー**
> - 実務（設計・レビュー・実行・報告書生成）は worker スキルへ **Skill ツール経由で委譲** する。エージェントの直接起動は行わない（worker スキルの責務。`${CLAUDE_PLUGIN_ROOT}/references/agents.md`）
> - `Bash` は **results_manager.py の実行と venv 構築（setup_venv.sh）** に使用する。`test-results.yaml` / `test-cases.yaml` を Edit / Write で直接編集することは禁止
> - MCP ゲートの実利用可否判定に `ToolSearch` を使用する（`${CLAUDE_PLUGIN_ROOT}/references/playwright-mcp.md` 4 章）

# test スキル（オーケストレータ）

テストライフサイクル全体を制御し、フェーズスキル・実行スキルへの委譲とゲート判定・実績記録を一元管理する。
テストに関する知識・実務は持たず、**制御（いつ・何を・どの順で・進めてよいか）** に徹する。

## 責務

制御のみを担う（すべて本スキルの単独責務）。

| 責務 | 内容 |
|------|------|
| モード判定 | 起動引数・依頼内容から実行モード（フル / 再テスト / 部分 / resume / 非対話）を確定する |
| target-slug 解決 | 基準ディレクトリと `{target-slug}/` の解決・初期化（`${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` 4 章のフロー） |
| フェーズ委譲 | 各フェーズの worker スキルを Skill ツールで起動し、引き継ぎデータを受け渡す |
| ゲート判定 | 4 ゲート（設計レビュー / 承認済みケース / 人間承認 / MCP）の判定と遡行・停止の制御（定義は `${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 1 章） |
| 結果統合 | 各フェーズの返却データの受領・要約・次フェーズへの引き渡し |
| 実績記録 | 実行スキルの中間結果を `results_manager.py` 経由で `test-results.yaml` へ一元記録（一次バリデーション含む） |
| 再テスト対象選択 | `results_manager.py select` による機械的抽出（手動抽出禁止） |

## 責務外（他スキルが担当）

| 責務外 | 委譲先・扱い |
|--------|-------------|
| テストレベルの知識・判定基準 | `${CLAUDE_PLUGIN_ROOT}/references/test-levels.md`（参照のみ） |
| テスト計画・ケース設計・test-cases.yaml の生成/更新 | `test-design` スキル |
| 成果物レビュー（設計文脈・結果文脈） | `test-review` スキル |
| テスト実行 | `test-run-unit` / `test-run-functional` / `test-run-integration` / `test-run-scenario` / `test-run-performance` / `test-run-security` |
| 実行環境の構築・検証（Playwright MCP 登録等） | `test-setup` スキル |
| 報告書生成（Excel / Markdown） | `test-report` スキル |
| test-results.yaml の直接編集 | **禁止**。`${CLAUDE_SKILL_DIR}/references/scripts/results/results_manager.py` 経由のみ（`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema.md` 3 章） |

## トリガー条件

- 「テストして」「テストを実施して」「テスト設計して」と言われた場合
- 「再テストして」「NG だけ再テストして」「テスト報告書を作って」と言われた場合
- `/deep-test:test` / `/deep-test:test-retest` / `/deep-test:test-report` コマンドで起動された場合
- Claude Code 再起動後に「resume」「続きから再開して」と言われた場合（中断 run の継続）

テストレベル単体の実行依頼（例:「ユニットテストだけ実行して」）も本スキルが受け、`run-only` モードで該当実行スキルへ委譲する（実行スキルの直接起動は行わない）。

このスキルを起動しないケース:

- コードレビュー中の差分限定ユニットテスト実行（コードレビュー系プラグインの責務）。本スキルはプロジェクト全体のテストライフサイクル管理を担う

## 前提

- **venv**: `results_manager.py` の実行前に、セッション作業領域 `.claude/.local/work/{yyyyMMdd_nn_summary}/workspace/` に venv を構築する。

  ```bash
  bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/setup_venv.sh" ".claude/.local/work/{yyyyMMdd_nn_summary}/workspace"
  ```

  以降の `<venv>` は `.claude/.local/work/{yyyyMMdd_nn_summary}/workspace/.venv` を指す（Windows は `<venv>/Scripts/python.exe`、Unix 系は `<venv>/bin/python`）。既存 venv があれば再利用する
- **データ配置**: 実績・エビデンスは `.claude/.local/plugins/deep-test/{target-slug}/` 配下（基準ディレクトリの解決は `${CLAUDE_PLUGIN_ROOT}/references/data-locations.md`）。以降の `{base}` はこの基準ディレクトリを指す
- **run を含むモード**: Playwright 必要レベルの実行には Playwright MCP のロードが必要（レベル別の要否は `${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 1.4）

## results_manager.py（実績 YAML 操作の唯一の入口）

`test-results.yaml` の追記・集計・抽出・検証はすべて `${CLAUDE_SKILL_DIR}/references/scripts/results/results_manager.py` を Bash + venv で実行して行う（サブコマンド仕様は `${CLAUDE_PLUGIN_ROOT}/references/yaml-schema.md` 3 章、Phase 別の実行コマンド例は `${CLAUDE_SKILL_DIR}/references/flow.md` 6 章）。

- サブコマンド: `init` / `start-run` / `record` / `finish-run` / `select` / `validate` / `summary`
- exit code: `0`=正常 / `1`=一般エラー / `2`=バリデーションエラー（欠落フィールドを stderr 出力）/ `3`=ロック競合（.lock 残留時は実行中プロセスがないことを確認して手動削除）/ `64`=引数パースエラー（サブコマンド・オプションの typo）

## 実行モード判定

起動コマンド・引数・依頼内容から以下のモードを確定する。判定に迷う場合はユーザーに確認する。

| モード | 引数 | フロー |
|-------|------|-------|
| フル | （既定） | Phase 0→1→1.5→(1.6)→2→3→4→5→6→7（(1.6) は fixture 有効時のみ） |
| 再テスト | `retest full` / `retest ng-only` / `retest ids=TC-...` | Phase 0→(1 必要時)→4→5→6→7（実績は既存 YAML へ append マージ） |
| 部分: design-only | `design-only` | Phase 0→2→3（設計レビューゲートまで。run へ進まない） |
| 部分: run-only | `run-only levels=<level,...>`（対象レベル指定必須） | Phase 0→(1 必要時)→4→5（select full の結果を指定レベルで絞り込む） |
| 部分: report-only | `report-only` | Phase 0→7（実績 YAML から報告書を再生成。run なし） |
| 再開 | `resume` | Phase 0→復帰位置判定（`${CLAUDE_SKILL_DIR}/references/flow.md` 5 章）→Phase 5 残ケース→6→7 |
| 非対話 | `--non-interactive`（各モードに併用） | 確認をスキップし既定値で進行（既定値表は `${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 9 章） |

- 再テストのモード定義・対象判定マトリクス・resume 規約は `${CLAUDE_PLUGIN_ROOT}/references/retest-policy.md` が SSOT
- ng-only は回帰テストの代替ではない（同 3 章）。ng-only 実行時はその旨を引き渡しと報告書に必ず含める
- Phase 1.6（`test-fixture`）はフルフローでのみ・条件付きで委譲する（`analysis.yaml` で web-app かつ 認証 EP / 外部依存ありのとき）。見込みレベルが unit のみ、または design-only / run-only / retest / report-only ではスキップする。委譲されても非 web・認証も外部依存もなしと判断された場合は test-fixture 側で no-op（空 `fixtures.yaml`）となり、既存の探索的 MCP フロー（`automation: playwright`）は不変（`${CLAUDE_PLUGIN_ROOT}/references/playwright-test.md`）

## 実行フロー

```mermaid
flowchart TD
    P0["Phase 0: target-slug 解決 + init"] --> P1["Phase 1: setup 確認（必要時）\nSkill: test-setup"]
    P1 -->|"新規 MCP 登録あり"| HANDOFF1["再起動ハンドオフを出力して停止\n（再起動後 resume）"]
    P1 --> P15["Phase 1.5: 解析\nSkill: test-analyze"]
    P15 -->|"fixture 有効"| P16["Phase 1.6: フィクスチャ基盤（条件付き）\nSkill: test-fixture"]
    P15 -->|"fixture 不要（スキップ）"| P2["Phase 2: 設計\nSkill: test-design"]
    P16 --> P2
    P2 --> P3["Phase 3: 設計レビュー\nSkill: test-review（設計文脈）"]
    P3 -->|"NEEDS REVISION\n（修正ループ上限 3 回）"| P2
    P3 -->|PASS| P4["Phase 4: run 対象確定 + ゲート\nselect → 承認済みケース → 人間承認 → MCP"]
    P4 -->|"MCP 未ロード"| HANDOFF2["再起動ハンドオフを出力して停止\n（再起動後 resume）"]
    P4 -->|"全ゲート通過"| P5["Phase 5: 実行\nstart-run → test-run-*（レベル順逐次）→ record → finish-run"]
    P5 --> P6["Phase 6: 結果レビュー\nSkill: test-review（結果文脈）"]
    P6 --> P7["Phase 7: 報告\nvalidate → Skill: test-report"]
```

フェーズ遷移・ゲート判定・遡行ループ・resume 復帰位置判定の詳細は `${CLAUDE_SKILL_DIR}/references/flow.md`、フェーズ間の受け渡しデータは `${CLAUDE_SKILL_DIR}/references/state-handoff.md` を参照。

### Phase 別の要点

| Phase | 内容 | 委譲先 / 操作 |
|-------|------|-------------|
| 0: target 解決 | `{base}` 解決 → 既存 slug は **AskUserQuestion** で選択（非対話: 唯一の既存 slug、複数はエラー中断）→ venv 準備 → `init` | results_manager |
| 1: setup 確認 | run を含むモードで環境未検証の場合のみ。検出結果（MCP ロード状況・ランナー・venv）を受領。新規 MCP 登録時は再起動ハンドオフを出力して**停止**。総合判定 **PARTIAL**（一部チェック失敗 + 一部成功）受領時は、利用可能なレベルは続行し、利用不可レベルに属するケースは実行時に skipped 記録となる旨を確認して進む（詳細な判定は test-setup の検出結果に従う） | Skill: test-setup |
| 1.5: 解析 | フルフローで対象ソースを read-only 解析し、`analysis.yaml` / `target-analysis.md`（下流消費材料）を生成。決定は行わず提案（hint）に留める。`spec=` / `diff=` 指定時は仕様乖離 / 変更影響も材料化 | Skill: test-analyze |
| 1.6: フィクスチャ基盤（条件付き） | フルフローで fixture が有効な場合のみ（unit のみ・design-only / run-only / retest / report-only はスキップ）。`analysis.yaml` を消費し、再現可能な Playwright Test 基盤（`fixtures.yaml` + SUT テストコード）を生成 / 拡充。非 web・認証も外部依存もなしは no-op（空マニフェスト） | Skill: test-fixture |
| 2: 設計 | test-plan.md + test-cases.yaml（全ケース draft）の生成 | Skill: test-design |
| 3: 設計レビュー | PASS → test-review が approved 化まで実施。NEEDS REVISION → test-design へ差し戻し（**上限 3 回**、超過時は対話=AskUserQuestion / 非対話=エラー中断） | Skill: test-review（design） |
| 4: 対象確定 + ゲート | `select` で scope を機械確定（LLM 判断禁止）→ 承認済みケースゲート → 人間承認ゲート（**AskUserQuestion**。非対話はスキップ）→ MCP ゲート（ToolSearch 実判定。未ロードは再起動ハンドオフで**停止**、unit のみは判定不要） | results_manager + AskUserQuestion + ToolSearch |
| 5: 実行 | `start-run` → レベル順**逐次**で test-run-* を Skill 起動（並列禁止）→ 中間結果を 1 件ずつ `record`（exit 2 は当該実行スキルへ追加取得を指示して再 record）→ `finish-run`（欠落検出時は補完実行後に再確定） | Skill: test-run-* + results_manager |
| 6: 結果レビュー | 欠陥分析・severity 妥当性の検証。NEEDS REVISION の遡行は flow.md 4 章（上限 3 回） | Skill: test-review（results） |
| 7: 報告 | `validate`（違反があれば差し戻して生成しない）→ test-report 起動（形式選択は test-report が実施、非対話既定 Markdown）。報告書はセッション作業領域直下 | results_manager + Skill: test-report |

各 Phase の具体的な実行コマンド・Skill args・判定手順は `${CLAUDE_SKILL_DIR}/references/flow.md` 6 章（実行コマンド集）を参照。

## 検証

完了報告の前に以下をすべて確認する。

- [ ] モードに応じた全フェーズが完了している（部分モードは該当フェーズのみで完了扱い）
- [ ] run を含むモードで、finish-run の status が `completed` になっている（interrupted の場合は resume 案内を引き渡しに含める）
- [ ] `validate` が ok（violations 0 件）である
- [ ] 報告書がセッション作業領域直下に存在する（report を含むモードのみ）
- [ ] `{base}/playwright/` に帰属不明の残留ファイルがない（あれば警告して整理する。`${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` 5 章）

## 引き渡し

### 正常完了時

以下をまとめてユーザーへ報告する。

- run_id・実行モード・対象 target-slug
- レベル別集計（summary の出力: 対象数 / pass / fail / blocked / skipped / na）と run 横断推移
- NG 一覧（case_id・severity・タイトル）
- 報告書のパス（生成した場合）
- 未確認事項（skipped 一覧と reason）
- ng-only 実行時: 「回帰テストの代替ではない。副作用検出には full を推奨」の注記
- 再テストの案内（`/deep-test:test-retest`）

### 停止・中断時

- MCP ゲート停止: 再起動ハンドオフ（状態保存済みの明示 / 再起動依頼 / `resume` での再開手順）を出力する（`${CLAUDE_PLUGIN_ROOT}/references/playwright-mcp.md` 3 章）
- その他の中断: 中断位置・test-results.yaml の記録状況・再開手段（resume または該当モード）を報告する

## 重要な制約

- **test-results.yaml を Edit / Write で直接編集しない**。すべて results_manager.py 経由（`${CLAUDE_PLUGIN_ROOT}/references/yaml-schema.md` 3 章）
- **test-cases.yaml も本スキルでは編集しない**（生成・更新は test-design の責務）
- **実行スキルの並列起動禁止**。レベル順の逐次起動のみ（Playwright MCP のブラウザセッション共有制約。`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 3 章）
- **逆呼び出し禁止**。依存方向は「コマンド → test → worker スキル → エージェント」の単方向。worker スキルから本スキルを呼ばせない
- **エージェントの直接起動禁止**（worker スキルの責務）
- **select を経ない再テスト対象の確定禁止**（`${CLAUDE_PLUGIN_ROOT}/references/retest-policy.md` 8 章）
- **MCP 未ロード時に利用可能を装って続行しない**（再起動ハンドオフを出して停止する）
- **本番環境への実行は既定で禁止**（`${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 6 章）
- 報告書を `{target-slug}/` 配下に保存しない（セッション作業領域直下が正位置）

## 参照

| ファイル | 内容 |
|---------|------|
| `${CLAUDE_PLUGIN_ROOT}/references/CLAUDE.md` | プラグイン共通 references の読み込みガイド（最初に読む） |
| `${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` | ゲート 4 種の定義・中間結果フォーマット・非対話既定値表・実行共通規範 |
| `${CLAUDE_PLUGIN_ROOT}/references/retest-policy.md` | 再テストモード・対象判定マトリクス・resume 規約・latest 集計規則 |
| `${CLAUDE_PLUGIN_ROOT}/references/yaml-schema.md` | 実績 YAML の共通規約・操作規約（スキーマ本体は `yaml-schema-cases.md` / `yaml-schema-results.md` に分割） |
| `${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` | 基準ディレクトリ・target-slug 解決・配置ツリー・エビデンス移送 |
| `${CLAUDE_PLUGIN_ROOT}/references/playwright-mcp.md` | MCP 実利用可否判定（ToolSearch 手順）・再起動ハンドオフ |
| `${CLAUDE_PLUGIN_ROOT}/references/test-levels.md` | テストレベル定義・レベル→実行スキル対応 |
| `${CLAUDE_PLUGIN_ROOT}/references/evidence-policy.md` | fail 時 3 点セット・二段バリデーション |
| `${CLAUDE_SKILL_DIR}/references/flow.md` | フェーズ遷移詳細・ゲート判定手順・遡行ループ・resume 復帰位置判定 |
| `${CLAUDE_SKILL_DIR}/references/state-handoff.md` | フェーズ間の引き継ぎデータ規約（args 規約・返却 JSON 構造） |
| `${CLAUDE_SKILL_DIR}/references/scripts/results/results_manager.py` | 実績 YAML 操作スクリプト（test-results.yaml への書き込みの唯一経路。test-report が validate 目的で読み取り実行する利用は許容） |
| `${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/` | venv 構築・削除スクリプトと requirements.txt（プラグイン共通） |
