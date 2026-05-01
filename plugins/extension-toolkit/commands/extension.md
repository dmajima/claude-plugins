---
description: Claude Code 拡張要素（スキル/プラグイン/コマンド/エージェント/フック）の作成・レビュー・公開を統括
argument-hint: <種別> <対象名> [--non-interactive] [--full-auto]
---

`extension-toolkit` プラグインの各スキルを使ってユーザの拡張要素作成・公開要求を処理してください。

ユーザの引数: $ARGUMENTS

## 動作モード判定

| 引数 | モード | 動作 |
|-----|-------|------|
| 空 | 対話 | 何を作成・公開・レビューしたいかをユーザに確認 |
| `<種別> <名前>` 形式 | 自動ルーティング | 対応するスキルへバトンを渡す |
| `--non-interactive` 含む | 非対話 | 引数値で確定し進行 |

## ルーティング

| 引数パターン | 起動スキル | 説明 |
|------------|----------|------|
| `skill <name>` または `skill ...` | `skill-toolkit` | スキル新規作成・改修 |
| `plugin <name>` または `plugin ...` | `plugin-toolkit` | プラグイン新規作成・移管・追加 |
| `command <name>` または `command ...` | `command-toolkit` | スラッシュコマンド作成・改修 |
| `agent <name>` または `agent ...` | `agent-toolkit` | サブエージェント単体作成 |
| `team <name>` または `team ...` | `agent-toolkit`（チームモード） | エージェントチーム編成 |
| `hook <event>` または `hook ...` | `hook-toolkit` | フック設定作成 |
| `readme <target>` または `readme ...` | `readme-toolkit` | README 生成・更新 |
| `setup <work-dir>` または `setup ...` | `environment-setup-toolkit` | Python venv 構築・撤去 |
| `marketplace <name>` または `marketplace ...` | `marketplace-toolkit` | マーケットプレイス新規構築・本体管理 |
| `review <target>` または `review ...` | `extension-reviewer` | 多角レビュー実施 |
| `publish <plugin>` または `publish ...` | `marketplace-publisher` | プラグイン公開ワークフロー |

## 引数が空の場合

ユーザに以下を確認してから進めてください:

- 対象（何を作りたいか / 何を公開したいか）
- 種別（スキル / プラグイン / コマンド / エージェント / チーム / フック / レビュー / 公開）
- 配置先（既存プラグイン内 / スタンドアロン / グローバル）

選択に応じて該当スキルへバトンを渡してください。

## 配置先未確定の場合（公開意図あり）

「○○を公開したい」のような **配置先未確定** な要望には:

1. 既存マーケットプレイスのプラグインを `.claude-plugin/marketplace.json` から確認
2. 重複チェックを `marketplace-publisher` で実施
3. 結果に応じて以下のいずれかを案内
   - 既存プラグインへの追加 → `plugin-toolkit`（追加シナリオ）
   - 新規プラグイン作成 → `plugin-toolkit` + 各 `*-toolkit`
   - 既存スキルへの統合 → 該当 `*-toolkit`（更新シナリオ）

## ユーザ選択の UI

何らかの選択をユーザに求める場合は `AskUserQuestion`（Claude UI）を原則として使用する。詳細は `references/user-interaction.md` を参照。

## 破壊的フラグの段階的ゲート（必須）

引数に以下の破壊的フラグが含まれる場合、対象スキルへ転送する **前に** オーケストレータ段階で `AskUserQuestion` による意思確認を必ず行うこと:

| 検出パターン | 対応 |
|-----------|------|
| `--remove` / `--remove-plugin` / `--also-delete-files` | 削除対象・範囲を提示し「実行する / キャンセル」を確認 |
| `--full-auto` | 「完全自動実行（git push / PR 作成）してよいか / ハンドオフに切り替えるか」を確認 |
| `--confirm-destructive` 単独（他フラグなし）| エラーで返却（用途不明な場合の事故防止）|
| 上記の複合（例: `--remove-plugin X --also-delete-files --confirm-destructive`）| 影響範囲を全て提示した上で **二重確認**（意図確認＋最終確認）|

これらは利用者が誤ってコピペ実行することを防ぐためのオーケストレータ段階の安全装置。対象スキル側にも同等のゲートがあるが、`/extension` 段階で先に確認することで一段早く事故を止める。詳細は `references/review-freshness.md` の安全装置原則と整合。

### 検出方式（誤判定防止）

引数を **空白で分割し、トークンごとに完全一致** で判定する（部分一致禁止）:

| 入力例 | `--full-auto` 検出 | `--remove` 検出 | 備考 |
|--------|------------------|----------------|------|
| `--full-auto` | YES | NO | 完全一致 |
| `--full-auto-mode` | NO | NO | 別フラグとして扱う |
| `--remove` | NO | YES | 完全一致 |
| `--remove-plugin foo` | NO | NO | `--remove-plugin` は別の完全一致対象として独立判定 |
| `--remove-cache` | NO | NO | 別フラグとして扱う |

判定すべきフラグの完全一致リスト: `--remove`, `--remove-plugin`, `--also-delete-files`, `--full-auto`, `--confirm-destructive`

## 共通の終了処理

| 動作した最後のスキル | 提示者 | 提示内容 |
|--------------------|-------|---------|
| `marketplace-publisher`（公開フロー実行時） | `marketplace-publisher` | 変更ファイル一覧 / marketplace.json 差分 / 推奨コミットメッセージ / 次のコマンド |
| 上記以外（作成・改修系のみ） | 直前のスキル | 生成・変更ファイル一覧 / 後続スキル接続案内（`extension-reviewer` / `marketplace-publisher` 等） |

`git commit` 以降の操作はこのコマンドからは実行しません。フルオート公開を希望する場合は `marketplace-publisher` のフルオートモードを直接利用してください。

## 関連スキル一覧

| スキル | 主な責務 |
|-------|--------|
| `skill-toolkit` | スキル本体作成・改修 |
| `plugin-toolkit` | プラグイン外形作成・既存資産移管 |
| `command-toolkit` | スラッシュコマンド作成・改修 |
| `agent-toolkit` | エージェント・チーム作成 |
| `hook-toolkit` | フック設定作成 |
| `readme-toolkit` | README 生成・更新 |
| `environment-setup-toolkit` | Python venv 構築・撤去 |
| `marketplace-toolkit` | マーケットプレイス新規構築・本体管理 |
| `extension-reviewer` | 多角レビュー（チーム起動） |
| `marketplace-publisher` | プラグイン公開ワークフロー（git push / PR） |
