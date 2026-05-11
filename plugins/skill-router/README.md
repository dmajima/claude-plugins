# skill-router

ユーザプロンプトに対し、Claude Code 有効化スキルの description / evals を分析してルーティング推奨を `UserPromptSubmit` フックで注入し、スキルの自動起動率を高めるプラグイン。

**v0.3.0**: Anthropic Claude API を用いた **オプトインの LLM 拡張** に対応しました。デフォルトは無効で既存挙動を維持しつつ、有効化すると同義語・言い換えに弱い表層一致ヒューリスティックを LLM が補完し、特定率を向上できます。詳細は「LLM 拡張」セクションを参照してください。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。各スキルの動作本体は `skills/{skill-name}/SKILL.md` および `references/` 配下を参照してください。

## 提供機能

| 機能 | 種別 | 説明 |
|-----|------|------|
| `skill-router` | スキル | ルーティングロジック本体・検証用 evals の保持 |
| `/router-rebuild` | コマンド | インデックスを手動で再構築する（LLM 有効時は enrichment も差分更新） |
| `/router-status` | コマンド | 統計・直近のルーティング決定・スコア分布を表示する（`--clean` で 30 日超セッション削除） |
| `/router-toggle` | コマンド | プラグインを `on` / `off` に切り替える |
| `/router-llm-cache` | コマンド | v0.3 LLM enrichment キャッシュの参照・クリア・スキル別詳細表示 |
| `SessionStart` フック | フック | `startup` / `resume` / `clear` 時にインデックス（`index.json` + `inverted_index.json`）を自動構築する。v0.3.0 から `requirements.txt` に `anthropic` SDK が追加され、内蔵 venv ライフサイクル管理（`<base>/.venv` 配下、72h TTL、1 セッション 3 回までの自動再構築）が常時有効に。LLM 有効時は同フックでオフライン拡張（Phase A）も実施 |
| `UserPromptSubmit` フック | フック | プロンプトを 5W1H 抽出 + 逆引き索引 + スコア閾値判定し、`high` / `mid` 帯のスキル候補を `additionalContext` で注入する。LLM オンライン再ランク（Phase B）が有効かつ tier=mid・上位差小の場合のみ LLM 呼出。フック終了時に古い venv（72h 超）を自動撤去する |

## 動作概要

```text
[SessionStart]
  └─ build_index.py で installed_plugins.json と各 SKILL.md / evals を走査し
     index.json + inverted_index.json を生成
     （installed_plugins.json schema v1 / v2 に対応。未対応バージョンは
      警告ログを残しフェイルオープン）
     │
     └─ [llm.enabled かつ offline_enrichment.enabled のとき]
        llm_enrich.py が各スキルの description / use_when / skip_when / evals を
        Anthropic Claude に渡し、拡張キーワード・想定発話例・タスクラベルを生成して
        index.json と inverted_index.json に統合（content hash でキャッシュ）

[UserPromptSubmit]
  └─ route.py が prompt を受け取り
     ├─ config.json の重み・閾値・LLM 設定ロード
     ├─ 逆引き索引で候補を最大 50 件に絞り込み
     ├─ keyword / trigger_phrase / eval / context / file_ext / skip_phrase でスコア計算
     ├─ top1 絶対値 + top1/top2 相対比で high / mid / low 判定
     ├─ [llm.enabled かつ online_routing.enabled、tier=mid、ratio<閾値 のとき]
     │   llm_route.py が上位 N 候補を Claude に再ランクさせ、score_boost 倍した
     │   fit を heuristic スコアに加算して再判定
     └─ high → 確定推奨 1 件、mid → 候補上位 3 件を additionalContext に注入
```

詳細設計はリポジトリ管理ドキュメント（`skill-router_detailed_design_v2.md`）と本リポジトリの `plugins/skill-router/.claude/.local/work/.../adr.md` を参照してください。

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
/router-rebuild              # インデックスを手動再構築（LLM 有効時は enrichment も差分更新）
/router-status               # 統計と直近の決定を表示（stats.llm を含む）
/router-status --clean       # 30 日超のセッション履歴を削除
/router-toggle on            # ルーティング有効化
/router-toggle off           # ルーティング無効化（disabled フラグファイル生成）
/router-llm-cache            # LLM enrichment キャッシュ統計を表示
/router-llm-cache --clear    # LLM enrichment キャッシュを全削除
/router-llm-cache --show <qualified_name>   # 指定スキルの enrichment 詳細を表示
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
| 「LLM enrichment の状態を見せて」 | `/router-llm-cache` |
| 「<plugin>:<skill> の LLM 拡張内容を見たい」 | `/router-llm-cache --show <qualified_name>` |

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

