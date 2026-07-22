---
name: test-setup
description: deep-test のテストツールチェーン（Playwright MCP・ランナー・venv）を検証するスキル。既存登録検出・規約準拠の新規登録・ToolSearch 実利用判定・再起動ハンドオフ・ランナー検出（pytest 等）・venv 構築を一元化し検証レポート返却。責務外=Docker 派生環境の構築・起動（test-environment）。deep-test の test 委譲時や「deep-test のテストツールチェーンを準備して」「Playwright MCP をセットアップして」と依頼時に使用。Use when preparing deep-test toolchain.
allowed-tools:
  - Read
  - Grep
  - Glob
  - ToolSearch
  - AskUserQuestion
  - Bash(claude mcp *)
  - Bash(bash *)
---

# test-setup スキル

テスト実行環境（Playwright MCP・テストランナー・venv）の構築と検証を一元化するフェーズスキル。チェック結果を環境検証レポートとして返却し、後続の MCP ゲート判定・実行スキル委譲の判定材料を提供する。

## 責務

| # | 責務 | 概要 |
|---|------|------|
| 1 | Playwright MCP のセットアップ | `claude mcp list` で既存登録を検出し、未登録なら登録要否の判断分岐（levels の Playwright 必要レベル有無・対話 / 非対話）を経て規約コマンド（`${CLAUDE_PLUGIN_ROOT}/references/playwright-mcp.md` 1 章）で新規登録。登録した場合は再起動ハンドオフ（同 3 章）を添えて停止 |
| 2 | Playwright MCP の実利用可否判定 | 登録済みの場合、ToolSearch による実判定（同 4 章）でロード済み / 未ロードを判定する |
| 3 | テストランナー検出 | 構成ファイル・テストファイル規約 + ランナー実体・宣言の 3 段規則（`${CLAUDE_SKILL_DIR}/references/setup-procedures.md` 4 章 = SSOT）で pytest / jest / vitest / dotnet test 等を検出し、根拠・実行コマンド例とともに報告（テストは実行しない） |
| 4 | venv の確認・構築 | セッション作業領域 `workspace/.venv` の存在を確認し、無ければプラグイン共通の `${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/` で構築 |
| 5 | フィクスチャ基盤の有無検出 | SUT に Playwright Test 基盤（`playwright.config.ts` / `{tests}/fixtures/` の存在）があるかを Glob / Grep で **有無検出**（構築・拡充はしない）。検出結果は Phase 1.6 の `test-fixture` が新規構築 / 拡充を判断する材料になる |
| 6 | docker 資産の有無検出 | SUT に docker 資産（compose / Dockerfile）があるかを Glob で **有無検出**し、存在と場所の記録のみ（構築・起動はしない = `test-environment` の責務）。検出結果は Phase 1.7 の `test-environment` が派生・起動を判断する材料になる |
| 7 | 環境検証レポート返却 | チェック項目ごとの利用可 / 不可 / 未チェックの一覧と総合判定を返却 |

## 責務外（他スキルが担当）

| 責務外 | 担当 |
|-------|------|
| テストの実行（検出したランナーの実行を含む） | `test-run-*` 実行スキル 6 種 |
| MCP ゲートの判定（run 直前の通過 / 停止の決定） | オーケストレータ `test`（本スキルは判定材料の提供まで） |
| テスト計画・ケース設計 | `test-design` |
| テスト成果物のレビュー | `test-review` |
| 実績 YAML（test-results.yaml）への記録 | オーケストレータ `test`（専用スクリプト経由） |

## トリガー条件

起動する:

- オーケストレータ `test` から Skill ツール経由で委譲（フルフローの setup フェーズ、MCP ゲート前の事前検証）
- 「テストツールチェーンを準備して」「Playwright MCP をセットアップして」「テストランナーを検出して」と依頼された

起動しない:

- テストの実行そのものを求められた（`test-run-*` の責務）
- deep-test の実行環境と無関係な一般的開発環境の構築を求められた

