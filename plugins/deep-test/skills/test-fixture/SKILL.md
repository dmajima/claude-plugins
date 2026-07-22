---
name: test-fixture
description: Playwright フィクスチャ基盤（storageState・API モック・シード・base）を作成・拡充する Phase 1.6 スキル。analysis.yaml を消費し fixtures.yaml と SUT テストコードを生成。責務外=ケース設計(test-design)・テスト実行(test-run-*)・ツールチェーン検証(test-setup)。test 委譲時や「フィクスチャ基盤を作って」「認証 storageState を用意して」「API モックを追加して」と依頼時に使用。Use when building deep-test fixtures.
allowed-tools:
  - Read
  - Grep
  - Glob
  - Write
  - Edit
  - Bash(date *)
  - Bash(npx playwright *)
  - Agent(deep-test:fixture-architect)
  # MCP（mcp__playwright__*）は既定で足さない。実ログインフロー探索が要る対象のみオプトインで追加する
---
<!-- TEST-FIXTURE-SKILL-SENTINEL-v1 -->

# test-fixture スキル

Playwright フィクスチャ基盤（認証 storageState・API モック・シード・base）を作成・拡充する Phase 1.6 フェーズスキル。`test-analyze` の `analysis.yaml` を材料に、再現可能テスト（`.spec.ts` + フィクスチャ）の**下地**を用意する。生成物は SUT のテストコードと機械可読 `fixtures.yaml`（`test-design` が Phase 2 で消費）。**ケースの定義・実行・記録には関与しない**（材料を受け取り下地を産出して止まるのが境界）。

## 責務

| # | 責務 | 概要 |
|---|------|------|
| 1 | フィクスチャ要否の判定 | `analysis.yaml`（target_type・認証 EP・外部依存）から再現可能 Playwright Test 基盤が有効かを判定。不要（unit のみ / 非 web / 認証も外部依存もなし）なら空マニフェストで no-op を返す |
| 2 | 既存基盤の検出 | SUT の `playwright.config.ts` / `{tests}/fixtures/` / `auth.setup.ts` / storageState を Read/Glob/Grep で検出し、新規作成か拡充かを分岐 |
| 3 | 認証フィクスチャ | `auth.setup.ts`（ログイン → storageState 保存）と config の projects で storageState を再利用する構成を生成。認証情報は実値を書かず取得方法のみ記述する |
| 4 | モックフィクスチャ | 外部 API/決済/メール等を `route.fulfill` / network interception で差し替える `test.extend` を生成 |
| 5 | シードデータ | テスト前提データの投入・クリーンアップ（globalSetup / seed スクリプト）を生成 |
| 6 | ベースフィクスチャ | `test.extend()` によるカスタムフィクスチャ（認証済み page・モック済み context 等）を生成 |
| 7 | 既存基盤の拡充 | 既存 config/fixtures を壊さず不足分（未カバー認証パターン・未モック外部依存）を非破壊で追加 |
| 8 | fixtures.yaml マニフェスト出力 | 作成・拡充したフィクスチャ一覧（種別・名前・提供内容・artifact パス・status）を `{base}/{target-slug}/fixtures.yaml` に出力 |
| 9 | 自己チェック | `fixture-architect` エージェントで設計の妥当性・再利用性・分離・書き込み境界・認証情報ハードコードを単独レビューし、重大指摘を反映してから返却 |

## 責務外（他スキルが担当）

| 責務外 | 担当 |
|-------|------|
| テストケース設計・技法適用・レベル選定・優先度決定（fixtures.yaml を**消費**する側） | `test-design`（Phase 2） |
| テストの実行（生成したフィクスチャ/テストの実走） | `test-run-*`（実行スキル 6 種） |
| 実行環境の構築（Playwright MCP 登録・ランナー検出・venv） | `test-setup`（Phase 1） |
| 対象アプリの一次分析（fixture は analysis.yaml を消費するのみ・逆生成しない） | `test-analyze`（Phase 1.5） |
| 認証情報のフル値の管理・保存・取得 | `credentials-manager`（fixture は取得方法のみ記述する） |
| Docker 等のテスト実行環境の構築 | `test-environment`（Phase 1.7） |

## トリガー条件

起動する:

- オーケストレータ `test` から Skill ツール経由で委譲（フルフローの Phase 1.6・fixture 有効判定時）
- 「フィクスチャ基盤を作って」「認証 storageState を用意して」「API モックを追加して」「テストの下地を拡充して」と依頼された

起動しない:

- テストケース・テスト計画の設計を求められた（`test-design` の責務）
- テストの実行・カバレッジ実測を求められた（`test-run-*` の責務）
- Playwright MCP 登録・ランナー検出等の環境構築を求められた（`test-setup` の責務）
- 対象アプリの一次解析（analysis.yaml 生成）を求められた（`test-analyze` の責務）

## 前提

