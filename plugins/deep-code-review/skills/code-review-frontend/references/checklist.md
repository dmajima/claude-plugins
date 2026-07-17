# code-review-frontend 達成チェックリスト

`code-review-frontend` 観点別スキルが **中間レポートを返却する前** に通過すべきルール群。
ID 体系・SSOT は `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` を参照。

> **確認タイミング**: web-designer エージェントの結果統合後、オーケストレーターへの返却前。
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
[ ] (O1)  web-designer エージェントを起動している（単独）
[ ] (O2)  SKILL.md「出力フォーマット」セクションに従って中間レポートを返している
[ ] (O4)  バックエンド実装・API 設計・XSS 重点レビュー・E2E テスト実行はスコープ外として明示している
[ ] (O5)  各指摘・改善提案にスコープ内/外フラグを付与している
[ ] (O6)  プロジェクト規約（CLAUDE.md / .claude/rules/ / .stylelintrc / .eslintrc / 既存デザインシステム）を最優先評価基準にし根拠に引用している
[ ] (O8)  オーケストレーター不在で単独実行された場合、本スキル自身で progress.md を作成・維持している
[ ] (O9)  Finding ID（CR-NNN）を自スキルで採番していない（採番はオーケストレーター責務）
[ ] (O10) language-profiles 引数（未受領時は language-detection.md で自己検出）に基づき、検出言語・FW の観点プロファイル（languages/ / frameworks/）をエージェントプロンプトに含めている。未対応言語は制約事項に明記
```

> **注**: 本スキルには動的検証エージェントがないため O3 / O7 は適用外。

---

## C. 中間レポート出力チェック

```bash
# C-Auto-1: 必須セクションが揃っているか
required_sections=(
  "^## フロントエンド観点レビュー結果"
  "^### web-designer"
)
for sec in "${required_sections[@]}"; do
  echo "$REPORT" | grep -qE "$sec" || echo "MISSING: $sec"
done

# C-Auto-2: 観点項目（HTML / CSS / アクセシビリティ / レスポンシブ / Vue/Liquid/JS）の網羅性
required_items=("HTML" "CSS" "アクセシビリティ|WCAG" "レスポンシブ" "Vue|Liquid|JS")
for item in "${required_items[@]}"; do
  echo "$REPORT" | grep -qE "$item" || echo "WARN: 観点未言及: $item"
done

# C-Auto-3: スコープ外指摘の混入（バックエンド・API・E2E 等）
echo "$REPORT" | grep -qE "API.*設計|バックエンド|E2E.*実行" \
  && echo "WARN: スコープ外（バックエンド/API/E2E）の言及あり。スコープ外フラグ付与または削除を検討"

# C-Auto-4: 別 PR 推奨文言の混入
banned=("別.*PR.*対応" "別途.*PR.*起票" "別チケット" "Issue を作成" "Work Item を作成")
for pat in "${banned[@]}"; do
  echo "$REPORT" | grep -qE "$pat" && echo "BANNED: $pat"
done
```

---

## D. 未通過時の対応

| 未通過 ID | 対応 |
|----------|------|
| O1 | web-designer エージェントを再起動 |
| O2 | 出力フォーマットを SKILL.md に揃えてレポート再生成 |
| O4 | バックエンド・API・E2E 等のスコープ外項目を中間レポートから除外 |
| O5 | 各指摘にスコープ内/外フラグを付与 |
| O6 | プロジェクト規約・デザインシステムを再読込し、指摘の根拠を更新 |
| U7 / U8 | 該当文言を削除 / スコープ外フラグに変更 |

---

## E. 関連リファレンス

- `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` — 全スキルのルール ID 体系
- `${CLAUDE_PLUGIN_ROOT}/references/agents.md` — エージェント選定・プロンプト構成
- `${CLAUDE_PLUGIN_ROOT}/references/severity-ranking.md` — 重要度付与・重複統合
- `${CLAUDE_PLUGIN_ROOT}/references/scope-out-policy.md` — 別 PR 推奨禁止 / PR 外影響禁止
- `${CLAUDE_SKILL_DIR}/SKILL.md` — 本スキルの実行フロー・出力フォーマット