## 前提

- `${CLAUDE_PLUGIN_ROOT}/references/common-references.md` 3.5（セットアップ時）が参照する共通規範一式が存在する
- `claude` CLI が利用可能である（MCP の登録・検出に使用）

受け取る引数（すべて任意）:

| 引数 | 内容 | 未指定時 |
|------|------|---------|
| `levels=` | 予定テストレベル（カンマ区切りの level 値）。MCP チェック要否の導出材料（レベル別の MCP 要否は `${CLAUDE_PLUGIN_ROOT}/references/execution-policy.md` 1.4 章の表） | 全チェック実施 |
| `checks=` | チェック対象の明示指定（`playwright` / `runner` / `venv` のカンマ区切り。`levels=` より優先） | `levels=` から導出 |
| `target-slug=`（別名 `target=`） | 対象 slug（委譲時にオーケストレータが渡す。レポートの対象識別に使用） | 対象識別なしで検証のみ実施 |
| `base=` | 基準ディレクトリ（委譲時に受領） | `data-locations.md` 1 章で解決 |
| `project=` | テストランナー検出の対象プロジェクトルート | カレントの作業ディレクトリ |
| `session=` | セッション作業領域パス（venv 配置先 `workspace/.venv` の親） | 現行セッションの作業領域を解決 |
| `--non-interactive` | 非対話モード | 対話モード |

## 実行モード判定

| 判定条件 | モード | 動作 |
|---------|-------|------|
| 引数に `--non-interactive` を含む（委譲時はオーケストレータが付与） | 非対話 | 確認なしで検出・判定を進行。未登録時の新規登録は行わず `not-registered` とする（永続的副作用を非対話で作らない。`${CLAUDE_SKILL_DIR}/references/setup-procedures.md` 3.2 章）。登録済み・未ロードで再起動が必要な場合は自動続行せず、ハンドオフを添えて停止（`execution-policy.md` 非対話既定値表の「MCP ゲートで未ロード」と同趣旨） |
| 上記以外 | 対話 | 通常は確認なしで進行し、曖昧な状況（playwright 系登録が複数見つかる等）のみ AskUserQuestion で確認 |

## 実行フロー

詳細手順は `${CLAUDE_SKILL_DIR}/references/setup-procedures.md` に従う。

### 1. チェック対象確定
引数を解釈し、チェック対象（playwright / runner / venv）を確定。

### 2. Playwright MCP チェック
既存登録を検出し、未登録なら登録要否の判断分岐（setup-procedures.md 3.2 章。levels に Playwright 必要レベルが含まれない場合・対話での否認時・非対話時は登録せず `not-registered` を記録）を経て新規登録し、登録済みなら ToolSearch で実利用可否を判定。

### 3. テストランナー検出
3 段の検出規則（setup-procedures.md 4 章）でランナーを検出し、根拠・実行コマンド例を整理（構成ファイルなし + ランナー実体なしの場合のセッション venv への導入可否は同 4.4 章）。

### 4. venv チェック
`workspace/.venv` を確認し、無ければオーケストレータの setup スクリプトで構築。

### 5. レポート組み立て
環境検証レポートを組み立て、総合判定（READY / RESTART_REQUIRED / PARTIAL）を確定。

### 6. 再起動判定
再起動が必要な場合（新規登録・未ロード検知）は、レポートに再起動ハンドオフを添えて返却し停止。

## 検証

返却前に以下を確認する。未達成の項目は解消してから返却する。

