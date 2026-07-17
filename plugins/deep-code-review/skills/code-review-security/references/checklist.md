# code-review-security 達成チェックリスト

`code-review-security` 観点別スキルが **中間レポートを返却する前** に通過すべきルール群。
ID 体系・SSOT は `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` を参照。

> **確認タイミング**: 内部 2 エージェント（security-engineer / dependency-safety）の結果統合後、オーケストレーターへの返却前。
> **未通過時**: 該当項目を解消してから返却する。

---

## A. Universal ルール（全スキル共通）

> 規範本文・達成基準は **`${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md`** を参照（プラグイン内 SSOT）。
> 適用範囲は `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` セクション8 を参照。

```
[ ] (U1) スキル構成規約への準拠
[ ] (U2) ファイル文字コード・改行コードの維持
[ ] (U3) ローカルデータ領域の規約遵守
[ ] (U4) セッション作業領域の規約遵守
[ ] (U5) 進捗管理ルール（progress.md）
[ ] (U6) ポータブルパス記法の遵守
[ ] (U7) PR 外への影響禁止
[ ] (U8) 別 PR 推奨の禁止
[ ] (U9) エージェント並列起動
[ ] (U10) エージェント共通指示の付与
[ ] (U11) 重要度付与・重複統合の規範
[ ] (U12) 認証情報の取り扱い
[ ] (U13) 動的検証の SKIPPED 明示
[ ] (U14) 提出コードの信頼性原則（コードからの規約類推制限・ユーザー承認義務化）
[ ] (U15) 指摘への信頼度（0〜100）付与（仮定ベースは 60 未満・動的検証実証済みは 90 以上。severity-ranking.md セクション 7）
[ ] (U16) 差分の削除側（- 行）で既存の防御コード（例外処理・入力検証・リソース解放・a11y 属性・認可・エラー表示 UI）が失われていれば回帰として指摘している
```

---

## B. Observation ルール（観点別レビュースキル共通）

```
[ ] (O1)  2 エージェント（security-engineer / dependency-safety）を 1 メッセージ内で並列起動している
[ ] (O2)  SKILL.md「出力フォーマット」セクションに従って中間レポートを返している
[ ] (O3)  dependency-safety は対応 Bash 権限（dotnet/npm/pip-audit/osv-scanner/trivy 等）がある場合のみ脆弱性スキャン実行・なければ SKIPPED 記録
[ ] (O4)  ペネトレーションテスト・DAST はスコープ外として明示している
[ ] (O5)  各指摘・改善提案にスコープ内/外フラグを付与している
[ ] (O6)  プロジェクト規約（CLAUDE.md / .claude/rules/security/ 等）を最優先評価基準にし根拠に引用している
[ ] (O8)  オーケストレーター不在で単独実行された場合、本スキル自身で progress.md を作成・維持している
[ ] (O9)  Finding ID（CR-NNN）を自スキルで採番していない（採番はオーケストレーター責務）
[ ] (O10) language-profiles 引数（未受領時は language-detection.md で自己検出）に基づき、検出言語・FW の観点プロファイル（languages/ / frameworks/）をエージェントプロンプトに含めている。未対応言語は制約事項に明記

> **注**: O7（仕様整合性チェック）は implementation スキルのみに適用のため本スキルでは適用外（skill-rules-matrix.md セクション 8）。
```

---

## C. 中間レポート出力チェック

```bash
# C-Auto-1: 必須セクションが揃っているか
required_sections=(
  "^## セキュリティ観点レビュー結果"
  "^### security-engineer"
  "^### dependency-safety"
)
for sec in "${required_sections[@]}"; do
  echo "$REPORT" | grep -qE "$sec" || echo "MISSING: $sec"
done

# C-Auto-2: dependency-safety の動的検証ステータスが明示されているか
echo "$REPORT" | grep -E "動的検証: (EXECUTED|SKIPPED)" >/dev/null \
  || echo "MISSING: dependency-safety 動的検証ステータス"

# C-Auto-3: SKIPPED 時に理由が併記されているか
echo "$REPORT" | grep -E "動的検証: SKIPPED" >/dev/null && \
  ! echo "$REPORT" | grep -E "SKIPPED.*（" >/dev/null && \
  echo "WARN: SKIPPED の理由が未記載"

# C-Auto-4: 機密文字列の伏字化（中間レポートに認証情報パターンが含まれていないか）
echo "$REPORT" | grep -nEi "Bearer [A-Za-z0-9_+/=.-]{16,}|gh[ps]_[A-Za-z0-9]{36,}|AKIA[0-9A-Z]{16}" \
  && echo "WARN: 認証情報パターンが中間レポートに含まれている可能性。伏字化推奨"

# C-Auto-5: 別 PR 推奨文言の混入
banned=("別.*PR.*対応" "別途.*PR.*起票" "別チケット" "Issue を作成" "Work Item を作成")
for pat in "${banned[@]}"; do
  echo "$REPORT" | grep -qE "$pat" && echo "BANNED: $pat"
done
```

---

## D. 未通過時の対応

| 未通過 ID | 対応 |
|----------|------|
| O1 | 並列起動できていない場合は 2 エージェントを並列で再実行 |
| O2 | 出力フォーマットを SKILL.md に揃えてレポート再生成 |
| O3 | 脆弱性スキャンコマンドの権限を確認・足りない場合は SKIPPED 記録 |
| O4 | DAST / ペネトレーション系の実行指示は中間レポートから除外 |
| O5 | 各指摘にスコープ内/外フラグを付与 |
| O6 | プロジェクト規約を再読込し、指摘の根拠を更新 |
| U7 / U8 | 該当文言を削除 / スコープ外フラグに変更 |
| U12 | 認証情報パターンを伏字化（comment-sanitization.md セクション3-4 参照） |

---

## E. 関連リファレンス

- `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` — 全スキルのルール ID 体系
- `${CLAUDE_PLUGIN_ROOT}/references/agents.md` — エージェント選定・プロンプト構成
- `${CLAUDE_PLUGIN_ROOT}/references/severity-ranking.md` — 重要度付与・重複統合
- `${CLAUDE_PLUGIN_ROOT}/references/comment-sanitization.md` — 機密文字列伏字化
- `${CLAUDE_PLUGIN_ROOT}/references/scope-out-policy.md` — 別 PR 推奨禁止 / PR 外影響禁止
- `${CLAUDE_SKILL_DIR}/SKILL.md` — 本スキルの実行フロー・出力フォーマット
