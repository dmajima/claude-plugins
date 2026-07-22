# env-setup 達成チェックリスト

`env-setup` スキルが **完了報告を返却する前** に通過すべきルール群。
ID 体系・SSOT は `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` を参照。

> **確認タイミング**: 確認モード or インストールモードの完了直前。
> **未通過時**: 該当項目を解消してから報告する。

---

## A. Universal ルール（全スキル共通）

> 規範本文・達成基準は **`${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md`** を参照（プラグイン内 SSOT）。
> 適用範囲は `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` セクション8 を参照。

本スキルに適用される Universal ルールは **U1〜U8 / U12〜U16**（一覧・達成基準は `${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` の U マップ表）。**U9 / U10 / U11 は本スキル適用外**（`skill-rules-matrix.md` セクション8 脚注）。U15（信頼度付与）・U16（防御コード削除の回帰検出）はレビュー指摘生成・コード差分評価を行う場合のみ適用（本スキルは通常それらを行わないため実質対象外）。

---

## B. Environment ルール（環境構築スキル固有）

```
[ ] (E1)  明示指示なしの場合は確認モード（存在確認のみ）で動作している
[ ] (E2)  インストール実行前に AskUserQuestion でユーザー承認を取っている
[ ] (E3)  管理者権限が必要な場合、自動昇格せず実行コマンドをユーザーに提示している
[ ] (E4)  インストール優先順位（winget → ツール固有サブコマンド → MSI/EXE）を遵守している
[ ] (E5)  個別スキル経由の独自インストール（winget / npm install -g 等）が発生していない
[ ] (E6)  新規ツール追加時は references/tools-catalog.md を更新している
```

---

## C. 完了報告チェック

```bash
# C-Auto-1: 必須セクションが揃っているか
required_sections=(
  "^## env-setup 結果"
  "^### 既にインストール済み|^### インストール実行|^### インストール失敗"
)
for sec in "${required_sections[@]}"; do
  echo "$REPORT" | grep -qE "$sec" || echo "MISSING: $sec"
done

# C-Auto-2: インストール失敗時に対処方針が明記されているか
echo "$REPORT" | grep -qE "^### インストール失敗" \
  && (echo "$REPORT" | grep -qE "^### 推奨アクション|要対応" \
      || echo "WARN: インストール失敗時の推奨アクションが未記載")

# C-Auto-3: 認証情報の値が含まれていないか
echo "$REPORT" | grep -nEi "(password|token|secret|api[_-]?key)[[:space:]]*[:=][[:space:]]*[^[:space:]\"'<>]+" \
  && echo "ERROR: 認証情報の値が完了報告に含まれている可能性"

# C-Auto-4: 自動昇格の禁止確認（実行ログに sudo/runas が含まれていないか）
history 2>/dev/null | grep -qE "sudo |Start-Process.*-Verb RunAs|runas " \
  && echo "ERROR: 管理者権限への自動昇格が実行された可能性（E3 違反）"
```

---

## D. 未通過時の対応

| 未通過 ID | 対応 |
|----------|------|
| E1 | 確認モードへ切り替えて再実行（インストールはユーザー承認後のみ） |
| E2 | AskUserQuestion で承認を取得してから再実行 |
| E3 | 管理者昇格が必要なコマンドはユーザーに案内し、自動実行を中止 |
| E4 | winget で再試行 → 失敗時のみ次の優先度（dotnet tool / npm -g）へ |
| E5 | 他スキルの独自インストールを禁止し、本スキル経由に統合する旨をユーザー報告 |
| E6 | tools-catalog.md に追加してから運用継続 |

---

## E. 関連リファレンス

- `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` — 全スキルのルール ID 体系
- `${CLAUDE_SKILL_DIR}/references/tools-catalog.md` — 管理対象ツールの詳細カタログ
- `${CLAUDE_SKILL_DIR}/SKILL.md` — 本スキルの実行フロー・実行モード判定
