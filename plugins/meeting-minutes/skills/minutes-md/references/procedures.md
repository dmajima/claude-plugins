# Markdown 出力手順

## 前提

- `minutes-composer` が `workspace/minutes.json` を出力済みであること
- [`setup.md`](setup.md) の手順で venv が構築済みであること

## 手順

### 1. Markdown 生成

```bash
& chcp.com 65001 | Out-Null
[Console]::InputEncoding = [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

& $venvPy "$CLAUDE_SKILL_DIR\scripts\output\generate_md.py" \
  --input "$SESSION_DIR\workspace\minutes.json" \
  --output "$SESSION_DIR\minutes.md"
```
## トラブルシューティング

| 問題 | 対処 |
|------|------|
| `minutes.json` が見つからない | `workspace/minutes.json` の存在を確認。minutes-composer が完了しているか確認 |
| 日本語が文字化けする | `generate_md.py` 先頭の `sys.stdout.reconfigure` を確認 |
| 出力内容が空 | `minutes.json` の内容を確認（`agendas` 配列が空でないか） |
