---
name: marketplace-publisher
description: Claude Code プラグインマーケットプレイスの marketplace.json を更新し、新規プラグインの登録・既存プラグインの更新・重複/マージ判定・公開ワークフロー（ハンドオフ or フルオート）を支援するスキル。「foo プラグインを公開」「マーケットプレイスに登録」「marketplace.json を更新」「重複チェックして」などの依頼で起動する。Use when the user wants to register or update a plugin in the marketplace, check for duplicates with existing plugins, or publish with a full automation flow. SKIP when the user wants to create plugin files (use plugin-toolkit) or migrate items (use plugin-toolkit's migration scenario).
---

# Marketplace Publisher

Claude Code プラグインマーケットプレイス（`.claude-plugin/marketplace.json`）への登録・更新・公開ワークフローを担当するスキル。新規登録時には既存プラグインとの **重複・マージ可能性チェック** を実施する。

## 責務

- `.claude-plugin/marketplace.json` の `plugins[]` 更新（追加・変更・削除）
- 既存プラグインとの **重複・マージチェック**（機能類似度・統合提案）
- 整合性検証（プラグイン実体の存在・命名衝突・JSON valid）
- 公開ワークフロー（ハンドオフ / フルオート選択）
- フルオート時の `git add` → `commit` → `push` → PR 作成

## 責務外（他スキルが担当）

| 業務 | 担当スキル |
|-----|----------|
| プラグイン本体の作成 | `plugin-toolkit` |
| スキル/コマンド/エージェント/フック本体の作成 | 各 `*-toolkit` |
| 公開前のレビュー | `extension-reviewer` |
| README 単体の生成・更新 | `readme-toolkit` |

## トリガー条件

- 「マーケットプレイスに `{plugin}` を公開」「`{plugin}` を登録」
- 「marketplace.json を更新」
- 「`{plugin}` の重複チェックして」
- 「`{plugin}` をフルオートで公開」

このスキルを起動しないケース:

- 「プラグインを作って」（→ `plugin-toolkit`）
- 「既存スキルをプラグイン化」（→ `plugin-toolkit` の移管シナリオ）

## 前提

呼び出し前に以下が決まっていること:

1. 対象プラグインが `plugins/{plugin-name}/` に実在
2. プラグイン内のアイテム配置が完了している（`plugin-toolkit` の新規/移管シナリオが完了済み + 必要に応じて `skill-toolkit` / `command-toolkit` / `agent-toolkit` / `hook-toolkit` で本体生成済み）
3. レビュー実施推奨（`extension-reviewer` で Critical/High なし状態）

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| `--non-interactive` フラグあり、ハンドオフ | 非対話・ハンドオフ | git コマンド提示まで自動 |
| `--full-auto` フラグあり | フルオート | git push + PR 作成まで自動 |
| 上記以外 | 対話 | モード選択をユーザに確認 |

## 実行フロー

### 1. 現状確認

`.claude-plugin/marketplace.json` を Read。対象プラグインの既存エントリ有無を確認。

### 2. プラグイン実体検証

| 確認項目 | 動作 |
|---------|------|
| `plugins/{plugin-name}/.claude-plugin/plugin.json` 存在 | 必須 |
| plugin.json の `name` がディレクトリ名と一致 | 必須 |
| description が plugin.json と整合 | 不一致時はユーザ確認 |
| `README.md` 存在 | 推奨 |
| シークレット混入スキャン | **必須**（[references/secret-scan.md](references/secret-scan.md) 参照、検出時 fail-closed） |

#### シークレット混入スキャン（必須）

公開対象に `.env` / 鍵ファイル / API トークン文字列が含まれていないかを `git add` 前に検査する。
ファイル名パターン（`*.env` / `*.pem` / `*.key` / `id_rsa` / `credentials.json` / `secrets.json`）と
内容パターン（AWS アクセスキー `AKIA[0-9A-Z]{16}` / GitHub トークン `ghp_[A-Za-z0-9]{36}` / Slack トークン `xox[baprs]-` 等）を検出。

検出時は **fail-closed**（公開フローを中断）し、ユーザに対象ファイルを提示して以下を選択させる:

1. 該当ファイルを削除/移動して再実行
2. `.gitignore` に追加して再実行
3. キャンセル

詳細パターンと検出ロジックは [references/secret-scan.md](references/secret-scan.md) を参照。

### 3. 重複・マージチェック（新規登録時）

詳細は [references/duplication-check.md](references/duplication-check.md) を参照。

`marketplace.json` の既存 `plugins[]` 配列をスキャンし、以下の類似度を評価:

| 観点 | 判定基準 |
|-----|---------|
| 名前類似 | レーベンシュタイン距離 < 3 or 部分文字列一致 |
| description 類似 | 主要キーワードの重複 |
| 機能領域類似 | 各プラグインの提供スキル/コマンドを比較 |

類似プラグイン検出時はユーザに以下を提示:

```text
類似プラグインを検出しました:

- `{existing-plugin}` — {description}
  類似ポイント: {具体}

選択肢:
1. 既存プラグインへのマージ（新プラグインの中身を既存に追加、`plugin-toolkit` の追加シナリオへ）
2. 新規登録を続行（差別化点を明記）
3. キャンセル

どうしますか？
```

### 4. marketplace.json の更新

詳細は [references/marketplace-json.md](references/marketplace-json.md) を参照。

| シナリオ | 動作 |
|---------|------|
| 新規登録 | `plugins[]` にエントリ追加 |
| 既存更新 | description / source の変更を反映 |
| 削除 | ユーザ **明示的確認** 必須、エントリ削除 + ディレクトリ削除も併せて確認 |

並び順は **アルファベット順**。

### 5. 検証

- [ ] JSON valid
- [ ] エントリの `source` パスが実在
- [ ] `name` が plugin.json と一致
- [ ] バージョン情報が `marketplace.json` に書かれていない（plugin.json で管理）

### 6. 公開モードの選択

```text
marketplace.json の更新が完了しました。
公開方法を選択してください:

1. ハンドオフ（git コマンドを提示、ご自身で実行）
2. フルオート（git push → PR 作成まで自動実行）
```

#### モード A: ハンドオフ

[references/publish-workflow.md](references/publish-workflow.md) の「ハンドオフフォーマット」を参照。以下を提示して終了:

- 変更ファイル一覧
- marketplace.json の差分
- 推奨コミットメッセージ
- 次のコマンド（`git add` / `git commit` / `git push` / PR 作成）

#### モード B: フルオート

[references/publish-workflow.md](references/publish-workflow.md) の「フルオートモード」を参照。以下を順に実行:

1. ブランチ確認（main 直接 push 禁止、feature ブランチであること）
2. `git add` → `git commit`
3. `git push origin <branch>`
4. PR 作成（リモート設定に応じて GitHub / TFS 等）
5. PR URL 提示

## 重要な制約

- main / master ブランチへの直接 push 禁止（フルオートモードでもブランチ確認必須）
- 既存エントリ削除はユーザ明示確認必須
- バージョン情報は marketplace.json に書かない（plugin.json で管理）
- 重複検出時は **必ずユーザに提示**（自動マージ・自動却下しない）
- フルオート実行前に **ユーザの明示的選択** が必須
- 既存 marketplace.json のエンコーディング維持
- ユーザに選択を求める場合は `AskUserQuestion`（[`../../references/user-interaction.md`](../../references/user-interaction.md)）
- 作業完了報告前に [`../../references/completion-checklist.md`](../../references/completion-checklist.md) に基づく自己検証（ルール順守 + 要件適合 + 結果完全性）を実施

## 参照

| 用途 | ファイル |
|-----|---------|
| 命名・配置規約 | [`../../references/conventions.md`](../../references/conventions.md) |
| ポータブルパス | [`../../references/path-portability.md`](../../references/path-portability.md) |
| 検証ルール | [`../../references/validation-rules.md`](../../references/validation-rules.md)（節 1 + 2.2 実体検証） |
| marketplace.json 仕様 | [`references/marketplace-json.md`](references/marketplace-json.md) |
| 重複チェック詳細 | [`references/duplication-check.md`](references/duplication-check.md) |
| シークレットスキャン | [`references/secret-scan.md`](references/secret-scan.md) |
| 公開ワークフロー | [`references/publish-workflow.md`](references/publish-workflow.md) |
| 動作例 | [`evals/`](evals/) |