- [ ] 要求された全チェック項目に状態を付与した（未チェック項目を「利用可」と書いていない）
- [ ] 既存の playwright 系登録に対して重複登録・上書きをしていない（playwright-mcp.md 2 章）
- [ ] 新規登録した場合、再起動ハンドオフを添えて RESTART_REQUIRED で返却している（同 3 章）
- [ ] ロード判定を ToolSearch の実結果で行った（`claude mcp list` の登録有無だけで「利用可」としていない。同 4 章）
- [ ] テストランナー検出結果に根拠（検出の段・根拠ファイル・起動確認結果等）と実行コマンド例を併記した
- [ ] venv の構築失敗・スクリプト不在を ready と偽装していない
- [ ] 環境検証レポートの必須項目（総合判定・チェック項目表・引き継ぎ事項）が揃っている

## 引き渡し（オーケストレータへの返却内容）

最終応答に以下の環境検証レポートを含めて返却する（状態値の定義・組み立て手順は `${CLAUDE_SKILL_DIR}/references/setup-procedures.md` 6〜7 章）。

```markdown
## 環境検証レポート（test-setup）

- 総合判定: READY | RESTART_REQUIRED | PARTIAL

| チェック項目 | 状態 | 詳細 |
|-------------|------|------|
| Playwright MCP 登録 | registered / newly-registered / not-registered / failed / not-checked | 登録名・output-dir 設定（not-registered は理由必須） |
| Playwright MCP ロード | loaded / not-loaded / not-checked | ToolSearch 判定結果 |
| テストランナー | detected / none / not-checked | ランナー・根拠ファイル・実行コマンド例 |
| venv | ready / created / failed / not-checked | venv パス |
| フィクスチャ基盤 | detected / none / not-checked | `playwright.config.ts` / `{tests}/fixtures/` の有無検出結果（Phase 1.6 の test-fixture が新規構築 / 拡充を判断する材料。SUT テストコードの生成は test-fixture の責務。総合判定のゲートではなく情報項目） |
| docker 資産 | detected / none / not-checked | compose（`compose.y*ml` / `docker-compose.y*ml`）・`Dockerfile*` の存在と場所の検出結果（Phase 1.7 の test-environment が派生・起動を判断する材料。構築・起動は test-environment の責務。総合判定のゲートではなく情報項目） |

### 引き継ぎ事項
- MCP ゲート（execution-policy.md 1.4 章）の判定材料・再起動ハンドオフの実施有無
- test-run-unit への引き継ぎ（検出ランナーの詳細）
- 利用不可項目と後続影響（該当レベルの skipped 見込み。execution-policy.md 2 章）
```

- 総合判定が RESTART_REQUIRED の場合は、レポートに続けて再起動ハンドオフ（playwright-mcp.md 3 章のメッセージ例に準拠）を出力して停止する。委譲時はオーケストレータがそのままユーザーへ提示する

## 重要な制約

- 既存の playwright 系登録がある場合、重複登録・上書き（remove して add し直す等）をしない（playwright-mcp.md 2 章）
- 新規登録した場合、同一セッションで MCP ツールの利用を試みず、必ず再起動ハンドオフを出力して停止する（同 3 章）
- ロード済み判定を `claude mcp list` の登録有無だけで行わない（ToolSearch の実結果で判定する。同 4 章）
- 検出したテストランナーでテストを実行しない（起動確認は `--version` 等の無害なコマンドに限る。テスト実行は `test-run-unit` の責務）
- 未登録の Playwright MCP を判断分岐（setup-procedures.md 3.2 章）を経ずに新規登録しない（levels に必要レベルがない場合・非対話時は `not-registered` とし、永続的副作用を作らない）
- 利用不可・未チェックの項目を「利用可」「問題なし」と書かない（条件付き動的検証。execution-policy.md 2 章）
- `test-results.yaml` への書き込み・編集を行わない

## 参照

| 参照先 | 内容 |
|-------|------|
| `${CLAUDE_PLUGIN_ROOT}/references/common-references.md` | プラグイン共通規範の集約インデックス（本スキルの場面別参照は 3.5 章「セットアップ時」） |
| `${CLAUDE_SKILL_DIR}/references/setup-procedures.md` | 検出・登録・実利用可否判定・ハンドオフ・レポート組み立ての詳細手順 |
