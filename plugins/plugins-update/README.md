# plugins-update

インストール済みマーケットプレイス・プラグインを **全スコープ（User / Project / Local）で一括更新** するコマンドプラグイン。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がプラグイン動作中に参照することはありません。
コマンドの実体は `commands/update-all.md` にあります。

## 提供コマンド

| コマンド | 効果 |
|---------|-----|
| `/update-all` | 全マーケットプレイスを最新版に更新し、`/reload-plugins` を促す |
| `/update-all --dry-run` | 更新対象を表示するのみで、実際の更新は行わない |
| `/update-all --scope user` | User スコープのみ更新 |
| `/update-all --scope project` | Project スコープのみ更新 |
| `/update-all --scope local` | Local スコープのみ更新 |

## 動作概要

**マーケットプレイス → User → Project → Local の固定順** で処理し、
同一プラグインが複数スコープに存在する場合も **スコープごとに個別** に更新します。

| Phase | 処理内容 |
|-------|---------|
| A | 対象収集（`known_marketplaces.json` + 各スコープの `enabledPlugins`）|
| B | マーケットプレイス更新（Git クローンで `fetch + reset --hard origin/HEAD`）|
| C | User スコープのプラグイン更新 |
| D | Project スコープのプラグイン更新 |
| E | Local スコープのプラグイン更新 |
| F | 結果報告（サマリ + マーケットプレイス詳細 + スコープ別詳細）|
| G | 失敗があれば `AskUserQuestion` でリトライ / スキップを確認 |

### 振る舞いの原則

- **固定順序**: マーケットプレイス → User → Project → Local（順序を入れ替えない）
- **スコープ個別更新**: 同一プラグインが複数スコープにあっても、スコープごとに独立した更新エントリとして処理
- **継続実行**: 個別更新でエラーが発生しても処理を中断せず、エラーは記録して次へ進む
- **失敗対応の確認**: 結果報告後、失敗があれば一括リトライ / 個別判断 / 全件スキップをユーザに確認
- **二重リトライ防止**: リトライは最大 1 回まで（無限ループ防止）

## A. マーケットプレイス経由でインストール（推奨）

```text
/plugin marketplace add https://github.com/dmajima/claude-plugins
/plugin install plugins-update@dmajima-claude-plugins
```

## B. ローカル複製でインストール（オフライン環境）

```bash
# 1. リポジトリを複製
git clone https://github.com/dmajima/claude-plugins <local-path>

# 2. リリースタグまたは main に切替
cd <local-path>
git checkout main
```

```text
# 3. ローカルパスでマーケットプレイスを登録
/plugin marketplace add <local-path>

# 4. インストール
/plugin install plugins-update@dmajima-claude-plugins
```

## C. 自動更新の有効化（推奨）

`~/.claude/settings.json` の `extraKnownMarketplaces` で `autoUpdate: true` を設定すると、
Claude Code セッション起動時に本プラグインが自動更新されます。

```json
{
  "extraKnownMarketplaces": {
    "dmajima-claude-plugins": {
      "source": {
        "type": "github",
        "repo": "dmajima/claude-plugins"
      },
      "autoUpdate": true
    }
  }
}
```

`autoUpdate: true` の状態でも、本プラグインの `/update-all` を **任意タイミングで手動実行** することで、
セッション中に最新化したい場合に対応できます。

## D. 依存関係

依存マーケットプレイス・プラグインなし。Git CLI が PATH に通っていれば動作します。

| 動作要件 | 説明 |
|---------|-----|
| Git CLI | マーケットプレイス Git クローンの更新に使用 |
| Claude Code | `/reload-plugins` 実行のため |

## 利用例

### 通常更新

```text
/update-all
```

実行後、すべてのマーケットプレイスが `git fetch + reset --hard` で最新化され、
更新結果テーブルが表示されます。最後に `/reload-plugins` の実行を促されます。

### 確認のみ（dry-run）

```text
/update-all --dry-run
```

更新対象一覧のみ表示され、実際の更新は行われません。
本番更新前の影響範囲確認に使えます。

### スコープ限定更新

```text
/update-all --scope user
```

User スコープ（`~/.claude/settings.json` の有効プラグイン）のみを対象に更新します。
Project / Local は対象外。

## 注意事項

- Git クローン配下で **手動編集** を行っている場合、`git reset --hard` で変更が失われる可能性があります。
  本コマンドは事前に `git status` を確認し、クリーンでない場合はスキップします。
- プライベートリポジトリのマーケットプレイスは、Git credential helper / SSH キーの設定が前提です。
- `autoUpdate: true` で十分な場合、本プラグインを使う必要はありません（セッション起動時に自動更新されます）。
  本プラグインは「セッション中に最新版を取り込みたい」場面のために設計されています。

## ファイル構成

```text
plugins-update/
├── .claude-plugin/
│   └── plugin.json           # プラグイン定義
├── README.md                  # このファイル（人間向けリファレンス）
└── commands/
    └── update-all.md          # /update-all コマンド本体
```

## 関連プラグイン

| プラグイン | 関係 |
|----------|-----|
| `extension-toolkit:marketplace-toolkit` | マーケットプレイス本体（`marketplace.json` / README）の管理 |
| `extension-toolkit:marketplace-publisher` | マーケットプレイスへのプラグイン公開ワークフロー |

## 関連ルール

- 自動更新ポリシー: `~/.claude/rules/claude/plugin-auto-update.md`（`autoUpdate: true` 必須・週 1 回更新チェック）
