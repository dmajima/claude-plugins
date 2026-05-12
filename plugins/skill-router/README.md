# skill-router

ユーザプロンプトに対し、Claude Code 有効化スキルの description / evals を分析してルーティング推奨を `UserPromptSubmit` フックで注入し、スキルの自動起動率を高めるプラグイン。

**完全ローカルで動作する埋め込みベース意味的類似度判定** をオプトインで搭載（既定無効）。外部 API には一切接続せず、`fastembed` + 多言語 MiniLM モデル（約 120MB）で同義語・言い換えを意味ベクトルで捕捉します。有効化すると現行ヒューリスティックでは拾えない表現バリエーションを大幅に改善できます。詳細は「埋め込み判定」セクションを参照してください。

## このドキュメントについて

このファイルは **人間向けのリファレンス** です。Claude Code がスキル動作中に参照することはありません。各スキルの動作本体は `skills/{skill-name}/SKILL.md` および `references/` 配下を参照してください。

## 提供機能

| 機能 | 種別 | 説明 |
|-----|------|------|
| `skill-router` | スキル | ルーティングロジック本体・検証用 evals の保持 |
| `/router-rebuild` | コマンド | インデックスを手動で再構築する（embedding 有効時はベクトルも差分更新） |
| `/router-status` | コマンド | 統計・直近のルーティング決定・スコア分布を表示する（`--clean` で 30 日超セッション削除）。`stats.embedding` を含む |
| `/router-toggle` | コマンド | プラグインを `on` / `off` に切り替える |
| `/router-embedding-cache` | コマンド | v0.4 埋め込みキャッシュの参照・クリア・スキル別詳細表示 |
| `SessionStart` フック | フック | `startup` / `resume` / `clear` 時にインデックス（`index.json` + `inverted_index.json`）を自動構築する（`hooks.json` timeout 360s）。`requirements.txt` の `fastembed` + `numpy` + `onnxruntime` に対する内蔵 venv ライフサイクル管理（`<base>/.venv` 配下、72h TTL、1 セッション 3 回までの自動再構築）も同フックから実施。`embedding.enabled` 時は同フックで各スキルのベクトル化（fastembed ONNX 推論）も実施。timeout 内訳の目安: venv create 60s + pip install 180s + index build 数 s + ベクトル化 100 スキルで 10s 程度 = 計 250s 程度（初回有効化時のみ）|
| `UserPromptSubmit` フック | フック | プロンプトを 5W1H 抽出 + 逆引き索引 + スコア閾値判定し、`high` / `mid` 帯のスキル候補を `additionalContext` で注入する。`embedding.enabled` 時はプロンプトを fastembed でベクトル化してコサイン類似度を heuristic スコアに加算する。フック終了時に古い venv（72h 超）を自動撤去する |

## 動作概要

```text
[SessionStart]
  └─ build_index.py で installed_plugins.json と各 SKILL.md / evals を走査し
     index.json + inverted_index.json を生成
     （installed_plugins.json schema v1 / v2 に対応。未対応バージョンは
      警告ログを残しフェイルオープン）
     │
     └─ [embedding.enabled のとき]
        embedding_enrich が各スキルの description + use_when + skip_when +
        trigger_phrases + evals.prompt を結合して fastembed で 384 次元
        ベクトル化し、<base>/embeddings_cache/vectors.npz に保存
        （content hash で差分のみ再計算）

[UserPromptSubmit]
  └─ route.py が prompt を受け取り
     ├─ config.json の重み・閾値・embedding 設定ロード
     ├─ 逆引き索引で候補を最大 50 件に絞り込み
     ├─ keyword / trigger_phrase / eval / context / file_ext / skip_phrase でスコア計算
     ├─ [embedding.enabled のとき]
     │   embedding_route がプロンプトをベクトル化し、候補とのコサイン類似度を
     │   weight 倍して heuristic スコアに加算 → 再ソート
     ├─ top1 絶対値 + top1/top2 相対比で high / mid / low 判定
     └─ high → 確定推奨 1 件、mid → 候補上位 3 件を additionalContext に注入
```

