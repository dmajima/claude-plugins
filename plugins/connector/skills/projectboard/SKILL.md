---
name: projectboard
description: HUE ProjectBoard の WBS タスク読み書き・スケジュールシート構造解析（クリティカルパス含む）を行うスキル。「ProjectBoard のタスクを取得」「WBS を CSV で」「タスクを追加」「クリティカルパスを分析」等で起動。書き込み前に承認必須。Use when operating HUE ProjectBoard WBS tasks or schedule sheets. SKIP when target is Backlog (use backlog) or Azure DevOps (use azure).
---

# ProjectBoard

HUE ProjectBoard（Works Applications のプロジェクト管理 SaaS）の WBS タスクを Cookie セッション +
REST API で操作するスキル。読み取り（タスク取得・CSV 化）、スケジュールシート全体の構造解析
（クリティカルパス含む）、書き込み（タスク追加・更新）に対応する。書き込みはユーザー承認を必ず経由する。

## 責務

- タスク（WBS ノード）の読み取り: シート特定 → タスクツリー取得 → 特定タスク抽出 / CSV 整形（読み取り系）
- スケジュールシート全体の構造解析: WBS ツリー・依存関係・クリティカルパス（CPM）・サマリのレポート生成（読み取り系）
- タスクの追加（addNode）・更新（updateNodeContent: タイトル・ステータス・日付・担当者・進捗・先行タスク等）（書き込み系）
- urlKey ⇔ UUID 変換・Cookie セッション管理・XSRF 処理

## 責務外（他スキルが担当）

| 業務 | 担当スキル |
|-----|----------|
| Backlog の課題操作 | `backlog` |
| Azure DevOps（PR / 作業項目）の操作 | `azure` |
| 認証情報の保存・管理 | credentials-manager プラグイン |

## トリガー条件

- 「ProjectBoard のタスクを取得して」「HUE ProjectBoard の WBS を CSV にして」
- 「このシートのスケジュール構造を解析して」「クリティカルパスを出して」
- 「ProjectBoard にタスクを追加して」「SAMPLE-67 のステータスを実行中にして」
- `*.pm.apps.worksap.com/wbs/project/...` 形式の URL が共有された場合
- 他プラグインから Skill ツール経由で「読み取りのみ」と明示された呼び出しを受けた場合（書き込みには進まない）

このスキルを起動しないケース:

- Backlog / Azure DevOps の操作（→ `backlog` / `azure`）

## 前提

呼び出し前に以下が確認できること（不足時は対話で確認）:

1. 対象の指定 — 次のいずれか（[references/procedures.md](references/procedures.md) セクション 1.1）:
   - A. シート URL（`https://{tenant}.pm.apps.worksap.com/wbs/project/{urlKey}/issue/{sheetCode}`）
   - B. tenant + projectId(UUID) + シート名 / sheetCode（任意）
2. `~/.claude/credentials.json` に `hue-projectboard` エントリが存在し、対象テナントのホストが
   `domains` に合致する（[../../references/credentials-precheck.md](../../references/credentials-precheck.md)）

## 実行フロー

### 1. 認証事前確認

- 参照: [../../references/credentials-precheck.md](../../references/credentials-precheck.md)
- 対象テナントのホスト `{tenant}.pm.apps.worksap.com` を確定し、credentials.json の
  `hue-projectboard` エントリの `domains` と照合する（username / value が非空であること）
- 確認できない場合は **API を呼ばずに** ユーザーへ準備を依頼して停止する

### 2. 入力解決・セッション確立

- 参照: [references/procedures.md](references/procedures.md) セクション 0〜1
- セッション作業領域（`$WORK_DIR`）を確保し、venv を構築する（[references/setup.md](references/setup.md)）
- URL 入力なら tenant / urlKey / sheetCode を抽出し、`scripts/resolve/urlkey.py` で UUID に変換する
- credentials-manager 経由で認証値を取得し、`PB_TENANT` / `PB_EMAIL` / `PB_PASSWORD` 環境変数として
  `scripts/auth/login.sh` を実行する（値を会話・ログに出さない）

### 3. 操作種別判定

| 種別 | 操作 | 後続 |
|-----|------|------|
| 読み取り | タスク取得 / 特定タスク参照 / CSV 化 / シート全体の構造解析・クリティカルパス | Step 4 |
| 書き込み | タスク追加 / タスク更新（ステータス・日付・担当者・先行タスク等） | Step 5 |

### 4. 読み取り系の実行

- 参照: [references/procedures.md](references/procedures.md) セクション 2〜3
- シート特定: `list_sheets.sh` の結果から ISSUE シートを絞り込み、sheetCode 突合 / シート名一致で
  一意特定する。特定できない場合は AskUserQuestion で候補を提示して選択してもらう
- `get_tasks.sh`（wbsId = sourceId）でタスクツリーを取得し、要求に応じて整形する:
  - 特定タスク参照: jq で抽出して要点を報告
  - 一覧 CSV: `tasks_to_csv.py`（standard / all モード）
  - シート全体の構造解析: `analyze_schedule.py`（ツリー・依存・クリティカルパス・警告のレポート）
