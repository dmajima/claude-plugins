# design-bridge

Markdown の画面設計書とローカルのモック HTML を正本（SSOT）として、claude.ai/design の design-system プロジェクトへ同期するプラグインです。設計フェーズと実装フェーズを通じて、設計書・モック・Claude Design 上のカードが食い違わないことを、運用ルールではなく Claude Code のフック機構で担保します。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。

## 解決する課題

Markdown の画面設計書だけでは画面イメージが伝わらず、かといって Claude Design 上にモックを作っても、設計書・モック・実装のどれかを直した瞬間に三者が乖離します。`DesignSync` ツールにはリモート変更の通知機構（watch）がないため、放置すると「承認したカード」と「正本の設計書」がずれ、承認プロセスそのものが壊れます。

本プラグインは次の方針でこれを防ぎます。

| 方針 | 内容 |
|------|------|
| 正本はローカル | `specs/` の Markdown と `mocks/` の HTML だけが正本。Claude Design は表示・承認用の鏡として扱う |
| push は自動強制 | 設計書・モックを変更した応答は、Claude Design への反映が終わるまで Stop フックで終了できない |
| pull は明示のみ | Claude Design 側を正とする取り込みは、ユーザーが明示的に指示したときだけ実行する |
| 画面イメージは実体化 | モックのスクリーンショットをリポジトリに置き、Markdown から相対参照する |

## 提供機能

| 機能 | 種別 | 説明 |
|-----|------|------|
| `design-init` | スキル | プロジェクトへの導入。ディレクトリ構成の作成、Claude Design プロジェクトの紐付け、スクショ用 venv の構築 |
| `design-mock` | スキル | Markdown 画面設計書とトンマナ・基礎レイアウトから画面モック HTML を生成する |
| `design-push` | スキル | スクショ再生成 → Markdown の画面イメージ更新 → Claude Design へ反映、までを 1 本で実行する |
| `design-pull` | スキル | 明示指示時のみ。Claude Design の内容と全件照合し、差分を提示したうえでローカルを最新化する |
| `design-status` | スキル | 未反映の設計書・モック一覧と、リモートとのドリフト状況を表示する |
| `/design-init` `/design-mock` `/design-push` `/design-pull` `/design-status` | コマンド | 各スキルの明示起動 |
| PostToolUse フック | フック | 設計書・モックの変更を検出し、未反映として記録する |
| Stop フック | フック | 未反映が残っていれば応答の終了をブロックする |

## 導入手順

### 前提

- Claude Code がインストール済み
- claude.ai アカウントで `/design-login` を実行し、design-system へのアクセスを認可済みであること
- Python 3.10 以上（スクリーンショット生成に使用。`design-init` がプラグイン専用 venv を構築します）

### A. マーケットプレイス経由インストール（推奨）

```text
/plugin marketplace add dmajima/claude-plugins
/plugin install design-bridge@dmajima-claude-plugins
```

### B. ローカル複製してインストール（オフライン・企業内環境向け）

公開マーケットプレイスにアクセスできない環境では、リポジトリをローカルに複製してから登録します。

```bash
# 1. リポジトリを複製
git clone https://github.com/dmajima/claude-plugins <local-path>

# 2. 必要に応じてブランチ・タグ切替
cd <local-path>
git checkout main
```

```text
# 3. ローカルパスでマーケットプレイスを登録
/plugin marketplace add <local-path>

# 4. プラグインをインストール
/plugin install design-bridge@dmajima-claude-plugins
```

### C. 自動更新の有効化

`~/.claude/settings.json` の `extraKnownMarketplaces` で `autoUpdate: true` を設定すると、セッション起動時にマーケットプレイス + インストール済みプラグインが自動更新されます。

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

`autoUpdate: false` の場合は `/plugin update` を手動実行することで最新化できます。

### D. 依存関係のインストール

プラグイン依存なし（`plugin.json` の `dependencies` は空）。ただし以下の外部ツールが利用者環境に必要です。

- Python 3.10+（`design-init` が構築する venv 上で Playwright を動かし、モックのスクリーンショットを生成します）
- Claude Code の `DesignSync` ツール（`/design-login` による design-system 認可が必要）

### 動作確認

```text
/design-status
```

## 使い方

### 初回セットアップ

```text
/design-init
```

対象リポジトリに次の構成を作り、Claude Design プロジェクトとの紐付けを記録します。

```text
<repo>/
├─ specs/screens/S001_login.md      # 画面設計書（正本）
├─ specs/assets/S001_login.png      # スクリーンショット（自動生成）
├─ mocks/_tokens.html               # トンマナ
├─ mocks/_layout.html               # 基礎レイアウト
├─ mocks/S001_login.html            # 画面モック（正本）
└─ .claude/design-bridge.json       # Claude Design プロジェクトとの紐付け設定
```

### 日常の流れ

```text
/design-mock S001_login     # 設計書からモックを生成
/design-push                # スクショ再生成 → Markdown 更新 → Claude Design へ反映
```

設計書やモックを編集したまま `/design-push` を忘れた場合、Stop フックが応答の終了をブロックして反映を促します。

### 自然言語

| 発話例 | 起動 |
|-------|-----|
| 「このリポジトリに design-bridge を導入して」 | `design-init` |
| 「ログイン画面のモックを作って」 | `design-mock` |
| 「Claude Design に反映して」 | `design-push` |
| 「Claude Design 側の変更を取り込んで」 | `design-pull` |
| 「設計書とデザインのずれを確認して」 | `design-status` |

## ファイル構成

```text
plugins/design-bridge/
├── .claude-plugin/
│   └── plugin.json
├── README.md
├── LICENSE
├── commands/
├── skills/
├── hooks/
└── references/
```

## 依存システム（External Dependencies）

| システム | 用途 | 参照箇所 |
|---------|------|---------|
| claude.ai/design | 画面モックを design-system プロジェクトのカードとして表示・承認する | `skills/design-push/`、`skills/design-pull/` |

## 注意事項

- 本プラグインの `design-*` 機能は claude.ai/design 向けです。社内マーケットプレイス `customerep-claudecode` の `prod-asset-import` プラグインにある `design-sync` スキルは、本番サーバーからフロントリソースを取り込む別物です。名前が似ていますが用途は異なります。
- `DesignSync` にはリモート変更の通知機構がないため、`design-pull` はセッション中の自動検知ではなく、明示実行時の全件照合として動作します。

## ライセンス

[MIT License](LICENSE) の下で配布されています。
