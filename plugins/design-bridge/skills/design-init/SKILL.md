---
name: design-init
description: design-bridge をリポジトリへ導入するスキル（specs/ mocks/ 構成の作成・.claude/design-bridge.json 生成・claude.ai/design プロジェクトとの紐付け・スクショ用 venv 構築）。「design-bridge を導入して」「画面設計書とデザインを連動させたい」等の依頼で起動する。Use when setting up design-bridge in a repo. SKIP when 反映（design-push）、取り込み（design-pull）、状態確認（design-status）。
---

# design-init

リポジトリに design-bridge を導入し、Markdown 画面設計書・モック HTML・claude.ai/design の 3 者を連動させる土台を作る。

## 責務

- 画面設計書・モック・スクリーンショットのディレクトリ構成を作成する
- claude.ai/design の design-system プロジェクトを選択または新規作成し、紐付けを記録する
- プロジェクト設定 `.claude/design-bridge.json` を生成する
- `.gitignore` に `.claude/.local/` が登録されていることを確認する
- スクリーンショット生成用の venv を構築する

## 責務外（他スキルが担当）

| 業務 | 担当スキル |
|-----|----------|
| 画面モック HTML の生成 | `design-mock` |
| claude.ai/design への反映 | `design-push` |
| claude.ai/design からの取り込み | `design-pull` |
| 未反映・ドリフトの確認 | `design-status` |

## トリガー条件

- 「design-bridge を導入して」「デザイン同期をセットアップして」
- 「画面設計書と Claude Design を連動させたい」
- 「このリポジトリで画面モックを管理したい」

このスキルを起動しないケース:

- 既に導入済みで反映したいだけ（→ `design-push`）
- 導入済みで状態を見たいだけ（→ `design-status`）

## 前提

1. 対象が git リポジトリであること（`.git` がプロジェクトルート判定に必要）
2. Python 3.9 以上が利用可能であること（スクリーンショット生成に使用）
3. `/design-login` で claude.ai の design-system 認可が済んでいること

`jq` は任意依存。無い場合もフックは動作するが、`watch` 設定が読めず既定の監視対象（`specs` 配下の `.md`、`mocks` 配下の `.html`）に縮退する。既定以外の構成にする場合は `jq` が必要。

## 実行モード判定

| 入力 | モード | 動作 |
|-----|-------|------|
| `--non-interactive` フラグあり / 引数で projectId まで指定 | 非対話 | 既定値で確定し進行 |
| 上記以外 | 対話 | 対象プロジェクト・ディレクトリ構成を確認 |

## 実行フロー

### 1. 前提チェック

- プロジェクトルート（`.git` のあるディレクトリ）を特定する
- Python 3.9 以上の有無を確認する
- `jq` の有無を確認する。無い場合は「既定以外の `watch` 設定が効かない」旨を伝える（導入自体は続行してよい）
- 既に `.claude/design-bridge.json` があれば **更新モード**として扱い、上書き前に差分を提示する

### 2. Claude Design プロジェクトの決定

`DesignSync` の `list_projects` で書き込み可能な design-system プロジェクトを一覧する。

| 状況 | 動作 |
|-----|------|
| 候補が 1 件 | そのプロジェクトで良いか `AskUserQuestion` で確認 |
| 候補が複数 | `AskUserQuestion` で選択させる（「新規作成」も選択肢に含める） |
| 候補が 0 件 | 新規作成するか確認し、`create_project` でプロジェクト名を指定して作成 |

`list_projects` が認可エラーを返した場合は `/design-login` の実行をユーザーに依頼し、このスキルを中断する。

選択後、`get_project` で `type` が design-system であることを必ず確認する。通常プロジェクトへは push できない（型は作成時に固定され後から変更できない）。型が違う場合は選び直す。

### 3. ディレクトリ構成の作成

既定の構成を作成する。既存ディレクトリがある場合はそれを流用し、作り直さない。

```text
specs/screens/     画面設計書（Markdown・正本）
specs/assets/      スクリーンショット（design-push が自動生成）
mocks/             モック HTML（正本）
```

`mocks/_tokens.html`（トンマナ）と `mocks/_layout.html`（基礎レイアウト）が未作成の場合は、雛形を作るか `design-mock` に任せるかをユーザーに確認する。

### 4. 設定ファイルの生成

`.claude/design-bridge.json` を生成する。全フィールドの意味は [references/config-schema.md](references/config-schema.md) を参照。

```json
{
  "projectId": "<design-system プロジェクトの UUID>",
  "projectName": "<表示名>",
  "specsDir": "specs/screens",
  "assetsDir": "specs/assets",
  "mocksDir": "mocks",
  "watch": [
    { "dir": "specs", "ext": "md", "kind": "spec" },
    { "dir": "mocks", "ext": "html", "kind": "mock" }
  ],
  "viewport": { "width": 1280, "height": 800 }
}
```

このファイルはコミット対象とする（チームで共有する紐付け情報のため）。

ブロックの強さ（連続通知の上限）はこのファイルには書かない。リポジトリ同梱の設定から挙動を変えられないようにしているため、調整が必要な場合はユーザースコープ設定（`~/.claude/.local/plugins/design-bridge/user-config.json`）で行う。

### 5. .gitignore の確認

`.gitignore` に `.claude/.local/` が含まれていることを確認する。無い場合は追記の可否をユーザーに確認してから追記する。未反映リスト・バンドル・venv がコミットされることを防ぐため必須。

### 6. venv の構築

スクリーンショット生成に Playwright を使う。プラグイン同梱スクリプトで構築する。

```bash
bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/setup_venv.sh" \
  --project-root "<プロジェクトルート>"
```

venv は `.claude/.local/plugins/design-bridge/.venv` に永続構築される。Chromium のダウンロード（展開後 約 690 MB）が初回に発生するため、所要時間をユーザーへ事前に伝える。すぐに構築しない場合は `--skip-browser` で Python 依存のみ入れ、後から `python -m playwright install chromium` を実行する案内を残す。

### 7. 導入完了の報告

以下を提示する。

- 作成したディレクトリ・設定ファイル
- 紐付けた Claude Design プロジェクト名と ID
- venv の場所と Chromium 導入の有無
- フックが有効になる条件（Claude Code の再起動が必要）
- 次のアクション（`design-mock` でモック生成、`design-push` で反映）

## 重要な制約

- 既存の `specs/` `mocks/` の中身を書き換えない（構成の作成のみ）
- `.claude/design-bridge.json` を無確認で上書きしない
- `projectId` に design-system 型でないプロジェクトを設定しない
- 認可エラー時に `/design-login` を代行実行しようとしない（ユーザー操作が必要）
- ブロック挙動を変える値を `.claude/design-bridge.json` に書かない

## 参照

| 用途 | ファイル |
|-----|---------|
| 設定ファイルのスキーマ | [references/config-schema.md](references/config-schema.md) |
| venv 構築 | `${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/setup_venv.sh` |
| 依存パッケージ | `${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/requirements.txt` |