- 結果は要点を整形して報告する（タスク数・期間・クリティカルパス等）

### 5. 書き込み系の実行

- 参照: [references/api-write.md](references/api-write.md) / [references/procedures.md](references/procedures.md) セクション 4
1. **現状取得**: 対象シートを `get_tasks.sh` で再取得し、対象ノード id・親ノード・既存値を確定する
2. **ID 解決**: ステータス名は `sheet_detail.sh` の statusSet で id に解決する。先行タスクの変更は
   既存 predecessor とマージする。曖昧な場合は候補を提示して確認
3. **機密チェック**: title / description に認証情報らしき文字列（トークン・パスワード・秘密鍵パターン）が
   含まれる場合は指摘し、ユーザーが意図を確認するまで進まない
4. **承認**: 対象（テナント / シート / タスク）・操作種別・変更内容（更新は変更前 → 変更後）を提示し、
   `AskUserQuestion` で承認を得る
5. **実行**: jq でボディを構築し、`stomp_session.py`（WebSocket+STOMP 接続を保持）経由で
   `post_node_api.sh` を実行する。書き込みは connectionId が生きた WebSocket 接続であることが必須
   （[references/api-write.md](references/api-write.md) セクション 1.2）。XSRF・401/403 リトライ・
   operationId 生成は実装済み。タスク追加は先頭 preSiblingId=null・1 件ずつ
6. **結果検証（必須）**: レスポンスのエラーコード（`00000099`/`01010401`）有無と `wbsVersion` 増加を確認し、
   シート再取得で反映を確認する。原因切り分けは [references/api-write.md](references/api-write.md) セクション 8

### 6. 後始末・引き渡し

- `cleanup_sensitive.sh` で cookies.txt・取得 JSON を削除する（成果物は事前にセッションフォルダ直下へ移動）
- 操作結果（取得内容 / 解析レポート / 追加・更新したタスク）を報告し、続けて関連操作が必要かを確認する

## 重要な制約

- [../../references/safe-api-access.md](../../references/safe-api-access.md) の安全原則（ホワイトリスト・
  シークレット取り扱い・エラー分岐・書き込みゲート）に必ず従う
- **ユーザー未承認での書き込み禁止**（非対話モードでも承認は省略しない）
- 依頼された操作のみ実行する（依頼外のタスクへの書き込み・一括変更をしない。複数タスクの一括更新は
  ユーザーの明示指示 + 対象一覧の承認がある場合のみ）
- パスワード・Cookie 値・XSRF トークンを会話出力・ログに出さない。パスワードはコマンドライン引数に乗せず
  環境変数で渡す
- `domains` 照合に合致しないテナントへアクセスしない（credentials.json の `hue-projectboard` エントリ準拠）
- 書き込みは必ず `stomp_session.py`（WebSocket+STOMP 接続）経由で行う（connectionId の接続検証のため）
- 書き込み後の反映確認を省略しない（[references/api-write.md](references/api-write.md) セクション 7）
- 操作完了後の機密後始末（cleanup_sensitive.sh）を省略しない
- 残存リスクの認識: `PB_PASSWORD` は 401 自動再ログインのため子プロセス環境に継承される（プロセス環境の
  可視性）。また解析レポート（pb_*.md）は個人名・スケジュールを含むため成果物の共有範囲に注意する

## サブエージェント呼び出し（他プラグイン向け）

他プラグインが read 操作を **後続フローのある文脈で** 呼び出す場合は、`Skill()` ではなく `Agent()` を使用すること。`Skill()` では本スキルの結果報告後に呼び出し元のフローが停止する。

詳細なプロトコル・テンプレート・パラメータは [../../references/subagent-protocol.md](../../references/subagent-protocol.md) セクション 5.7 を参照。

| 操作 | 出力ファイル |
|------|-------------|
| WBS 情報取得 | `wbs.json` |
| シート情報取得 | `sheet.json` |

## 参照

| 用途 | ファイル |
|-----|---------|
| 実行手順（フロー別コマンド例） | [references/procedures.md](references/procedures.md) |
| 環境構築（venv・後始末） | [references/setup.md](references/setup.md) |
| 読み取り API 仕様（SSOT） | [references/api-spec.md](references/api-spec.md) |
| 書き込み API 仕様（SSOT・確証度付き） | [references/api-write.md](references/api-write.md) |
| 既知の落とし穴 | [references/pitfalls.md](references/pitfalls.md) |
| 認証事前確認 | [../../references/credentials-precheck.md](../../references/credentials-precheck.md) |
| API アクセス安全原則 | [../../references/safe-api-access.md](../../references/safe-api-access.md) |
| サブエージェント呼び出しプロトコル（SSOT） | [../../references/subagent-protocol.md](../../references/subagent-protocol.md) |
| 動作例 | [evals/](evals/) |