## LLM 拡張（v0.3+）

スキル特定率を更に高めたい場合、Anthropic Claude API による LLM 拡張をオプトインで有効化できます。デフォルトは **完全に無効**（`llm.enabled: false`）で、既存ユーザは何も設定しなければ従来挙動を維持します。

### 仕組み

| Phase | タイミング | 役割 | コスト傾向 |
|-------|-----------|------|-----------|
| **A. オフライン拡張** | SessionStart | 各スキルから拡張キーワード・想定発話例・タスクラベルを LLM が生成し、index に統合。content hash でキャッシュし、変更されたスキルのみ呼出 | 低（多くの場合キャッシュヒットでゼロ） |
| **B. オンライン再ランク** | UserPromptSubmit | tier=mid かつ top1/top2 比が小さい曖昧時のみ、上位 N 候補を 1 リクエストで Claude に再評価させる | 中（曖昧時のみ・1 セッション数回） |

**LLM 機能はすべてフェイルオープン**: SDK 不在・API キー未設定・通信失敗・JSON パース失敗のいずれでも、heuristic スコアの結果がそのまま使われます。

### 設定例

`<base>/config.json` に以下を追記してください（既定値の全フィールド一覧は `references/templates/config.default.json` を参照）。

```json
{
  "llm": {
    "enabled": true,
    "model": "claude-haiku-4-5-20251001",
    "api_key_env": "ANTHROPIC_API_KEY",
    "request_timeout_sec": 30,
    "offline_enrichment": {
      "enabled": true,
      "max_skills_per_run": 30,
      "max_keywords_per_skill": 15,
      "max_phrases_per_skill": 8
    },
    "online_routing": {
      "enabled": false,
      "trigger_tier": "mid",
      "ratio_threshold": 1.5,
      "max_candidates": 5,
      "timeout_sec": 5.0,
      "score_boost": 4.0
    }
  }
}
```

### API キーの渡し方

API キーは以下の順序で解決されます。

1. 環境変数 `${llm.api_key_env}`（既定: `ANTHROPIC_API_KEY`）
2. `credentials-manager` プラグインの `credentials.json`
   - キー名 `anthropic-api-key` / `ANTHROPIC_API_KEY` / `anthropic` のいずれか
   - 値は文字列または `{"value": "..."}` 形式に対応
3. いずれも無ければ LLM 機能は自動的にスキップ（フェイルオープン）

`credentials-manager` を併用する場合は次のように保存します。

```text
/credentials-manager:manage
> 追加 → name: anthropic-api-key、value: <Console から発行した API キー>
```

### コスト目安

`claude-haiku-4-5` 既定で:

- **オフライン拡張**: 1 スキルあたり入力 ≦ 800 tokens、出力 ≦ 600 tokens。100 スキルでも初回フル更新の費用は USD 0.05 未満。content hash キャッシュにより 2 回目以降はゼロ。
- **オンライン再ランク**: 候補 5 件・プロンプト ≦ 2KB で入力 ≦ 1500 tokens / 出力 ≦ 600 tokens。1 セッション中の発火頻度は曖昧 mid に限定されるため、通常数回。

### 状態確認とトラブルシュート

| 症状 | 確認手順 |
|------|---------|
| LLM 機能が動かない | `/router-status` の `stats.llm` を確認。`enabled: false` の場合は config を見直す |
| キャッシュが空 | `/router-llm-cache` で生成状況・最新時刻を確認。`/router-rebuild` を再実行 |
| 想定外のキーワード | `/router-llm-cache --show <qualified_name>` で生成内容を確認、必要なら `--clear` で再生成 |
| API キーが効かない | `<base>/route.log` / `<base>/index.log` を確認。env 名のタイプミス、credentials-manager の保存名を見直す |
| API 障害でフックが遅い | `llm.online_routing.enabled` を `false` に。`offline_enrichment` のみでも特定率は向上する |

### セキュリティ注意

