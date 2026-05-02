---
name: skill-router
description: skill-router の `<base>/index.json` / disabled / ログを操作・診断するスキル。「router の状態確認」「インデックス再構築」「skill-router を停止」等の依頼で起動し、`/router-rebuild` `/router-status` `/router-toggle` の使い分けと配置場所を説明する。Use when operating skill-router. SKIP when editing routing logic (use hook-toolkit or edit route.py).
allowed-tools: Read, Grep, Glob, Bash
---

# skill-router

Claude Code に有効化されたスキルを `UserPromptSubmit` フックで自動推奨し、スキル起動率を高めるルーティングプラグインの **操作・診断ガイド** スキル。

ルーティング本体（インデックス生成・スコア計算・additionalContext 注入）はフックと Python スクリプトが担うため、本スキルは利用者向けの操作支援とテスト用 evals 保持を担当する。

## 責務

- `/router-rebuild` / `/router-status` / `/router-toggle` 各コマンドの使い分けを案内する
- ルーティングが期待どおり動作しないときの診断手順（`<base>/index.log` / `route.log` / `error.log` の確認）を案内する
- `<base>/index.json` / `inverted_index.json` / `route_decisions.jsonl` を Read で要約してユーザに状態を共有する
- 動作分岐検証用の evals（`evals/case-XX_*.md`）を保持し、parse_evals.py のゴールデンソースとして機能する

## 責務外（他スキルが担当）

| 業務 | 担当 |
|-----|-----|
| スコア計算ロジックの改修 | `references/scripts/lib/route.py` を直接編集 |
| インデックス生成ロジックの改修 | `references/scripts/lib/build_index.py` を直接編集 |
| フック設定の変更 | `extension-toolkit:hook-toolkit` |
| 新スキル追加時のインデックス更新 | 何もしない（次の `SessionStart` で自動再構築） |
| 公開・PR 作成 | `extension-toolkit:marketplace-publisher` |

## トリガー条件

- 「skill-router の状態を見たい」「ルータの統計が知りたい」
- 「インデックスを再構築して」「router-rebuild したい」
- 「skill-router を一時停止」「ルーティングを切って」
- 「ルータのログを確認したい」「どのスキルが推奨されたか見たい」

## 前提

呼び出し時に以下が満たされていること（不足時はスキル内で案内する）。

1. Python 3.10+ が `python` または `python3` として PATH 上に存在する
2. プラグインが有効化されている（`~/.claude/settings.json` の `enabledPlugins` に登録）
3. 一度でも `SessionStart` フックが発火したか、`/router-rebuild` を手動実行済み（`<base>/index.json` が存在する）

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| 操作意図が明確（rebuild / status / toggle のいずれか） | 直接実行 | 該当コマンドを案内、または Bash で実行 |
| 症状ベースの依頼（「推奨が出ない」等） | 診断 | `<base>` 配下のログ・index を Read で確認し原因を切り分け |
| 不明 | 対話 | `AskUserQuestion` で意図（操作 / 診断）を確認 |

## 実行フロー

### 操作系

1. ユーザの意図を確認（rebuild / status / toggle のいずれか）
2. 適切なコマンドを案内、または直接 Bash で実行
3. 結果（statistics / 直近の決定 / トグル状態）をユーザに要約

### 診断系

1. 症状の切り分け
   - 「推奨が出ない」→ index 存在 / config 閾値 / disabled 有無
   - 「誤推奨が多い」→ skip_keywords 設定 / config 重み / 候補絞込結果
   - 「セッション開始が遅い」→ build_index ログ・スキル数・逆引き索引サイズ
2. 該当する base ディレクトリを特定（下節「base ディレクトリ」参照）
3. `index.log` / `route.log` / `error.log` を Read で確認

## base ディレクトリの解決順位

| 優先 | パス | 備考 |
|-----|------|------|
| 1 | `${CLAUDE_PLUGIN_DATA}` | Claude Code が提供する場合のみ |
| 2 | `<repo-root>/.claude/.local/plugins/skill-router/` | 現在地から `.git` を上方探索（`$HOME` を超えない） |
| 3 | `~/.claude/.local/plugins/skill-router/` | フォールバック |

## 主要ファイル

| ファイル | 役割 |
|---------|------|
| `<base>/config.json` | 重み・閾値の外部化 |
| `<base>/index.json` + `index.pkl` | インデックス本体 |
| `<base>/inverted_index.json` | 逆引き索引 |
| `<base>/disabled` | トグル無効化フラグ |
| `<base>/sessions/<id>/prompts.jsonl` | プロンプト履歴 |
| `<base>/sessions/<id>/route_decisions.jsonl` | ルーティング決定履歴 |

## 関連スキル / コマンド

| 種別 | 名前 | 用途 |
|-----|------|------|
| コマンド | `/router-rebuild` | index 手動再構築 |
| コマンド | `/router-status` | 統計・直近決定・スコア分布表示（`--clean` で 30 日超セッション削除） |
| コマンド | `/router-toggle` | `on` / `off` 切り替え |

## evals

`evals/case-01_rebuild.md` 〜 `evals/case-04_skip_negative.md` の 4 ケースで、コマンド誘導とルーティング判定の負例を確認できる。詳細は `evals/README.md` を参照。

## 重要な制約

- スコアリング・インデクサのロジック改修は本スキルからは行わない（`references/scripts/lib/route.py` / `build_index.py` を直接編集する）
- `session_id` 解決の最終フォールバックは `sha256(host + cwd + sec + pid)` で衝突確率は実用上 0
- フェイルオープン原則のため、エラー時も `exit 0` で透過する
- `<base>/disabled` フラグは 3 段階の優先順位で参照されるため、再有効化時は全層で削除を試みる必要がある

## 参照

| 用途 | パス |
|-----|------|
| ルーティング本体 | `${CLAUDE_PLUGIN_ROOT}/references/scripts/lib/route.py` |
| インデクサ | `${CLAUDE_PLUGIN_ROOT}/references/scripts/lib/build_index.py` |
| evals パーサ | `${CLAUDE_PLUGIN_ROOT}/references/scripts/lib/parse_evals.py` |
| セッション状態 | `${CLAUDE_PLUGIN_ROOT}/references/scripts/lib/session_state.py` |
| spike 一覧 | `${CLAUDE_PLUGIN_ROOT}/references/spike/` |
| 設定既定値 | `${CLAUDE_PLUGIN_ROOT}/references/templates/config.default.json` |