- `${CLAUDE_PLUGIN_ROOT}/references/` の共通規範（playwright-test.md / yaml-schema-analysis.md / data-locations.md / agents.md）が存在する
- `fixture-architect` エージェント定義がプラグインルート `agents/` に存在する
- `analysis.yaml`（`test-analyze` 生成）が存在すれば材料に消費。無ければ Read/Glob/Grep で軽量補完する（3.2）
- テスト用接続情報（ホスト・公開ポート）は `test-environment`（Phase 1.7）の `environment.yaml` から env var 名で受領できる（Phase 1.7 以降。seed / globalSetup は実値をハードコードせず env var 参照で書く）

受け取る引数:

| 引数 | 内容 | 未指定時 |
|------|------|---------|
| `target-slug=`（別名 `target=`） | 解決済み slug（委譲時にオーケストレータが付与） | 単独時は `data-locations.md` 4 章の解決フロー |
| `base=` | 基準ディレクトリ（委譲時に受領） | `data-locations.md` 1 章で解決 |
| `project=` | SUT のプロジェクトルート（**テストコード生成先の基準**・既存 config 検出の起点） | カレント作業ディレクトリ |
| `対象説明=` または位置引数 | アプリ URL・リポジトリパス・対象名 | 委譲時は analysis.yaml の meta / 引数から補完 |
| `--non-interactive` | 非対話モード | 対話モード |

> 上流連携: `test-analyze`（Phase 1.5）の `analysis.yaml` を材料に消費する。`test-setup`（Phase 1）が検出した既存 fixture 基盤情報を（利用可能なら）受け取る。

## 実行モード判定

| 判定条件 | モード | 動作 |
|---------|-------|------|
| 引数に `--non-interactive` を含む（委譲時はオーケストレータが付与） | 非対話 | 曖昧確認せず進行。target-slug は `data-locations.md` 4.2 章の非対話規則（唯一の既存 slug 採用・複数はエラー中断）に従う。`.gitignore` 追記は提案に留める |
| 上記以外 | 対話 | 不足情報（target-slug・対象・`.gitignore` 追記可否）をユーザーに確認。委譲時は target-slug / base / project 受領済みのため確認は不要 |

## 実行フロー

詳細手順は `${CLAUDE_SKILL_DIR}/references/fixture-procedures.md`、パターン集は `${CLAUDE_SKILL_DIR}/references/fixture-patterns.md`、エージェント運用は `${CLAUDE_SKILL_DIR}/references/agents.md` に従う。本スキルは deep-test ライフサイクルの **Phase 1.6**（`test-analyze` の後・`test-design` の前）に位置する。

### 1. 入力解決・target-slug 確定
引数を解釈し `project=` と target-slug を確定（委譲時は受領値、単独時は解決フロー）。`{base}/{target-slug}/analysis.yaml` の存在を Read で確認。

### 2. analysis.yaml 消費（材料受領）
存在時は `entry_points`（auth）→ 認証、`dependency_summary.external_dependencies` → モック、`attack_surface_summary` → 認証切替、`meta.target_type` → 要否判定の材料に用いる。非存在時は 3.2 の軽量補完（`analysis_consumed: false`・confidence を下げる）。

### 3. 要否判定（no-op 分岐）
非 web / unit のみ / 認証も外部依存もなしと判断したら、SUT に何も書かず **空の fixtures.yaml（`fixtures: []`）+ 理由** を出力し正常終了（非破壊 no-op）。

### 4. 既存基盤の検出
`project=` を起点に `playwright.config.ts` / `{tests}/fixtures/` / `auth.setup.ts` / storageState を Glob/Grep で検出し、新規作成（無）か拡充（有）かを分岐。

### 5. 生成 or 拡充
`fixture-patterns.md` に従い、認証 / モック / シード / base のフィクスチャと config を生成（無）または非破壊で不足分を追加（有）。書き込みは **SUT のテストディレクトリのみ**。

### 6. fixtures.yaml マニフェスト出力
作成・拡充結果を `{base}/{target-slug}/fixtures.yaml`（`playwright-test.md` スキーマ）に Write。`status`（created/extended/existing）でトレースする。

### 7. 自己チェック
`fixture-architect` エージェントを単独起動し、設計の妥当性・再利用性・分離・書き込み境界・認証情報ハードコードをレビューさせる。重大指摘を反映（反映は本スキルが行い、エージェントには修正させない）。

## 検証

返却前に以下を確認する。未達成の項目は解消してから返却する。

