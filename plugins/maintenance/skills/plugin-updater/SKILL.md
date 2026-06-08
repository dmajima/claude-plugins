---
name: plugin-updater
description: "Claude Code 公式 CLI 経由でマーケットプレイス・プラグインを一括最新化するスキル。`/update-all`（全プロジェクト対象）または `/update`（現在のプロジェクトのみ）コマンドからの委譲経由のみで起動（AI 自動起動非想定）。Use only when explicitly invoked via /update-all or /update. SKIP when adding/removing plugins (/plugin), building plugins (extension-toolkit), workspace cleanup (cleanup-workspace), or settings sync (sync-settings). For complex requests combining multiple maintenance areas, use AskUserQuestion to confirm order."
---

# plugin-updater

Claude Code 公式 CLI（`claude plugin marketplace update` / `claude plugin update`）を経由して
インストール済みマーケットプレイスとプラグインを **一括で最新版に更新** する実作業スキル。

`/update-all` コマンド（全プロジェクト対象）または `/update` コマンド（現在のプロジェクトのみ）から
委譲されて起動する（コマンドはトリガー / 引数解釈のみを担当）。
詳細な Phase 仕様・横断ルール・設計判断は本スキルの `references/` 配下に集約されている。

## 責務

- Phase A-0 → G の固定順序での更新実行
- 横断ルール XR-1〜XR-5 の適用（入力検証 / タイムアウト / 出力サニタイズ / リトライ上限 / Unknown 警告）
- ユーザー対話（Phase G の AskUserQuestion による失敗対応確認）
- 結果報告（Phase F のサマリ + 詳細テーブル）

## 責務外

- 引数 (`--dry-run`) の解釈とバリデーション → コマンド側（`commands/update-all.md` / `commands/update.md`）
- マーケットプレイス本体（`marketplace.json` / README）の編集 → `extension-toolkit:marketplace-toolkit`
- プラグインの新規公開 → `extension-toolkit:marketplace-publisher`

## トリガー条件

- `/update-all` または `/update` コマンドから Skill ツール経由で起動される（明示的な委譲）
- 本スキルは AI が自動起動する用途を想定していない（コマンド呼び出し経由のみ）

## 前提

- Claude Code CLI（`claude` コマンド）が PATH 上で利用可能
- 呼び出し元コマンドが `mode` / `target` を引数として渡してくる
- Read / Bash / Grep / AskUserQuestion ツールが利用可能

## 重要な制約

- **公式 CLI 経由限定**: `claude plugin marketplace update` / `claude plugin update` のみを使用。
  `git fetch` / `git reset --hard` 等の低レベル git 操作は行わない（ADR-PU-002）
- **Phase 順序の厳守**: Phase A-0 → G の固定順序で実行し、順序を入れ替えない（ADR-PU-003）
- **横断ルール SSOT 参照**: XR-1〜XR-5 の規則本体・閾値・例外は `cross-cutting-rules.md` を
  参照し、本スキル内で再定義しない（ADR-PU-004）
- **シークレット非接触**: `settings.json` 系の `enabledPlugins` 以外のキーをメインコンテキストに
  載せない（Grep ブロック終端検出 + フェイルクローズ。Phase A-Sec を厳守）
- **Failed のみリトライ対象**: Missing は CLI リトライで回復しないため Phase G の対象外
  （ADR-PU-007）。サーキットブレーカー作動中の MP の扱い・Phase B 全件リトライへの非適用は
  ADR-PU-006 が SSOT（本 SKILL.md は再定義しない）
- **全文 Read 禁止**: `settings.json` 全文を Read することは禁止。Grep + ブロック終端検出で
  範囲を限定する

## 起動コンテキスト

呼び出し元コマンドから次の情報を受け取る:

| キー | 値の例 | 既定値（直接スキル起動時） | 説明 |
|------|--------|--------------|------|
| `mode` | `normal` / `dry-run` | `normal` | 通常実行か実行予定提示のみか |
| `target` | `all` / `current-project` | `all` | 更新対象範囲 |

### target の動作差

| target | Marketplace (B) | User (C) | Project (D) | Local (E) |
|--------|----------------|----------|-------------|-----------|
| `all` | 実行 | 実行 | **全プロジェクト** の Project プラグインを更新（`installed_plugins.json` の全 `projectPath` を対象） | **全プロジェクト** の Local プラグインを更新（同上） |
| `current-project` | スキップ | スキップ | **現在のプロジェクト** の Project プラグインのみ更新 | **現在のプロジェクト** の Local プラグインのみ更新 |

### フェイルセーフ既定値

AI トリガー判定で本スキルが `/update-all` コマンドを経由せず直接起動された場合
（ユーザ発話による誤起動等）、`mode` / `target` が空文字列で渡される可能性がある。
本スキルは以下のフェイルセーフ動作を行う:

- `mode` が空 → `normal` を採用
- `target` が空 → `all` を採用
- `mode` / `target` が許容値以外（`maybe` / `foo` 等） → A-0-1 早期失敗

これにより、直接起動された場合でも安全に動作する（破壊的副作用は dry-run でないとしても
Phase G の AskUserQuestion 確認で抑止される）。

`target=current-project` で git リポジトリ外から起動された場合はエラーで中断する。

## 設計判断・実行手順の SSOT

| 内容 | 参照先 |
|-----|--------|
| Phase A-0〜G の固定順序・実行手順詳細 | [`references/phase-flow.md`](references/phase-flow.md) |
| 横断ルール XR-1〜XR-5（入力検証 / タイムアウト / サニタイズ / リトライ / Unknown 警告） | [`references/cross-cutting-rules.md`](references/cross-cutting-rules.md) |
| Phase F のテーブル / 警告 / 質問文フォーマット集 | [`references/output-formats.md`](references/output-formats.md) |
| 設計判断記録（ADR-PU-001〜008） | [`references/architecture-decisions.md`](references/architecture-decisions.md) |
| 動作分岐検証 | [`evals/`](evals/) |

## 実行フロー（概要）

詳細は [`references/phase-flow.md`](references/phase-flow.md) を参照。
Phase 番号体系（`A-0-1` の 3 階層 / `A-1` の 2 階層 / `B-1` のサブフェーズ）の規約は
[`references/architecture-decisions.md`](references/architecture-decisions.md) ADR-PU-003「Phase 番号体系」を参照。

> **SSOT 注記**: 以下の Phase 表は **概要であり実行順序の規範ではない**。実行順序の SSOT は
> `references/phase-flow.md` 冒頭の固定順記述および ADR-PU-003 が担う。本表は迅速な俯瞰用途
> であり、差異が生じた場合は phase-flow.md / ADR-PU-003 を信頼する。

| Phase | 概要 |
|-------|------|
| A-0-1 | 引数バリデーション（`target` ホワイトリスト照合） |
| A-0-2 | Claude Code CLI 存在チェック（必要サブコマンドの正規表現照合） |
| A | 対象収集（`marketplace list` + 各スコープの `enabledPlugins` 抽出） |
| A-1 | プラグイン名 / MP 名 / スコープ名の入力検証（XR-1） |
| A-2 | マーケットプレイス整合性検証（未登録 MP の早期除外） |
| A-3 | スコープ判定（`installed_plugins.json` の `scope` / `projectPath` を使用。`target=all` では全 `projectPath` を対象、`target=current-project` では現在の `<repo>` のみ対象。disabled / 未インストール / projectPath 欠落は除外。ADR-PU-009 / ADR-PU-015） |
| B | マーケットプレイス更新（`target=current-project` ではスキップ） |
| C | User スコープのプラグイン更新（`target=current-project` ではスキップ） |
| D | Project スコープのプラグイン更新（`target=all` では全プロジェクトを順次処理） |
| E | Local スコープのプラグイン更新（`target=all` では全プロジェクトを順次処理） |
| F | 結果報告（サマリ + マーケットプレイス詳細 + スコープ別詳細） |
| G | 失敗対応の確認 + 限定リトライ + 再描画 |

## 重要原則

各原則の根拠 ADR は [`references/architecture-decisions.md`](references/architecture-decisions.md) を参照。

| 原則 | 根拠 ADR |
|-----|---------|
| 公式 CLI 経由（`git fetch` / `git reset` 等の低レベル操作禁止） | ADR-PU-002 |
| Phase A-0〜G 固定順序 + スコープ個別更新 + 継続実行 | ADR-PU-003 |
| 横断ルール SSOT 配置（cross-cutting-rules.md） | ADR-PU-004 |
| exit code 一次判定 + Unknown 区分（Missing はリトライ対象外） | ADR-PU-005 |
| サーキットブレーカー（MP 単位累計 3 件以上の Failed で配下 Skip。集計対象・Phase B 例外は ADR-PU-006 が SSOT） | ADR-PU-006 |
| 失敗対応の対話モデル（Failed のみリトライ・5 件閾値で個別判断除外） | ADR-PU-007 |
| Skipped 全区分はリトライ対象外（A-3 由来 Skipped 含む） | ADR-PU-009 |
| コマンドとスキルの責務分離（トリガー / 実作業） | ADR-PU-008 |
| `installed_plugins.json` をスコープ判定 SSOT に採用（Phase A-3 で projectPath を使用） | ADR-PU-009 |
| 全プロジェクト更新（`target=all` で全 `projectPath` を対象化、`target=current-project` で現在のプロジェクトのみ） | ADR-PU-015 |

## 出力契約

呼び出し元コマンドへ返す結果:

- Phase F の結果報告（サマリ + 詳細テーブル + 次のアクション）
- 失敗時は Phase G の対話結果を含めた最終サマリ

詳細な出力フォーマットは [`references/output-formats.md`](references/output-formats.md) を参照。
