# 環境構築（projectboard スキル）

projectboard スキルの実行前提と venv 構築・削除手順。

## 前提ツール

| ツール | 用途 | 必須 |
|------|------|------|
| bash (Git Bash) | scripts/ 配下のシェルスクリプト実行 | 必須 |
| curl | ProjectBoard API 呼び出し | 必須 |
| jq | JSON 整形・リクエストボディ構築 | 必須 |
| python 3.9+ | urlKey 変換・CSV 整形・スケジュール解析・**WebSocket+STOMP 接続**（書き込み時） | 必須 |

## 依存パッケージ

**外部 PyPI 依存はゼロ**（標準ライブラリのみで完結 — ADR-2）。
`scripts/setup/requirements.txt` は空（コメントのみ）だが、python-venv ルール準拠のため
venv 構築手順は他スキルと同一に維持する。

> **書き込み時の WebSocket 接続**: `scripts/write/stomp_session.py` が Python 標準ライブラリ
> （socket / ssl）のみで SockJS+STOMP の WebSocket 接続を実装している（外部 WebSocket ライブラリ不要）。
> 書き込み API は connectionId が「生きた接続」であることを要求するため、書き込みは必ず
> stomp_session.py 経由で実行する（[api-write.md](api-write.md) セクション 1.2）。

## venv 構築

```bash
# WORK_DIR はセッション作業領域（.claude/.local/work/{session}/workspace）
bash "${CLAUDE_SKILL_DIR}/scripts/setup/setup_venv.sh" "$WORK_DIR"
```

venv は `$WORK_DIR/.venv` に作成される。Python スクリプトは venv の python を明示指定して実行する:

```bash
# Windows
"$WORK_DIR/.venv/Scripts/python.exe" "${CLAUDE_SKILL_DIR}/scripts/resolve/urlkey.py" <urlKey>
# Unix
"$WORK_DIR/.venv/bin/python" "${CLAUDE_SKILL_DIR}/scripts/resolve/urlkey.py" <urlKey>
```

## venv 削除

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/setup/teardown_venv.sh" "$WORK_DIR"
```

## 機密ファイルの後始末（必須）

操作完了後、`$WORK_DIR` に生成された Cookie・取得 JSON を削除する:

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/setup/cleanup_sensitive.sh" "$WORK_DIR"
```

削除対象: `cookies.txt`（SESSION / XSRF-TOKEN を含む）・`pb_*.json`・`pb_*.csv`・`*.har`。
成果物として残す CSV / レポートは削除前にセッションフォルダ直下へ移動しておくこと。