- [ ] fixtures.yaml が `playwright-test.md` スキーマに準拠している（meta 必須フィールド・`type` / `status` / `confidence` の enum・parse 可能な YAML）
- [ ] no-op 判定時は SUT に何も書かず `fixtures: []` + 理由を出力した（非破壊）
- [ ] 書き込みは **SUT のテストディレクトリ**（`{project}/{tests}/` ・playwright.config.ts）に限定し、プロダクションコードを変更していない
- [ ] 認証情報の実値を config/fixture/setup に**ハードコードしていない**（環境変数・credentials-manager 経由の取得コードにした）
- [ ] storageState 出力先（`.auth` 等）の `.gitignore` 追記を提案した（実トークンをコミットしない）
- [ ] 既存基盤の拡充時に既存の書式・命名を尊重し、破壊的上書きをしていない（不足分の非破壊マージ）
- [ ] `analysis_consumed` と各 fixture の `confidence` が材料の確からしさと整合している（補完時は下げた）
- [ ] fixture-architect の自己チェックを実施し、重大指摘を反映した（プロンプトに共通注入事項を含めた）
- [ ] test-results.yaml / test-cases.yaml / analysis.yaml へ書き込んでいない

## 引き渡し（オーケストレータへの返却内容）

最終応答に以下のフィクスチャ構築結果サマリを含めて返却する。

```markdown
## フィクスチャ基盤構築結果（test-fixture）

- target-slug: <slug> / 生成ファイル: fixtures.yaml（絶対パス）/ analysis_consumed: <true|false>
- 対象種別: <target_type> / 判定: <生成 | 拡充 | no-op（理由）>

| type | 件数 | status 内訳（created/extended/existing） |
|------|------|----------------------------------------|
| auth | <n> | ... |
| mock | <n> | ... |
| seed | <n> | ... |
| base | <n> | ... |

- 生成/拡充した SUT テストコード: <playwright.config.ts / tests/fixtures/*.ts の相対パス一覧>
- fixture-architect 自己チェック所見: 反映済み指摘 / 反映不要と判断した指摘（理由付き）
- .gitignore 追記提案: <storageState/.auth の除外提案の有無>
- 次フェーズ: fixtures.yaml を材料に test-design が `fixtures:` と `automation: playwright-test` を決定する
```

## 重要な制約

- **書き込み境界（新境界）**: SUT の**テストディレクトリのみ** Write/Edit 可（`playwright.config.ts` / `{tests}/fixtures/*.ts` / `auth.setup.ts` / seed）。SUT のプロダクションコード・DB スキーマ・業務ロジックへは**一切書き込まない**。`test-results.yaml` / `test-cases.yaml` / `analysis.yaml` へも書き込まない（各所有スキルの専有）。`playwright-test.md` 4 章が SSOT
- **認証情報のハードコード禁止**: 実値を config/fixture/setup に書かず、環境変数・credentials-manager 経由の取得コードとして記述する（credentials-management ルール MANDATORY）。storageState 出力先は `.gitignore` 追記を提案し実トークンをコミットしない
- **決定をしない**: テストケースの `fixtures:` 参照・`automation: playwright-test` の選定・レベル/技法/優先度は `test-design` の専有。本スキルは下地（fixture コード + マニフェスト）を作るに徹する
- **no-op 条件**: 非 web / unit のみ / 認証も外部依存もなしなら SUT に何も書かず空 fixtures.yaml + 理由で正常終了する（既存 MCP フローを壊さない非破壊パターン）
- **捏造禁止**: analysis.yaml 未消費時（補完）は `analysis_consumed: false` と `confidence` を下げ、推定を確定情報として書かない。稼働アプリへの能動プローブ（実ログイン試行等）はしない
- 他 worker スキルを呼ばない（逆呼び出し禁止）。自エージェント `fixture-architect` と read-only + SUT テスト書き込みツールのみ使用する（2 段委譲を厳守）
- fixture-architect には評価のみをさせ、成果物の修正はさせない（指摘の反映は本スキルが行う。agents.md 冒頭の構造規範）

## 参照

| 参照先 | 内容 |
|-------|------|
| `${CLAUDE_PLUGIN_ROOT}/references/playwright-test.md` | fixtures.yaml スキーマ SSOT・Playwright Test 実行規約・認証/モック/シード/base のパターン規範・書き込み境界 |
| `${CLAUDE_PLUGIN_ROOT}/references/yaml-schema-analysis.md` | 消費する `analysis.yaml` の完全スキーマ（entry_points / external_dependencies / attack_surface_summary） |
| `${CLAUDE_PLUGIN_ROOT}/references/data-locations.md` | fixtures.yaml の配置パス・target-slug 解決フロー・SUT テストコードは管理対象外である旨 |
| `${CLAUDE_PLUGIN_ROOT}/references/agents.md` | fixture-architect の選定・起動方式・プロンプト組み立て・共通注入事項 |
| `${CLAUDE_SKILL_DIR}/references/fixture-procedures.md` | 入力解決 → 消費 → 既存検出 → 生成/拡充 → マニフェスト出力 → 自己チェックの詳細手順 |
| `${CLAUDE_SKILL_DIR}/references/fixture-patterns.md` | 認証(storageState)/モック(route.fulfill)/シード/base(test.extend) のパターン集と最小コード例 |
| `${CLAUDE_SKILL_DIR}/references/agents.md` | 本スキルのフェーズ定義（fixture-architect の起動フェーズ） |
