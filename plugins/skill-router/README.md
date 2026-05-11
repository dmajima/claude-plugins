# skill-router

ユーザプロンプトに対し、Claude Code 有効化スキルの description / evals を分析してルーティング推奨を `UserPromptSubmit` フックで注入し、スキルの自動起動率を高めるプラグイン。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。各スキルの動作本体は `skills/{skill-name}/SKILL.md` および `references/` 配下を参照してください。

## 提供機能

| 機能 | 種別 | 説明 |
|-----|------|------|
| `skill-router` | スキル | ルーティングロジック本体・検証用 evals の保持 |
| `/router-rebuild` | コマンド | インデックスを手動で再構築する |
| `/router-status` | コマンド | 統計・直近のルーティング決定・スコア分布を表示する（`--clean` で 30 日超セッション削除） |
| `/router-toggle` | コマンド | プラグインを `on` / `off` に切り替える |
| `SessionStart` フック | フック | `startup` / `resume` / `clear` 時にインデックス（`index.json` + `inverted_index.json`）を自動構築する。Phase 2 で `requirements.txt` に依存が追加されると、内蔵 venv ライフサイクル管理（`<base>/.venv` 配下、72h TTL、1 セッション 3 回までの自動再構築）も同フックから起動する |
| `UserPromptSubmit` フック | フック | プロンプトを 5W1H 抽出 + 逆引き索引 + スコア閾値判定し、`high` / `mid` 帯のスキル候補を `additionalContext` で注入する。フック終了時に古い venv（72h 超）を自動撤去する |

## 動作概要

```text
[SessionStart]
  └─ build_index.py で installed_plugins.json と各 SKILL.md / evals を走査し
     index.json + inverted_index.json を生成
     （installed_plugins.json schema v1 / v2 に対応。未対応バージョンは
      警告ログを残しフェイルオープン）

[UserPromptSubmit]
  └─ route.py が prompt を受け取り
     ├─ config.json の重み・閾値ロード
     ├─ 逆引き索引で候補を最大 50 件に絞り込み
     ├─ keyword / trigger_phrase / eval / context / file_ext / skip_phrase でスコア計算
     ├─ top1 絶対値 + top1/top2 相対比で high / mid / low 判定
     └─ high → 確定推奨 1 件、mid → 候補上位 3 件を additionalContext に注入
```

詳細設計はリポジトリ管理ドキュメント（`skill-router_detailed_design_v2.md`）を参照してください。

## 導入手順

### 前提

- Claude Code がインストール済み
- Python 3.10 以上が PATH 上で `python3` または `python` として解決できること
- Bash 4.0 以上（フックエントリポイント実行用）
- 依存プラグインなし（標準ライブラリのみで動作）

### A. マーケットプレイス経由インストール（推奨）

```text
/plugin marketplace add dmajima/claude-plugins
/plugin install skill-router@dmajima-claude-plugins
```

### B. ローカル複製してインストール（オフライン・企業内環境向け）

```bash
# 1. リポジトリを複製
git clone https://github.com/dmajima/claude-plugins.git <local-path>

# 2. 必要に応じてブランチ・タグ切替
cd <local-path>
git checkout main
```

```text
# 3. ローカルパスでマーケットプレイスを登録
/plugin marketplace add <local-path>

# 4. プラグインをインストール
/plugin install skill-router@dmajima-claude-plugins
```

### C. 自動更新の有効化

`~/.claude/settings.json` の `extraKnownMarketplaces` で `autoUpdate: true` を設定すると、セッション起動時に自動更新されます。

```json
{
  "extraKnownMarketplaces": {
    "dmajima-claude-plugins": {
      "source": { "type": "github", "repo": "dmajima/claude-plugins" },
      "autoUpdate": true
    }
  }
}
```

### D. 依存関係のインストール

**依存プラグインなし**（標準ライブラリのみで動作）。

`plugin.json` に `dependencies` の記載はなく、別マーケットプレイスのプラグインへの参照も持ちません。`anthropic-agent-skills` 等の追加マーケットプレイスを別途登録する必要はありません。

#### Python 等の外部ツール依存

利用者環境に以下の前提となる外部ツールが必要です:

- Python 3.10 以上（`python3` または `python` として PATH 上に解決可能）
- Bash 4.0 以上（フックエントリポイント実行用）

