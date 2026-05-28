# Parity Test Framework

Bash 実装と PowerShell 実装の動作等価性を自動検証するための共通基盤。

## 概要

7 プラグインの `.ps1` スクリプトを Bash 純粋実装 (`.sh`) に置き換える過程で、
**同じ入力に対して同じ観測結果を返すこと** を機械的に検証する。

ゴールデンマスター方式 + 5 軸比較 + 正規化レイヤを採用する。

## 比較軸

| 軸 | 比較対象 |
|----|---------|
| stdout | 正規化後のテキスト diff |
| stderr | 正規化後のテキスト diff |
| exit code | 数値比較 |
| ファイルシステム | `find + sha256` のツリーハッシュ diff |
| 環境状態 | CWD / 露出環境変数（必要に応じてケース側で指定） |

## ディレクトリ構成

```
tests/parity/
├── run_all.sh                    全プラグイン横断ランナー
├── lib/
│   ├── sandbox.sh                サンドボックスディレクトリ管理
│   ├── path.sh                   Windows / Unix パス変換
│   ├── capture.sh                stdout/stderr/exit のキャプチャ
│   ├── normalize.sh              テキスト正規化（CRLF / TS / パス / UUID 等）
│   ├── fs_snapshot.sh            find + sha256 によるツリーハッシュ
│   ├── json_canon.sh             jq -S による JSON canonical 化
│   └── driver.sh                 テスト実行コア（parity_run_case）
├── fixtures/common/              プラグイン横断 fixture
└── README.md                     本ファイル

plugins/{plugin}/tests/parity/
├── run.sh                        プラグイン単独ランナー（lib を source）
├── cases/                        1 ケース = 1 .case ファイル
├── fixtures/                     プラグイン固有 fixture
└── golden/                       期待出力スナップショット（必要な場合）
```

## ケース DSL

各テストケースは `cases/<id>.case` という Bash 変数定義ファイル。

```bash
# cases/020_toggle_off_creates_flag.case
ID="toggle_off_creates_flag"
SCRIPT_PS_REL="plugins/skill-router/references/scripts/commands/toggle.ps1"
SCRIPT_BASH_REL="plugins/skill-router/references/scripts/commands/toggle.sh"
ARGS=("off")
STDIN_FILE=""
ENV_VARS=(
  "CLAUDE_PLUGIN_DATA=__SANDBOX__/data"
  "HOME=__SANDBOX__/home"
)
PRE_FS="plugins/skill-router/tests/parity/fixtures/toggle/empty"
POST_FS_INCLUDE=("__SANDBOX__/data" "__SANDBOX__/home/.claude")
NORMALIZE=("crlf" "timestamps" "abs_paths")
HOOK_JSON="false"
SKIP_BASH=""               # 値があれば Bash 比較スキップ + 理由
SKIP_PS=""                 # 値があれば PS 比較スキップ + 理由
COMPARE_STDOUT="true"
COMPARE_STDERR="true"
COMPARE_FS="true"
COMPARE_EXIT="true"
```

`__SANDBOX__` プレースホルダはランナーが `mktemp -d` で確保した一時ディレクトリの
絶対パスに置換される。`HOME` / `USERPROFILE` / `CLAUDE_PLUGIN_ROOT` 等は
すべてここに閉じ込められる。

## 利用可能な正規化ルール（NORMALIZE 配列）

| ルール | 効果 |
|--------|------|
| `crlf` | CRLF → LF |
| `trailing_ws` | 行末空白除去 |
| `timestamps` | ISO 8601 / `yyyyMMdd_NN_` を `<TS>` / `<SESSION>_` に畳む |
| `abs_paths` | サンドボックスパス（Unix / Windows 両形式）を `<SANDBOX>` に畳み、`\` を `/` に正規化 |
| `uuid` | UUID を `<UUID>` に畳む |
| `pid` | `pid=12345` を `pid=<PID>` に畳む |
| `python_trace` | Python トレースバックの絶対パスを `<PY>` に畳む |
| `git_sha` | 40 桁 / commit SHA を `<SHA>` に畳む |
| `json` | jq -S によるキーソート（stdout のみ、`HOOK_JSON=true` で自動付与） |

## 実行コマンド

```bash
# 全プラグイン
bash tests/parity/run_all.sh

# 1 プラグインのみ
bash tests/parity/run_all.sh skill-router

# プラグイン単独ランナー直接実行
bash plugins/skill-router/tests/parity/run.sh

# 単一ケース
bash plugins/skill-router/tests/parity/run.sh 020_toggle_off_creates_flag

# Self-check（PS↔PS / Bash↔Bash の連続実行で揺らぎ検出）
bash tests/parity/run_all.sh --self-check
```

## 終了コード

| Code | 意味 |
|------|------|
| 0 | 全 PASS（SKIP は許容） |
| 1 | 1 件以上 FAIL |

## PowerShell 専用ツールの扱い

`run_psscriptanalyzer.ps1` / `setup_psmodule.ps1` のように Bash 純粋実装が原理的に
不可能なスクリプトは、ケース側で `SKIP_BASH="psmodule_required"` 等の理由を
明示する。ランナー終了時に SKIP 件数と理由が集計される。

代わりに Bash 側は `pwsh -NoProfile -File <.ps1> "$@"` の 1 行プロキシ `.sh` を
提供し、その I/O のみを通常通り parity 比較する。

## 自己検証（基盤の sanity check）

`tests/parity/lib/` 自体の動作確認は、プラグイン未実装の段階でも次のコマンドで可能:

```bash
bash tests/parity/run_all.sh
# → 0 plugins, 0 cases (nothing to verify yet) 出力されれば OK
```

プラグイン側 `.case` 実装後は、`bash tests/parity/run_all.sh` が常に 0 で終了する
ことを各コミットで確認する。
