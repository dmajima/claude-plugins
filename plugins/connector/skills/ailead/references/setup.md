# 環境構築

## venv 構築

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/setup/setup_venv.sh" "$SESSION_DIR/workspace"
```

- venv は `$SESSION_DIR/workspace/.venv/` に作成される
- `requirements.txt` に定義された依存パッケージが自動インストールされる

## 依存パッケージ

| パッケージ | バージョン | 用途 |
|-----------|----------|------|
| `requests` | >=2.31.0 | HTTP リクエスト（HTML取得・GraphQL API呼び出し） |

## venv 削除

```bash
bash "${CLAUDE_SKILL_DIR}/scripts/setup/teardown_venv.sh" "$SESSION_DIR/workspace"
```