### E. 動作確認

```text
/router-rebuild
/router-status
```

`/router-status` でインデックス生成統計とスコア分布ヒストグラムが表示されれば導入完了です。

## 使い方

### スラッシュコマンド

```text
/router-rebuild              # インデックスを手動再構築
/router-status               # 統計と直近の決定を表示
/router-status --clean       # 30 日超のセッション履歴を削除
/router-toggle on            # ルーティング有効化
/router-toggle off           # ルーティング無効化（disabled フラグファイル生成）
```

`disabled` フラグファイルは以下の優先順位で `route_prompt.sh` から参照されます（最初に見つかった時点でルーティングをスキップします）。

| 優先 | パス | スコープ |
|-----|------|---------|
| 1 | `${CLAUDE_PLUGIN_DATA}/disabled` | プラグイン永続データ領域（提供されていれば最優先） |
| 2 | `<repo-root>/.claude/.local/plugins/skill-router/disabled` | リポジトリスコープ |
| 3 | `${HOME}/.claude/.local/plugins/skill-router/disabled` | ユーザスコープ（最終フォールバック） |


### 自然言語

| 発話例 | 起動 |
|-------|-----|
| 「router のインデックスを再構築して」 | `/router-rebuild` |
| 「router の状態を確認したい」 | `/router-status` |
| 「skill-router を一時停止して」 | `/router-toggle off` |

### 自動動作

ユーザがプロンプトを送信するたびに、`UserPromptSubmit` フックが自動発火し、適合度の高いスキルがある場合のみ `additionalContext` で推奨が注入されます。閾値未満（`low` 帯）では何も注入せず通常応答に進みます。

## 設定（高度な用途）

`<base>/config.json` で重み・閾値を調整できます。`<base>` は以下の優先順位で解決されます。

1. `${CLAUDE_PLUGIN_DATA}`（定義され書込可能なら最優先）
2. リポジトリ配下: `<repo-root>/.claude/.local/plugins/skill-router/`
3. ホーム配下: `~/.claude/.local/plugins/skill-router/`

主要パラメータ:

| キー | 既定値 | 説明 |
|-----|-------|------|
| `weights.keyword_overlap` | 1.0 | プロンプトトークンとスキル keywords の重なり係数 |
| `weights.trigger_phrase` | 2.0 | description 内 trigger_phrase 部分一致の係数 |
| `weights.eval_similarity` | 3.0 | evals プロンプトとの 3-gram Jaccard 係数 |
| `weights.skip_phrase_combo` | -5.0 | skip 動詞 + 名詞共起時の減点 |
| `thresholds.high_score` | 8.0 | high 帯閾値 |
| `thresholds.high_ratio` | 1.25 | top1/top2 相対比の高帯条件 |
| `thresholds.mid_score` | 4.0 | mid 帯閾値 |
| `candidate_filter.max_candidates_per_route` | 50 | スコア計算対象の最大候補数 |
| `candidate_filter.context_window` | 3 | 文脈継続性算出時の直近ターン数 |

## ファイル構成

```text
plugins/skill-router/
├── .claude-plugin/
│   └── plugin.json
├── README.md
├── commands/
│   ├── router-rebuild.md
│   ├── router-status.md
│   └── router-toggle.md
├── hooks/
│   └── hooks.json
├── skills/
│   └── skill-router/
│       ├── SKILL.md
│       ├── README.md
│       └── evals/                # 動作分岐検証用ケース集
│           ├── README.md
│           └── case-01_*.md ... case-10_*.md
└── references/
    ├── scripts/
    │   ├── hooks/
    │   │   ├── build_index_on_start.sh
    │   │   └── route_prompt.sh
    │   ├── lib/
    │   │   ├── build_index.py
    │   │   ├── route.py
    │   │   ├── session_state.py
    │   │   └── parse_evals.py
    │   └── setup/
    │       └── requirements.txt
    ├── spike/                    # 動作検証スクリプト（利用者は通常使用しない）
    │   ├── s1_session_id.py
    │   ├── s2_hook_concat.py
    │   ├── s3_plugin_data_var.py
    │   ├── s4_session_start_clear.py
    │   └── s5_python_startup_latency.py
    └── templates/
        └── config.default.json
```

## ライセンス

[MIT License](LICENSE) の下で配布されています。
