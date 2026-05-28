# hooks-fallback — PowerShell フォールバック版 hooks.json

`hooks/hooks.json` は通常運用の **Bash 起動版** を配置している。
本ディレクトリの `hooks.ps1.json` は、Git Bash 不調時等に PowerShell 起動へ
切り替えるためのフォールバック設定。

## 切り替え手順

```bash
# Bash → PowerShell へ切替
cp references/hooks-fallback/hooks.ps1.json hooks/hooks.json
# Claude Code を再起動して hooks.json を再読込
```

PowerShell 強制モードへの全体切り替えは
`~/.claude/rules/tools/powershell-fallback-mode.md` を参照。

## 復帰手順

```bash
# PowerShell → Bash へ復帰（git の HEAD から復元）
git checkout HEAD -- hooks/hooks.json
# または
cp references/hooks-fallback/hooks.bash.json.template hooks/hooks.json
```

## 動作等価性の保証

Bash 起動の `*.sh` と PowerShell 起動の `*.ps1` は、`tests/parity/run_all.sh`
で同じ入力に対して同じ観測結果を返すことが自動検証される。
