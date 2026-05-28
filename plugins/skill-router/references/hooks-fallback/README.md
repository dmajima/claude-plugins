# hooks-fallback — PowerShell フォールバック版 hooks.json

`hooks/hooks.json` は通常運用の **Bash 起動版** を配置。本ディレクトリの
`hooks.ps1.json` は Git Bash 不調時のフォールバック設定。

切り替え:

```bash
cp references/hooks-fallback/hooks.ps1.json hooks/hooks.json
# Claude Code を再起動
```

詳細手順は `~/.claude/rules/tools/powershell-fallback-mode.md` を参照。
