---
description: skill-router の有効化／無効化を切り替える
argument-hint: "<on|off>"
---

ユーザの引数: $ARGUMENTS

`skill-router` のルーティング動作を即時に切り替えます。`<base>/disabled` フラグファイルの作成・削除で実現するため、Claude Code の再起動なしで反映されます（設計書 v2 セクション 7）。

## 動作モード

| 引数 | 動作 |
|-----|------|
| `on` | `<base>/disabled` を削除（存在すれば）し、ルーティングを有効化 |
| `off` | `<base>/disabled` を作成し、ルーティングを無効化 |
| 空 / その他 | 現在の状態（ON/OFF）を表示し、引数 `on` / `off` のいずれかを指定するよう案内 |

## base ディレクトリ解決

```text
1. CLAUDE_PLUGIN_DATA （定義され書込可能なら最優先）
2. <repo-root>/.claude/.local/plugins/skill-router/
3. <user-home>/.claude/.local/plugins/skill-router/
```

`<user-home>` は Bash で `HOME_DIR="${HOME:-${USERPROFILE:-}}"` として解決します（Windows 互換のため `USERPROFILE` フォールバック付き、credentials-manager と統一）。書き込み先は **解決順位の 1 番目** を使用します（`route_prompt.sh` のトグル参照順位と一致）。

## 実行手順

### 状態確認（引数なし時）

```bash
HOME_DIR="${HOME:-${USERPROFILE:-}}"
if [[ -n "${CLAUDE_PLUGIN_DATA:-}" && -f "${CLAUDE_PLUGIN_DATA}/disabled" ]] || \
   [[ -f "${PWD}/.claude/.local/plugins/skill-router/disabled" ]] || \
   [[ -n "${HOME_DIR}" && -f "${HOME_DIR}/.claude/.local/plugins/skill-router/disabled" ]]; then
  echo "skill-router: OFF"
else
  echo "skill-router: ON"
fi
```

### 無効化（`off`）

```bash
HOME_DIR="${HOME:-${USERPROFILE:-}}"
if [[ -n "${CLAUDE_PLUGIN_DATA:-}" ]]; then
  BASE="${CLAUDE_PLUGIN_DATA}"
elif [[ -d "${PWD}/.claude" ]]; then
  BASE="${PWD}/.claude/.local/plugins/skill-router"
else
  BASE="${HOME_DIR}/.claude/.local/plugins/skill-router"
fi
mkdir -p "${BASE}"
touch "${BASE}/disabled"
echo "skill-router toggled OFF (flag: ${BASE}/disabled)"
```

### 有効化（`on`）

```bash
HOME_DIR="${HOME:-${USERPROFILE:-}}"
for BASE in \
    "${CLAUDE_PLUGIN_DATA:-}" \
    "${PWD}/.claude/.local/plugins/skill-router" \
    "${HOME_DIR}/.claude/.local/plugins/skill-router"; do
  if [[ -n "${BASE}" && -f "${BASE}/disabled" ]]; then
    rm -f "${BASE}/disabled"
    echo "skill-router: removed disabled flag at ${BASE}/disabled"
  fi
done
echo "skill-router toggled ON"
```

## 提示する内容

- 切替前後の状態（ON / OFF）
- 操作したフラグファイルパス
- 補足: 「`route_prompt.sh` は次回プロンプト送信時から新状態で動作」

## 失敗時

- 書込権限エラーの場合はパスをユーザに提示し、別 base ディレクトリでの実行を提案する。
- `off` を複数回連続実行した場合はべき等（既存フラグを上書き）。
- `on` を複数回連続実行した場合もべき等（フラグ不在ならスキップ）。

## 補足

- 再有効化は `on` 引数だけでなく、対応する `disabled` ファイルを直接削除しても可能。
- 永続的に無効化したい場合は `~/.claude/settings.json` の `enabledPlugins` から `skill-router@dmajima-claude-plugins` を外す方が確実。