詳細設計は本プラグインの `references/scripts/lib/` 配下の各モジュール docstring（`build_index.py` / `route.py` / `embedding_client.py` / `embedding_enrich.py` / `embedding_route.py`）を参照してください。

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

#### 対応プラットフォーム

`embedding.enabled=true` を利用する場合、`fastembed` の依存 `onnxruntime` が動作する以下のプラットフォームをサポートします。

| プラットフォーム | 状態 |
|---|---|
| Windows x86_64 | サポート |
| Linux x86_64 | サポート |
| macOS x86_64 / arm64 | サポート |
| Linux ARM64 / aarch64 | `onnxruntime` バージョンによっては wheel 未配布。動作要確認 |
| Windows ARM64 | wheel 未配布のバージョンあり。動作要確認 |

未対応プラットフォームでは `pip install` が失敗し、venv 再構築が枯渇すると埋め込み機能が無効化されます（heuristic にフェイルオープン）。`embedding.enabled=false`（既定）であれば全プラットフォームで動作します。

### E. 動作確認

```text
/router-rebuild
/router-status
```

`/router-status` でインデックス生成統計とスコア分布ヒストグラムが表示されれば導入完了です。

## 使い方

### スラッシュコマンド

```text
/router-rebuild                       # インデックスを手動再構築（embedding 有効時はベクトルも差分更新）
/router-status                        # 統計と直近の決定を表示（stats.embedding を含む）
/router-status --clean                # 30 日超のセッション履歴を削除
/router-toggle on                     # ルーティング有効化
/router-toggle off                    # ルーティング無効化（disabled フラグファイル生成）
/router-embedding-cache               # 埋め込みキャッシュ統計を表示
/router-embedding-cache --clear       # 埋め込みキャッシュを全削除
/router-embedding-cache --show <qn>   # 指定スキルのキャッシュ詳細を表示
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
| 「埋め込みキャッシュの状態を見せて」 | `/router-embedding-cache` |
| 「<plugin>:<skill> の埋め込みを確認したい」 | `/router-embedding-cache --show <qualified_name>` |

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

## 埋め込み判定（v0.4+）

スキル特定率を更に高めたい場合、**完全ローカルで動作する埋め込みベースの意味的類似度判定** をオプトインで有効化できます。外部 API には一切接続せず、データは一切送信されません。デフォルトは無効（`embedding.enabled: false`）です。

### 仕組み

| Phase | タイミング | 役割 | コスト |
|-------|-----------|------|-------|
| **SessionStart** | スキル本文を結合して fastembed で 384 次元ベクトル化し `vectors.npz` に保存。content hash で差分のみ再計算 | 初回 100 スキル ≈ 3〜10s。2 回目以降はゼロ | ローカル CPU 推論 |
| **UserPromptSubmit** | プロンプトをベクトル化し、各候補とのコサイン類似度を heuristic スコアに加算 | プロンプトあたり 30〜100ms | ローカル CPU 推論 |

**外部通信は初回モデル DL のみ**（HuggingFace ハブから）。それ以降は完全オフライン。**フェイルオープン**: fastembed 未インストール・モデル未取得・推論失敗時は heuristic のみで動作します。

### 採用ライブラリ・モデル

| 項目 | 採用 | 補足 |
|---|---|---|
| 推論バックエンド | `fastembed`（ONNX Runtime） | `torch` 不要・約 400MB |
| 既定モデル | `sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2` | 50+ 言語対応、約 120MB、384 次元 |
| 軽量代替（英語） | `BAAI/bge-small-en-v1.5` | 約 130MB |

### 設定例

`<base>/config.json` に以下を追記してください（既定値の全フィールド一覧は `references/templates/config.default.json` を参照）。

```json
{
  "embedding": {
    "enabled": true,
    "model": "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2",
    "cache_dir": null,
    "weight": 3.0,
    "min_similarity": 0.3,
    "max_skills_per_run": 200
  }
}
```

- `cache_dir` が `null` の場合は `<base>/embeddings_cache/models/` に保存
- `weight`: コサイン類似度に乗じる係数（既定 3.0）
- `min_similarity`: この値未満の類似度は加算しない（ノイズ抑制）
- `max_skills_per_run`: 1 SessionStart で再ベクトル化するスキル数の上限

### リソース消費

| 項目 | 目安 |
|---|---|
| ディスク（fastembed + onnxruntime + numpy） | 約 530MB |
| ディスク（モデル ONNX） | 約 120MB |
| メモリ（推論時） | 500MB〜1GB |
| 推論レイテンシ | 1 文 30〜100ms（CPU） |
| 初回 SessionStart 追加レイテンシ | 100 スキルで 3〜10s |
| 2 回目以降の SessionStart | 約 0s（キャッシュヒット） |
| ベクトルキャッシュサイズ | スキル 1000 件で約 1.5MB |

### オフライン環境向け（事前配置運用・推奨）

エアギャップ環境ではもちろん、ネットワークがある環境でも **モデル ONNX を事前に配置することを推奨** します。これにより、HuggingFace 側侵害・タイポスクワッティング・中間者改竄でモデル重みが意図せず差し替わるサプライチェーン攻撃のリスクをゼロに抑えられます（セキュリティレビュー H-2）。

```bash
# オンライン環境で
/router-embedding-cache --clear
/router-rebuild   # ← fastembed が自動 DL
# embeddings_cache/models/ を tar 等で持ち出してオフライン環境に配置

