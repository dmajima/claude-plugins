# code-review-spec-inference 達成チェックリスト

`code-review-spec-inference` スキルが **出力 JSON を返却する前** に通過すべきルール群。
ID 体系・SSOT は `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` を参照。

> **確認タイミング**: Step 5（矛盾事項の検出）完了後、出力 JSON 返却前。
> **未通過時**: 該当項目を解消してから返却する。

---

## A. Universal ルール（全スキル共通）

> 規範本文・達成基準は **`${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md`** を参照（プラグイン内 SSOT）。
> 適用範囲は `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` セクション8 を参照。

本スキルに適用される Universal ルールは **U1〜U8 / U12 / U14〜U16**（一覧・達成基準は `${CLAUDE_PLUGIN_ROOT}/references/universal-rules.md` の U マップ表）。**U9 / U10 / U11 / U13 は本スキル適用外**（`skill-rules-matrix.md` セクション8 脚注）。U15（信頼度付与）・U16（防御コード削除の回帰検出）はレビュー指摘生成・コード差分評価を行う場合のみ適用（本スキルは通常それらを行わないため実質対象外）。

---

## B. Inference ルール（推論支援スキル固有）

```
[ ] (I1)  情報源の優先順位（仕様書 > description 構造化見出し > 外部リンク > リポジトリ内資料 > 過去コメント > Bot 過去レビュー）に従っている
[ ] (I2)  外部 fetch は safe-external-fetch.md のドメインホワイトリスト方式に厳密準拠している
[ ] (I3)  取得結果に comment-sanitization.md のサニタイズ規則を適用している
[ ] (I4)  複数情報源間の矛盾を検出し、出力 JSON `conflicts` フィールドに格納している
[ ] (I5)  出力 JSON が 5 フィールド構造（expected_behavior_summary / requirements / acceptance_criteria / conflicts / sources_used）になっている
```

---

## C. 出力 JSON チェック

```bash
# C-Auto-1: 出力が有効な JSON であること
echo "$OUTPUT_JSON" | jq -e '.' >/dev/null 2>&1 || echo "ERROR: Invalid JSON"

# C-Auto-2: 必須フィールドが揃っているか
required_fields=("expected_behavior_summary" "requirements" "acceptance_criteria" "conflicts" "sources_used")
for f in "${required_fields[@]}"; do
  echo "$OUTPUT_JSON" | jq -e ".${f}" >/dev/null 2>&1 || echo "MISSING field: $f"
done

# C-Auto-3: sources_used に priority と type が含まれているか
echo "$OUTPUT_JSON" | jq -e '.sources_used[] | select((.priority? | not) or (.type? | not))' >/dev/null 2>&1 \
  && echo "WARN: sources_used に priority または type が欠落"

# C-Auto-4: 外部 fetch 失敗の透明性
echo "$OUTPUT_JSON" | jq -e '.sources_used[] | select(.type == "external-link") | .fetch_status' >/dev/null 2>&1 \
  || echo "WARN: external-link の fetch_status が欠落（success/failure/skipped を明示すること）"

# C-Auto-5: 機密文字列の伏字化
echo "$OUTPUT_JSON" | grep -nEi "Bearer [A-Za-z0-9_+/=.-]{16,}|gh[ps]_[A-Za-z0-9]{36,}|AKIA[0-9A-Z]{16}" \
  && echo "WARN: 認証情報パターンが出力 JSON に含まれている可能性。伏字化推奨"
```

---

## D. 未通過時の対応

| 未通過 ID | 対応 |
|----------|------|
| I1 | 情報源の優先順位を再評価し、出力の `sources_used` を並べ替え |
| I2 | ホワイトリスト不一致 URL を fetch 対象から除外、`sources_used.fetch_status` を "skipped" に |
| I3 | 取得資料に comment-sanitization.md セクション3-4 を再適用 |
| I4 | 矛盾検出ロジックを再実行し `conflicts` フィールドを更新 |
| I5 | 出力 JSON のスキーマを修正（5 フィールド構造） |
| U12 | 認証情報パターンを伏字化（comment-sanitization.md セクション3-4 参照） |

---

## E. 関連リファレンス

- `${CLAUDE_PLUGIN_ROOT}/references/skill-rules-matrix.md` — 全スキルのルール ID 体系
- `${CLAUDE_PLUGIN_ROOT}/references/safe-external-fetch.md` — 外部 fetch 安全方針
- `${CLAUDE_PLUGIN_ROOT}/references/comment-sanitization.md` — サニタイズ・機密文字列伏字化
- `${CLAUDE_SKILL_DIR}/references/expected-behavior.md` — 期待挙動推論ロジック詳細
- `${CLAUDE_SKILL_DIR}/SKILL.md` — 本スキルの実行フロー・出力フォーマット
