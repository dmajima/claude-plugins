# design-init

リポジトリに design-bridge を導入し、Markdown の画面設計書・モック HTML・claude.ai/design の 3 者を連動させる土台を作るスキル。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。スキル動作の本体は `SKILL.md` および `references/` 配下を参照してください。

## 責務（要約）

- 画面設計書・スクリーンショット・モックのディレクトリ構成を作成する
- claude.ai/design の design-system プロジェクトを選択または新規作成し、紐付けを記録する
- プロジェクト設定 `.claude/design-bridge.json` を生成する
- `.gitignore` に `.claude/.local/` が登録されていることを確認する
- スクリーンショット生成用の venv を構築する

導入だけを担当します。モック生成は `design-mock`、反映は `design-push`、取り込みは `design-pull`、状態確認は `design-status` の責務です。

## なぜ導入作業が必要なのか

design-bridge は「正本は常にローカル（`specs/` と `mocks/`）、claude.ai/design は表示・承認用の鏡」という方針で動きます。この方針を運用ルールではなく機構で担保するために、最初に次の 3 つを確定させる必要があります。

| 確定させるもの | 理由 |
|--------------|------|
| 正本の置き場（`specs/` と `mocks/`） | どのファイルが正本かが決まらないと、何を反映すべきかを機械的に判定できない |
| push 先の design-system プロジェクト ID | 反映先を毎回聞き直さずに済ませ、チーム全員が同じカード群を見るため |
| `.claude/design-bridge.json` の存在そのもの | PostToolUse / Stop フックは、このファイルの有無を「design-bridge 導入済み」の判定条件として使う |

`DesignSync` にはリモート変更の通知機構（watch）がないため、claude.ai/design 側の変更をセッション中に検知することは原理的にできません。そのため design-bridge は「push は Stop フックで強制し、pull は明示指示のときだけ全件照合する」という非対称な形を取っています。`design-init` は、この非対称さが成立する前提（正本の置き場・紐付け・フックの判定材料）を一度だけ用意するスキルです。

## 使い方

### 前提

1. 対象が git リポジトリであること（`.git` をプロジェクトルート判定に使う）
2. `jq` が利用可能であること（フックが設定を読むために使用）
3. `/design-login` で claude.ai の design-system 認可が済んでいること
4. Python 3.10 以上が利用可能であること（スクリーンショット生成に使用）

前提が欠けている場合は、スキルが不足している項目を提示してから進めます。`/design-login` はユーザ操作が必要なため、スキルが代行実行することはありません。

### トリガーフレーズ例

- 「このリポジトリに design-bridge を導入して」
- 「デザイン同期をセットアップして」
- 「画面設計書と Claude Design を連動させたい」
- 「このリポジトリで画面モックを管理したい」
- `/design-init`（確認を挟まず既定値で進める場合は `/design-init --non-interactive`）

### 入力 → 出力の流れ

1. プロジェクトルート・`jq` の有無・既存の `.claude/design-bridge.json` を確認する（既存があれば更新モード）
2. `DesignSync` の `list_projects` で書き込み可能な design-system プロジェクトを一覧し、対象を決める（候補が無ければ新規作成を確認）
3. `specs/screens` `specs/assets` `mocks` を作成する（既存ディレクトリは流用し、中身は書き換えない）
4. `.claude/design-bridge.json` を生成する
5. `.gitignore` に `.claude/.local/` があることを確認する（無ければ追記の可否を確認）
6. スクリーンショット生成用の venv を構築する
7. 作成物・紐付け先・次のアクションを報告する

## 動作例

入力:

```text
/design-init
```

出力（対象リポジトリ側）:

```text
<repo>/
├─ specs/screens/              # 画面設計書（Markdown・正本）
├─ specs/assets/               # スクリーンショット（design-push が自動生成）
├─ mocks/                      # モック HTML（正本）
└─ .claude/design-bridge.json  # claude.ai/design プロジェクトとの紐付け
```

報告には次が含まれます。

- 作成したディレクトリ・設定ファイル
- 紐付けた Claude Design プロジェクト名と ID
- フックが有効になる条件（Claude Code の再起動が必要）
- 次のアクション（`design-mock` でモック生成、`design-push` で反映）

## 生成される設定ファイル

`.claude/design-bridge.json` は **コミット対象** です（チームで共有する紐付け情報のため）。

```json
{
  "projectId": "<design-system プロジェクトの UUID>",
  "projectName": "<表示名>",
  "specsDir": "specs/screens",
  "assetsDir": "specs/assets",
  "mocksDir": "mocks",
  "watch": [
    { "dir": "specs", "ext": "md" },
    { "dir": "mocks", "ext": "html" }
  ],
  "blockLimit": 3,
  "viewport": { "width": 1280, "height": 800 }
}
```

各フィールドの意味・既定値・フックが読むフィールドは [`references/config-schema.md`](references/config-schema.md) を参照してください。

一方、未反映リスト（`pending.txt`）・連続ブロック回数・push 用バンドルは `.claude/.local/plugins/design-bridge/` 配下に置かれる **コミット対象外** の状態ファイルです。これらが誤ってコミットされないよう、`.gitignore` の `.claude/.local/` 登録を必須チェック項目にしています。

## カスタマイズ・拡張

| 変更したいこと | 変更箇所 |
|--------------|---------|
| 設定ファイルの項目・既定値・判定ルール | [`references/config-schema.md`](references/config-schema.md) |
| ディレクトリ構成（`specsDir` / `assetsDir` / `mocksDir`） | 生成後の `.claude/design-bridge.json` を編集 |
| フックの監視対象・連続ブロック上限 | `.claude/design-bridge.json` の `watch` / `blockLimit` |
| スクリーンショットのビューポート | `.claude/design-bridge.json` の `viewport` |
| スクリーンショット生成の依存パッケージ | `${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/requirements.txt` |

## 注意事項

- 既存の `specs/` `mocks/` の中身は書き換えません（構成の作成のみ）
- `.claude/design-bridge.json` が既にある場合は更新モードとなり、差分を提示してから上書き可否を確認します
- `projectId` には design-system 型のプロジェクトのみを設定します。型は作成時に固定され、後から変更できません
- venv 構築後、`playwright install chromium` によるブラウザバイナリ取得が別途必要です
- フックは Claude Code の再起動後に有効になります
- 社内マーケットプレイス `customerep-claudecode` の `prod-asset-import` プラグインにある `design-sync` スキルは、本番サーバーからフロントリソースを取り込む別物です。名前が似ていますが本スキルとは無関係です

## 関連スキル

| スキル | 関係 |
|-------|------|
| `design-mock` | 導入後、設計書から画面モック HTML を生成する |
| `design-push` | 導入後、スクショ再生成から claude.ai/design への反映までを行う |
| `design-pull` | 明示指示時のみ、claude.ai/design の内容をローカルへ取り込む |
| `design-status` | 未反映・ドリフトの状況を確認する |

## ファイル構成

```text
skills/design-init/
├── SKILL.md                      # スキル定義（Claude が実行時に読み込む）
├── README.md                     # 本ファイル（人間向け）
├── references/
│   └── config-schema.md          # design-bridge.json のスキーマ
└── evals/
    ├── README.md
    └── case-*.md                 # 動作分岐の期待挙動
```