# 整合性確認用にモデルファイルの SHA-256 を控えておくことを推奨
sha256sum <embeddings_cache/models 配下の ONNX>
```

オフライン環境では `embedding.cache_dir` でディレクトリを直接指定できます。

#### Windows MAX_PATH（260 文字）自動フォールバック

Windows では `<base>` が深いパスにあると、HuggingFace のモデルファイル名（`models--<org>--<name>/snapshots/<sha>/<file>` で 80〜150 文字）と合算して MAX_PATH を超え `[WinError 206] ファイル名または拡張子が長すぎます` で DL が失敗します。

これを避けるため、`embedding.cache_dir` が **未指定** の場合に自動解決されるパス（`<base>/embeddings_cache/models/`）が 100 文字を超えると、自動的に以下にフォールバックします:

```text
~/AppData/Local/skill-router/models/
```

フォールバック時は `<base>/index.log` に WARNING ログが出力されます。

明示的に `embedding.cache_dir` を指定した場合は自動フォールバックは行わず、その値を尊重します。

```json
{
  "embedding": {
    "enabled": true,
    "cache_dir": "C:/sr-models"
  }
}
```

#### Windows での `--clear`

`/router-embedding-cache --clear` は内部で POSIX `rm -f` 相当を呼びます。Windows 環境では同等の PowerShell コマンドを案内します。

```powershell
Remove-Item -Force "$BASE\embeddings_cache\vectors.npz", "$BASE\embeddings_cache\manifest.json"
```

### トラブルシュート

| 症状 | 対処 |
|------|------|
| `embedding` 機能が動かない | `/router-status` の `stats.embedding` を確認。`enabled: false` の場合は config を見直す |
| キャッシュが空 | `/router-embedding-cache` で生成状況を確認。`/router-rebuild` を再実行 |
| 推論が遅い | モデルサイズを `BAAI/bge-small-en-v1.5` などに変更、または `max_skills_per_run` を絞る |
| モデル DL に失敗 | プロキシ設定・HuggingFace への到達性を確認。エアギャップなら事前配置 |
| 想定外の推奨 | `/router-embedding-cache --show <qualified_name>` で対象スキルがキャッシュにあるか確認 |

### セキュリティ

#### 通信・データ保護

- 外部 API への送信は **一切なし**（v0.3 で導入された Anthropic 連携は v0.4 で完全撤回）
- 初回モデル DL 時のみ HuggingFace ハブと通信。テレメトリは `HF_HUB_DISABLE_TELEMETRY` `DO_NOT_TRACK` 等を `embedding_client` モジュール先頭で `os.environ.setdefault` 設定済（fastembed import より前に実行）
- POSIX 環境では `vectors.npz` / `manifest.json` を `0o600` 権限で保存（Windows は ACL 制御なし）

#### キャッシュ整合性

- `manifest.json` に `vectors_sha256` を記録し、`load_vectors` で検証。`vectors.npz` が他プロセスに改竄されると不一致となり読み込みを拒否（heuristic にフォールバック）
- `manifest.json` の `schema_version` 不一致時はキャッシュ全件を破棄して安全側に倒す
- `np.load(allow_pickle=False)` 指定により pickle 経由 RCE リスクを排除
- 入力テキストは `_sanitise_input` で NUL バイト除去・8192 文字に上限カット

#### サプライチェーン

- `fastembed>=0.3,<1.0` `numpy>=1.24,<3.0` `onnxruntime>=1.17,<2.0` を `requirements.txt` で固定
- 月次の `pip-audit` 等で脆弱性を確認することを推奨
- モデル ONNX は事前配置運用（オフライン環境向けセクション参照）が最も安全。ハッシュ確認は `sha256sum` で実施

#### 悪意あるスキルからのルーティング誘導

LLM 拡張は posting 一覧を増やすだけでなく、悪意あるスキルが description / use_when / evals に意味的"釣り文句"を埋め込むことで埋め込み類似度を吊り上げ、ユーザの無関係な発話で当該スキルを `high` 推奨させる攻撃が成立しえます。

**緩和策（運用手順）:**

1. **インストール前のレビュー**: `enabledPlugins` に追加するプラグインは信頼できるソースのみに限定する
2. **定期的な棚卸し**: `~/.claude/settings.json` の `enabledPlugins` を月次で確認し、不要なプラグインを除外する
3. **拡張内容の確認**: `/router-embedding-cache --show <qualified_name>` でスキル別のキャッシュ内容を確認できます。意図と乖離した内容なら `--clear` で破棄
4. **DoS 対策**: `embedding.max_skills_per_run` は最大 10000 にクランプされ、巨大設定による SessionStart ブロックを防止

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
│   └── router-embedding-cache.md   # v0.4 埋め込みキャッシュ管理
├── hooks/
│   └── hooks.json
├── skills/
│   └── skill-router/
│       ├── SKILL.md
│       ├── README.md
│       └── evals/                # 動作分岐検証用ケース集
│           ├── README.md
│           └── case-01_*.md ... case-16_*.md
└── references/
    ├── scripts/
    │   ├── hooks/
    │   │   ├── build_index_on_start.sh
    │   │   └── route_prompt.sh
    │   ├── lib/
    │   │   ├── build_index.py        # v0.4 で embedding 統合
    │   │   ├── route.py              # v0.4 で embedding 統合
    │   │   ├── session_state.py
    │   │   ├── parse_evals.py
    │   │   ├── venv_lifecycle.py
    │   │   ├── embedding_client.py   # v0.4 fastembed ラッパー
    │   │   ├── embedding_enrich.py   # v0.4 スキルベクトル化
    │   │   └── embedding_route.py    # v0.4 コサイン類似度補助スコア
    │   ├── setup/
    │   │   └── requirements.txt      # v0.4 から fastembed + numpy + onnxruntime
    │   └── tests/                    # ユニットテスト（v0.4.2 で tests/ から移動）
    │       ├── test_build_index.py
    │       ├── test_route.py
    │       ├── test_session_state.py
    │       ├── test_parse_evals.py
    │       ├── test_venv_lifecycle.py
    │       ├── test_embedding_client.py
    │       ├── test_embedding_enrich.py
    │       └── test_embedding_route.py
    ├── spike/                    # 動作検証スクリプト（利用者は通常使用しない）
    │   ├── s1_session_id.py
    │   ├── s2_hook_concat.py
    │   ├── s3_plugin_data_var.py
    │   ├── s4_session_start_clear.py
    │   └── s5_python_startup_latency.py
    └── templates/
        └── config.default.json      # v0.4 から embedding セクション含む
```

## ライセンス

[MIT License](LICENSE) の下で配布されています。