- **API キーのフル値は絶対にログ・コミットメッセージ・チャットに出力しないでください**。
- `llm.api_key_env` には `^[A-Z][A-Z0-9_]{2,63}$` を満たす環境変数名のみ受け入れ、`PATH` `HOME` `USER` 等の明らかに認証情報でない名前は強制的に既定 (`ANTHROPIC_API_KEY`) に差し戻されます。万一の `config.json` 改竄による無関係な環境変数の値漏洩に対する防御策です。
- `credentials-manager` プラグインを利用すると、`.gitignore` 登録・マスキング表示・URL/ドメイン自動マッチが揃うため推奨。

#### 外部送信されるデータ

- **Phase A (offline_enrichment)**: 各スキルの `description` / `use_when` / `skip_when` / `trigger_phrases` / `evals.prompt` を Anthropic に送信します。スキル定義は本来公開可能なメタデータですが、社内専用スキルを含む場合は Phase A も無効化してください。
- **Phase B (online_routing)**: **ユーザプロンプト全文** が Anthropic に送信されます。送信前に `session_state.mask_secrets` で sk-/ghp_/Bearer 等の典型的な認証情報パターンはマスクされますが、社内秘・顧客名・固有のコードパス等は素通しになる可能性があります。Phase B の有効化時は組織のデータポリシーを確認してください。

#### 悪意あるスキルからのルーティング誘導

LLM 拡張は posting 一覧を増やすのみで実コード実行には繋がりませんが、以下の攻撃ベクトルが残ります。

- **誤起動誘発**: 第三者が公開した悪意あるスキルが、`description` や `evals.prompt` に攻撃用キーワード（例: 全く無関係な業務語句）を埋め込むことで、ユーザがそれらの語句を含む別目的の発話をした際に当該スキルを `high` 推奨させる可能性。
- **緩和策**:
  1. `/router-llm-cache --show <qualified_name>` で各スキルの拡張内容を確認できます。怪しい場合は当該スキルをアンインストールするか、`/router-llm-cache --clear` でキャッシュを破棄してください。
  2. インストール元が信頼できないスキルは `enabledPlugins` から除外する。
  3. `_sanitise_string_list` で改行・制御文字を含むキーワードは破棄され、長さも 40 文字に制限済み。

#### キャッシュファイルの権限

`<base>/llm_cache/enrichment.json` は POSIX 環境では `0o600` で保存されます（他ユーザから読めない）。Windows では ACL 制御を行わないため、必要に応じて `<base>` をユーザ専用ディレクトリ配下に配置してください。

## ファイル構成

```text
plugins/skill-router/
├── .claude-plugin/
│   └── plugin.json
├── README.md
├── commands/
│   ├── router-rebuild.md
│   ├── router-status.md
│   ├── router-toggle.md
│   └── router-llm-cache.md       # v0.3 LLM enrichment キャッシュ管理
├── hooks/
│   └── hooks.json
├── skills/
│   └── skill-router/
│       ├── SKILL.md
│       ├── README.md
│       └── evals/                # 動作分岐検証用ケース集
│           ├── README.md
│           └── case-01_*.md ... case-10_*.md
├── tests/
│   ├── test_build_index.py
│   ├── test_route.py
│   ├── test_session_state.py
│   ├── test_parse_evals.py
│   ├── test_venv_lifecycle.py
│   ├── test_llm_client.py        # v0.3
│   ├── test_llm_enrich.py        # v0.3
│   └── test_llm_route.py         # v0.3
└── references/
    ├── scripts/
    │   ├── hooks/
    │   │   ├── build_index_on_start.sh
    │   │   └── route_prompt.sh
    │   ├── lib/
    │   │   ├── build_index.py    # Phase A 統合済 (v0.3)
    │   │   ├── route.py          # Phase B 統合済 (v0.3)
    │   │   ├── session_state.py
    │   │   ├── parse_evals.py
    │   │   ├── venv_lifecycle.py
    │   │   ├── llm_client.py     # v0.3 Anthropic SDK ラッパー
    │   │   ├── llm_enrich.py     # v0.3 オフライン拡張
    │   │   └── llm_route.py      # v0.3 オンライン再ランク
    │   └── setup/
    │       └── requirements.txt  # v0.3 から anthropic SDK
    ├── spike/                    # 動作検証スクリプト（利用者は通常使用しない）
    │   ├── s1_session_id.py
    │   ├── s2_hook_concat.py
    │   ├── s3_plugin_data_var.py
    │   ├── s4_session_start_clear.py
    │   └── s5_python_startup_latency.py
    └── templates/
        └── config.default.json   # v0.3 から `llm` セクション含む
```

## ライセンス

[MIT License](LICENSE) の下で配布されています。
