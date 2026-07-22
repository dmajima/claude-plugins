# code-review-architecture 達成チェックリスト

`code-review-architecture` 観点別スキルが **中間レポートを返却する前** に通過すべきルール群。
ID 体系・SSOT は `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` を参照。

> **確認タイミング**: 内部 1〜2 エージェント（architect / dba）の結果統合後、オーケストレーターへの返却前。
> **未通過時**: 該当項目を解消してから返却する。

---

## A. Universal ルール（全スキル共通）

> 規範本文・達成基準は **`${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md`** を参照（プラグイン内 SSOT）。
> 適用範囲は `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` セクション8 を参照。

上記 SSOT（`${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` の U マップ表）の U1〜U16 全項目の通過を確認する（各 U の 1 行要約・達成基準は同ファイルおよび `universal-rules-{environment,process,quality}.md` を参照）。

---

## B. Observation ルール（観点別レビュースキル共通）

```
[ ] (O1)  該当エージェント（architect, DB変更ある場合のみ dba）を 1 メッセージ内で並列起動している
[ ] (O2)  SKILL.md「出力フォーマット」セクションに従って中間レポートを返している
[ ] (O4)  実装一般・テスト・セキュリティ・UI 観点はスコープ外として対応スキルへ誘導している
[ ] (O5)  各指摘・改善提案にスコープ内/外フラグを付与している
[ ] (O6)  プロジェクト規約（CLAUDE.md / docs/ 配下の設計ドキュメント等）を最優先評価基準にし根拠に引用している
[ ] (O8)  オーケストレーター不在で単独実行された場合、本スキル自身で progress.md を作成・維持している
[ ] (O9)  Finding ID（CR-NNN）を自スキルで採番していない（採番はオーケストレーター責務）
[ ] (O10) language-profiles 引数（未受領時は language-detection.md で自己検出）に基づき、検出言語・FW の観点プロファイル（languages/ / frameworks/）をエージェントプロンプトに含めている。未対応言語は制約事項に明記
```

> **注**: 本スキルには動的検証エージェントがないため O3 / O7 は適用外。

---

## C. 中間レポート出力チェック

返却前に以下を検証する（ランタイム自動実行はしない。ルール ID 判定は A/B 節が担う）:

- **C-Auto-1**: 必須セクション（`## アーキテクチャ観点レビュー結果` / `### architect`）が揃っている
- **C-Auto-2**: DB 変更（`.sql` / `.csproj` / `migrations`）検出時に `### dba` セクションが存在する
- **C-Auto-3**: dba 省略時にその理由（DB 変更なし等）が明示されている
- **C-Auto-4**: 別 PR 推奨・Issue/Work Item 起票等の禁止文言が混入していない（U8）

---

## D. 未通過時の対応

| 未通過 ID | 対応 |
|----------|------|
| O1 | dba 起動条件を再判定し、必要なら architect + dba を並列再実行 |
| O2 | 出力フォーマットを SKILL.md に揃えてレポート再生成 |
| O4 | スコープ外観点（実装一般・テスト等）を中間レポートから除外し対応スキルへ誘導 |
| O5 | 各指摘にスコープ内/外フラグを付与 |
| O6 | プロジェクト規約を再読込し、指摘の根拠を更新 |
| U7 / U8 | 該当文言を削除 / スコープ外フラグに変更 |

---

## E. 関連リファレンス

- `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` — 全スキルのルール ID 体系
- `${CLAUDE_PLUGIN_ROOT}/references/agents.md` — エージェント選定・プロンプト構成
- `${CLAUDE_PLUGIN_ROOT}/references/severity-ranking.md` — 重要度付与・重複統合
- `${CLAUDE_PLUGIN_ROOT}/references/scope-out-policy.md` — 別 PR 推奨禁止 / PR 外影響禁止
- `${CLAUDE_SKILL_DIR}/SKILL.md` — 本スキルの実行フロー・出力フォーマット
