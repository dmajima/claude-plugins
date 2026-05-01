# plugins-update

Claude Code 公式 CLI（`claude plugin marketplace update` / `claude plugin update`）を経由して
**マーケットプレイスとインストール済みプラグインを全スコープ（User / Project / Local）で一括更新**
するメンテナンスプラグイン。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がプラグイン動作中に参照することはありません。
本プラグインはスキルを持たずコマンドのみを提供するため、コマンドの動作本体は
`commands/update-all.md` を参照してください。設計判断は `references/architecture-decisions.md` および
`references/cross-cutting-rules.md` に記録しています。

## 提供コマンド

| コマンド | 効果 |
|---------|-----|
| `/update-all` | 全マーケットプレイスとプラグインを最新版に更新し、再起動を促す |
| `/update-all --dry-run` | 実行予定の CLI コマンド一覧のみ表示。実際の更新は行わない |
| `/update-all --scope user` | マーケットプレイス更新後、User スコープのプラグインのみ更新 |
| `/update-all --scope project` | マーケットプレイス更新後、Project スコープのプラグインのみ更新 |
| `/update-all --scope local` | マーケットプレイス更新後、Local スコープのプラグインのみ更新 |

`--scope` 指定時も **マーケットプレイス更新（Phase B）は常に実行** されます。
`--dry-run` と `--scope` は併用可能。

## 動作要件

| 動作要件 | 説明 |
|---------|-----|
| Claude Code CLI | `claude plugin marketplace update` / `claude plugin update` を実行するため必須。Phase A-0 で存在チェックを行い、不在時はエラーで中断 |
| Git CLI | マーケットプレイスを Git ソース（GitHub/git）で登録する場合に必要（Claude Code CLI 内部で利用） |
| `/reload-plugins` | 本コマンド完了後、セッションへの反映に使用 |

## 導入手順

### 前提

- Claude Code がインストール済みで `claude plugin` サブコマンドが利用可能であること
- 上記「動作要件」のツールが PATH に通っていること
- 依存プラグインなし（`plugin.json` で `dependencies: []` を明示）

### A. マーケットプレイス経由でインストール（推奨）

```text
/plugin marketplace add https://github.com/dmajima/claude-plugins
/plugin install plugins-update@dmajima-claude-plugins
```

リリースタグの GPG 署名検証を行いたい場合は `git tag -v <tag>` を併用してください
（本リポジトリは現状署名運用なし）。

### B. ローカル複製でインストール（オフライン環境）

```bash
# 1. リポジトリを複製
git clone https://github.com/dmajima/claude-plugins <local-path>

# 2. リリースタグまたは main に切替
cd <local-path>
git checkout <tag-or-branch>   # 例: git checkout v2.2.0 / git checkout main
```

```text
# 3. ローカルパスでマーケットプレイスを登録
/plugin marketplace add <local-path>

# 4. インストール
/plugin install plugins-update@dmajima-claude-plugins
```

### C. 自動更新の有効化（推奨）

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

`autoUpdate: false` の場合や未設定時は、以下を手動実行することで最新化できます:

```text
/plugin update plugins-update@dmajima-claude-plugins
```

`autoUpdate: true` の状態でも、本プラグインの `/update-all` を **任意タイミングで手動実行** することで、
セッション中に最新化したい場合に対応できます。

### D. 依存関係

依存プラグインなし（`dependencies: []` を `plugin.json` で明示）。
個別インストール手順の追加は不要です。

### 動作確認

インストール直後の確認には `--dry-run` を使用します:

```text
/update-all --dry-run
```

実行予定の CLI コマンド一覧が表示され、実際の更新は行われません。

## 利用方法

### 最小例

ユーザ:
> 全部のプラグインを最新にして

Claude（要約）:
> Phase A〜G を順次実行し、`claude plugin marketplace update` と `claude plugin update <plugin>@<marketplace> --scope <scope>` を呼び出して全マーケットプレイス・全スコープのプラグインを更新。結果サマリと「次のアクション」を提示し、`/reload-plugins` か再起動を促す。

