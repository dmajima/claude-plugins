# 環境構築（projectboard スキル）

projectboard スキルの実行前提と venv 構築・削除手順。

## 前提ツール

| ツール | 用途 | 必須 |
|------|------|------|
| bash (Git Bash) | references/scripts/ 配下のシェルスクリプト実行 | 必須 |
| curl | ProjectBoard API 呼び出し | 必須 |
| jq | JSON 整形・リクエストボディ構築 | 必須 |
| python 3.9+ | urlKey 変換・CSV 整形・スケジュール解析・**WebSocket+STOMP 接続**（書き込み時） | 必須 |

## 依存パッケージ

**projectboard 自体の外部 PyPI 依存はゼロ**（標準ライブラリのみで完結 — ADR-2）。
venv はプラグイン共通（ADR-024）のため、`plugins/connector/references/scripts/setup/requirements.txt`
（全スキルの依存を統合。ailead 用の `requests` を含む）でまとめて構築する。

> **書き込み時の WebSocket 接続**: `references/scripts/write/stomp_session.py` が Python 標準ライブラリ
> （socket / ssl）のみで SockJS+STOMP の WebSocket 接続を実装している（外部 WebSocket ライブラリ不要）。
> 書き込み API は connectionId が「生きた接続」であることを要求するため、書き込みは必ず
> stomp_session.py 経由で実行する（[api-write.md](api-write.md) セクション 1.2）。

## venv 構築

```bash
# WORK_DIR はセッション作業領域（.claude/.local/work/{session}/workspace）
bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/setup_venv.sh" "$WORK_DIR"
```

venv は `$WORK_DIR/.venv` に作成される。Python スクリプトは venv の python を明示指定して実行する:

```bash
# Windows
"$WORK_DIR/.venv/Scripts/python.exe" "${CLAUDE_SKILL_DIR}/references/scripts/resolve/urlkey.py" <urlKey>
# Unix
"$WORK_DIR/.venv/bin/python" "${CLAUDE_SKILL_DIR}/references/scripts/resolve/urlkey.py" <urlKey>
```

> **PowerShell ツール経由で起動する場合（例外運用）**: Windows + PowerShell ツールでは Python 子プロセスがハングする既知事象があるため、直接 `&` 起動せずプラグイン共通の Start-Job ラッパーを使用する（グローバルルール `python-subprocess-hang-windows.md`）。通常の Bash ツール経由では上記の直接実行でよい。
>
> ```bash
> bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/run_via_job.sh" \
>   "$WORK_DIR/.venv/Scripts/python.exe" "${CLAUDE_SKILL_DIR}/references/scripts/resolve/urlkey.py" <urlKey>
> ```

## venv 削除

```bash
bash "${CLAUDE_PLUGIN_ROOT}/references/scripts/setup/teardown_venv.sh" "$WORK_DIR"
```

## 機密ファイルの後始末（必須）

操作完了後、`$WORK_DIR` に生成された Cookie・取得 JSON を削除する:

```bash
bash "${CLAUDE_SKILL_DIR}/references/scripts/cleanup/cleanup_sensitive.sh" "$WORK_DIR"
```

削除対象: `cookies.txt`（SESSION / XSRF-TOKEN を含む）・`pb_*.json`・`pb_*.csv`・`*.har`。
成果物として残す CSV / レポートは削除前にセッションフォルダ直下へ移動しておくこと。
