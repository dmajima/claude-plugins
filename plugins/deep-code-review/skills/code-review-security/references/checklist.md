# code-review-security 達成チェックリスト

`code-review-security` 観点別スキルが **中間レポートを返却する前** に通過すべきルール群。
ID 体系・SSOT は `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` を参照。

> **確認タイミング**: 内部 2 エージェント（security-engineer / dependency-safety）の結果統合後、オーケストレーターへの返却前。
> **未通過時**: 該当項目を解消してから返却する。

---

## A. Universal ルール（全スキル共通）

> 規範本文・達成基準は **`${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md`** を参照（プラグイン内 SSOT）。
> 適用範囲は `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` セクション8 を参照。

上記 SSOT（`${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` の U マップ表）の U1〜U16 全項目の通過を確認する（各 U の 1 行要約・達成基準は同ファイルおよび `universal-rules-{environment,process,quality}.md` を参照）。

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

返却前に以下を検証する（ランタイム自動実行はしない。ルール ID 判定は A/B 節が担う）:

- **C-Auto-1**: 必須セクション（`## セキュリティ観点レビュー結果` / `### security-engineer` / `### dependency-safety`）が揃っている
- **C-Auto-2**: dependency-safety の動的検証ステータス（`動的検証: EXECUTED|SKIPPED`）が明示されている
- **C-Auto-3**: SKIPPED 時に理由が併記されている（U13）
- **C-Auto-4**: 中間レポートに認証情報パターン（`Bearer ...` / `gh[ps]_...` / `AKIA...` 等）が含まれていない（含む場合は伏字化・U12）
- **C-Auto-5**: 別 PR 推奨・Issue/Work Item 起票等の禁止文言が混入していない（U8）

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