### 利用例

#### 通常更新

```text
/update-all
```

実行後、すべてのマーケットプレイスとプラグインが公式 CLI で最新化され、
更新結果テーブルが表示されます。最後に `/reload-plugins` または Claude Code 再起動を促されます。

#### 確認のみ（dry-run）

```text
/update-all --dry-run
```

実行予定の CLI コマンド一覧のみ表示され、実際の更新は行われません。
本番更新前の影響範囲確認に使えます。

#### スコープ限定更新

```text
/update-all --scope user
```

マーケットプレイス更新後、User スコープ（`~/.claude/settings.json` の有効プラグイン）のみを対象に更新します。

#### dry-run + スコープ限定

```text
/update-all --dry-run --scope project
```

Project スコープに限定した実行予定コマンドのみを表示します。

## 動作概要

`commands/update-all.md` で実装する Phase 構成の概略です（詳細はコマンド本体を参照）。

| Phase | 処理内容 | 使用 CLI |
|-------|---------|---------|
| A | 対象収集（マーケットプレイス一覧 + 各スコープの `enabledPlugins`） | `claude plugin marketplace list` |
| A-0 | Claude Code CLI 存在チェック | `claude plugin --help` |
| A-1 | プラグイン名・MP 名・スコープ名の入力検証（XR-1） | — |
| A-2 | マーケットプレイス整合性検証（未登録 MP の早期除外） | — |
| B | マーケットプレイス更新（`--scope` 指定時も常に実行） | `claude plugin marketplace update` |
| C | User スコープのプラグイン更新 | `claude plugin update <plugin>@<marketplace> --scope user` |
| D | Project スコープのプラグイン更新 | 同上 `--scope project` |
| E | Local スコープのプラグイン更新 | 同上 `--scope local` |
| F | 結果報告（サニタイズ + サマリ + マーケットプレイス詳細 + スコープ別詳細） | — |
| G | 失敗があれば `AskUserQuestion` でリトライ / スキップを確認 | — |

### 横断ルール

各 Phase は以下 4 つの横断関心事に従います（規則本体は `references/cross-cutting-rules.md`）。

| ID | ルール |
|----|------|
| XR-1 | 入力検証（プラグイン名・MP 名・スコープの正規表現照合 + ホワイトリスト + NFKC 正規化） |
| XR-2 | タイムアウト（個別 60 秒・全体 30 分・サーキットブレーカー） |
| XR-3 | 出力サニタイズ（GitHub PAT / GitLab / AWS / Slack / JWT / Google API / Stripe / Azure / NPM / SSH 鍵 / ローカルパス + 40 字超デフォルトマスク） |
| XR-4 | リトライ上限（最大 1 回 = 合計 2 試行） |

### 振る舞いの原則

- **公式 CLI 経由**（ADR-PU-002）
- **固定順序**（ADR-PU-003）
- **スコープ個別更新**（ADR-PU-001/002）
- **継続実行**（ADR-PU-003）
- **exit code 一次判定 + Unknown 区分**（ADR-PU-005）
- **横断ルール SSOT 参照**（ADR-PU-004）
- **失敗対応の確認**: 結果報告後、失敗があれば一括リトライ / 個別判断 / 全件スキップをユーザに確認

## 技術スタック・アーキテクチャ

設計判断の詳細は次を参照してください:

- [`references/architecture-decisions.md`](references/architecture-decisions.md) — ADR-PU-001〜005
- [`references/cross-cutting-rules.md`](references/cross-cutting-rules.md) — XR-1〜XR-4 の SSOT

## 注意事項

- 本コマンドは Claude Code 公式 CLI に処理を委譲します。`git reset --hard` 等の低レベル操作は
  行わないため、マーケットプレイスのローカル複製で **手動編集や独自ブランチが意図せず破壊される心配はありません**。
- プライベートリポジトリのマーケットプレイスは、Git credential helper / SSH キーの設定が前提です。
  認証エラー時の詳細メッセージは CLI 出力に依存しますが、Phase F の結果報告では認証情報・URL 埋め込み
  トークン・SSH 鍵パス・ローカルパス内のユーザ名等を **マスクして表示** します。
- **サプライチェーンリスク**:
  - マーケットプレイス更新により新しい `hooks` / `commands` / `agents` / MCP サーバが
    引き込まれた場合、次回 Claude Code 起動時に **自動実行される** 可能性があります。
  - `--dry-run` で確認できるのは「実行する CLI コマンド」だけで、引き込まれる **新規 hooks の内容は
    確認できません**。再起動前に `claude plugin show <plugin>@<marketplace>` を個別に実行し、
    `hooks` セクションの差分を必ず確認してください。
  - 信頼するマーケットプレイスのみで本コマンドを使用してください。
- `autoUpdate: true` で十分な場合、本プラグインを使う必要はありません（セッション起動時に自動更新されます）。
  本プラグインは「セッション中に最新版を取り込みたい」場面のために設計されています。
  `autoUpdate: true` 起動時自動更新と `/update-all` 手動更新が同時に走った場合、CLI 内部のロック挙動に
  依存します（一方が待機する想定）。
- `claude plugin update` は **再起動が必要** と公式が明示しているため、本コマンド完了後は
  `/reload-plugins` か Claude Code 再起動が必要です。

## ロールバック手順

更新後に問題が発覚した場合の復旧手順:

1. `claude plugin uninstall <plugin>@<marketplace>` で問題のあるプラグインをアンインストール
2. マーケットプレイスの旧版に戻す（必要な場合）
   - **リモートマーケットプレイス**: ローカル複製を作成し旧タグへ固定
     ```bash
     git clone <marketplace-url> <local-path>
     cd <local-path>
     git checkout <旧タグ or 旧コミットハッシュ>
     ```
     その後 `/plugin marketplace add <local-path>` で別マーケットプレイスとして登録
   - **ローカルマーケットプレイス**: 該当ディレクトリで `git checkout <旧タグ>`
3. `claude plugin install <plugin>@<marketplace>` で旧版から再インストール
4. `/reload-plugins` または Claude Code 再起動

### タグ非存在時のフォールバック

リリースタグが切られていないマーケットプレイスでは、過去の commit ハッシュを直接指定:

```bash
git log --oneline    # 復旧したい時点のハッシュを特定
git checkout <commit-hash>
```

### マーケットプレイス本体が壊れた場合のリセット

`marketplace.json` 不整合等で読み込み不能になった場合:

```text
/plugin marketplace remove <marketplace-name>
/plugin marketplace add <url-or-local-path>
```

その後、必要なプラグインを再インストール。

マーケットプレイス本体（`marketplace.json` / 構成プラグイン群）の自動ロールバック機能は公式 CLI に
存在しないため、上記のように **ローカル複製 + git checkout** での代替が現実的です。

## ファイル構成

```text
plugins-update/
├── .claude-plugin/
│   └── plugin.json                       # プラグイン定義
├── README.md                              # このファイル（人間向けリファレンス）
├── commands/
│   └── update-all.md                      # /update-all コマンド本体
└── references/
    ├── architecture-decisions.md          # ADR-PU-001〜005（設計判断記録）
    └── cross-cutting-rules.md             # XR-1〜XR-4（横断ルール SSOT）
```

## 関連プラグイン

| プラグイン | 関係 |
|----------|-----|
| `extension-toolkit:marketplace-toolkit` | マーケットプレイス本体（`marketplace.json` / README）の管理 |
| `extension-toolkit:marketplace-publisher` | マーケットプレイスへのプラグイン公開ワークフロー |

## 関連ルール

- 自動更新ポリシー: `~/.claude/rules/claude/plugin-auto-update.md`（`autoUpdate: true` 必須・週 1 回更新チェック）

## ライセンス

本プラグインは MIT License で配布されます。
